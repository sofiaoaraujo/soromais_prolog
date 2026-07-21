:- encoding(utf8).
:- consult('conhecimento_ms.pl').
:- consult('pesos.pl').

% ==========================================================
% motor.pl
% Camada de inferência do Soromais.
%
% Contém três motores + a tabela de recomendação:
%   grau_ms/2         — motor categórico (fiel ao Quadro 1)
%   score_urgencia/2  — motor por pontuação (acúmulo de sinais)
%   recomendacao/3    — combina grau + score → conduta clínica
%
% NOTA: a tabela de recomendação abaixo é decisão de design
% do Soromais, NÃO derivada literalmente do MS. Reflete a
% Decisão 1 do checkpoint (grau MS manda no rótulo, score
% alto aperta a conduta).


% ==========================================================
% ==========================================================
% MOTOR CATEGÓRICO — grau_ms/3
% Percorre a lista de sintomas do paciente e devolve o pior
% grau encontrado (regra do "pior sinal marcado" do MS).
% ==========================================================

% ----------------------------------------------------------
% Ordem dos graus (pior → melhor)
% ordem_grau(Grau, Valor)
% Valor maior = grau mais grave. Facilita a comparação
% numérica em vez de textual.
% ----------------------------------------------------------

ordem_grau(picada_seca, 0).
ordem_grau(leve,        1).
ordem_grau(moderado,    2).
ordem_grau(grave,       3).

% ----------------------------------------------------------
% Pior grau entre dois
% pior_grau(G1, G2, GraveDosDois)
% ----------------------------------------------------------

pior_grau(G1, G2, G1) :-
    ordem_grau(G1, V1),
    ordem_grau(G2, V2),
    V1 >= V2.

pior_grau(G1, G2, G2) :-
    ordem_grau(G1, V1),
    ordem_grau(G2, V2),
    V1 < V2.

% ----------------------------------------------------------
% Pior grau em uma lista de graus
% pior_grau_lista(ListaDeGraus, PiorGrau)
% ----------------------------------------------------------

% Caso base: lista com um elemento — o pior é ele mesmo
pior_grau_lista([G], G).

% Caso recursivo: pior de [H|T] é o pior entre H e o pior de T
pior_grau_lista([H | T], Pior) :-
    pior_grau_lista(T, PiorDaCauda),
    pior_grau(H, PiorDaCauda, Pior).

% ----------------------------------------------------------
% grau_ms/3 — motor categórico
% grau_ms(Tipo, Sintomas, Grau)
% "no acidente Tipo, com a lista Sintomas do paciente,
% o pior grau disparado é Grau"
% ----------------------------------------------------------

grau_ms(Tipo, Sintomas, Grau) :-
    findall(G, (
        member(Sintoma, Sintomas),
        sintoma_grau(Tipo, Sintoma, G)
    ), Graus),
    pior_grau_lista(Graus, Grau).

% ==========================================================
% MOTOR DE SCORE — score_urgencia/4
% Percorre a lista de sintomas e calcula um score numérico
% baseado na tabela peso/3, normalizado pelo máximo teórico
% do tipo (Decisão 2 do checkpoint).
% ==========================================================

% score_urgencia(Tipo, Sintomas, Pontos, Faixa)
score_urgencia(Tipo, Sintomas, Pontos, Faixa) :-
    findall(P, (
        member(Sintoma, Sintomas),
        peso(Tipo, Sintoma, P)
    ), Pesos),
    sum_list(Pesos, Pontos),
    score_maximo(Tipo, Max),
    Percentual is (Pontos * 100) / Max,
    faixa_score(Percentual, Faixa).


% ==========================================================
% PRÉ-TRIAGEM UNIVERSAL — avaliar_universal/2
% Decide o estado inicial do caso a partir do bloco universal
% (tempo + sintoma inicial).
% Regra das 6h do MS: sem sintoma + tempo >= 6h → picada seca;
% sem sintoma + tempo < 6h → observação em unidade de saúde.
% Com sintoma → segue pra motores de gravidade.
% ==========================================================

% avaliar_universal(Universal, Estado)

% Com sintoma → roda os motores de gravidade
avaliar_universal(Universal, envenenamento) :-
    memberchk(sintoma(sim), Universal).

% Sem sintoma e tempo >= 6h → picada seca
avaliar_universal(Universal, picada_seca) :-
    memberchk(sintoma(nao), Universal),
    memberchk(tempo_h(T), Universal),
    T >= 6.

% Sem sintoma e tempo < 6h → observação de 6h
avaliar_universal(Universal, observar) :-
    memberchk(sintoma(nao), Universal),
    memberchk(tempo_h(T), Universal),
    T < 6.

% ==========================================================
% TABELA DE RECOMENDAÇÃO
% recomendacao_base(Grau, FaixaScore, Conduta)
% ==========================================================

% Casos sem envenenamento
recomendacao_base(picada_seca, _, alta_orientacoes).
recomendacao_base(observar,    _, observar_6h_unidade).

% Grau leve
recomendacao_base(leve, baixa, hospital_encaminhamento).
recomendacao_base(leve, media, hospital_encaminhamento).
recomendacao_base(leve, alta,  transporte_imediato).

% Grau moderado
recomendacao_base(moderado, baixa, hospital_encaminhamento).
recomendacao_base(moderado, media, transporte_imediato).
recomendacao_base(moderado, alta,  transporte_imediato).

% Grau grave
recomendacao_base(grave, baixa, transporte_imediato).
recomendacao_base(grave, media, transporte_imediato).
recomendacao_base(grave, alta,  transporte_prioridade_maxima).

% ----------------------------------------------------------
% Flags que ativam aperto de conduta
% flag_ativa(Flag)
%
% Base: Categoria 1 (vulnerabilidade populacional/clínica)
%       Categoria 2 (conduta inadequada iatrogênica)
% Fonte: pesquisa Sofia (Hospital Israelita Albert Einstein,
%        Centro de Vigilância Epidemiológica) — checkpoint.
% ----------------------------------------------------------

% Categoria 1: vulnerabilidade populacional/clínica
flag_ativa(contexto_risco(gestacao)).
flag_ativa(contexto_risco(crianca)).
flag_ativa(contexto_risco(idoso)).
flag_ativa(contexto_risco(anticoagulante)).

% Categoria 2: conduta inadequada iatrogênica
flag_ativa(interferencia(garrote)).
flag_ativa(interferencia(corte)).
flag_ativa(interferencia(sucao)).
flag_ativa(interferencia(substancia)).

% ----------------------------------------------------------
% Predicado auxiliar: verdadeiro se a lista contém pelo menos
% uma flag que está no catálogo de flags ativas.
% ----------------------------------------------------------

% Existe alguma Flag que é membro da lista Flags E essa Flag está no catálogo flag_ativa.
tem_flag_ativa(Flags) :-
    member(Flag, Flags),
    flag_ativa(Flag).

% ----------------------------------------------------------
% Aperta uma conduta pra pelo menos transporte_imediato.
% Se já é imediato ou prioridade máxima, mantém.
% ----------------------------------------------------------

aperta(transporte_prioridade_maxima, transporte_prioridade_maxima).
aperta(transporte_imediato,          transporte_imediato).
aperta(C, transporte_imediato) :-
    C \= transporte_prioridade_maxima,
    C \= transporte_imediato.

% ----------------------------------------------------------
% Recomendação final: combina grau + score + flags → conduta
% recomendacao(Grau, FaixaScore, Flags, Conduta)
% ----------------------------------------------------------

% Exceção: picada seca — sem envenenamento, alta com orientações
recomendacao(picada_seca, _, _, alta_orientacoes).

% Exceção: observar — em observação, mantém observação
recomendacao(observar, _, _, observar_6h_unidade).

% Sem flag ativa: conduta base direto
recomendacao(Grau, Faixa, Flags, Conduta) :-
    Grau \= picada_seca,
    Grau \= observar,
    \+ tem_flag_ativa(Flags),
    recomendacao_base(Grau, Faixa, Conduta).

% Com flag ativa: pega conduta base e aperta pra pelo menos imediato
recomendacao(Grau, Faixa, Flags, Conduta) :-
    Grau \= picada_seca,
    Grau \= observar,
    tem_flag_ativa(Flags),
    recomendacao_base(Grau, Faixa, CondutaBase),
    aperta(CondutaBase, Conduta).

% ==========================================================
% ALERTAS DAS FLAGS — alerta/2
% Texto do alerta que cada flag ativa gera na saída.
% Alertas universais (não variam por tipo de acidente).
%
% Categorias:
%   1. Vulnerabilidade populacional/clínica (contexto_risco)
%   2. Conduta inadequada iatrogênica (interferencia)
%   3. Localização anatômica de risco (local_picada)
% ==========================================================

% ----------------------------------------------------------
% Categoria 1 — Vulnerabilidade populacional/clínica
% Base: protocolos de internação obrigatória do
% Hospital Israelita Albert Einstein.
% ----------------------------------------------------------

alerta(contexto_risco(gestacao),
    "Gestante — internação obrigatória. Comunicar a unidade receptora com antecedência para preparar equipe obstétrica (risco de hemorragia uterina e sofrimento fetal).").

alerta(contexto_risco(crianca),
    "Criança — internação obrigatória. Menor reserva fisiológica e maior sensibilidade a alterações hemodinâmicas. Priorizar transporte.").

alerta(contexto_risco(idoso),
    "Idoso — internação obrigatória. Menor reserva fisiológica e comorbidades comuns aumentam risco de descompensação. Priorizar transporte.").

alerta(contexto_risco(anticoagulante),
    "Uso de anticoagulante — risco amplificado de sangramento em acidentes botrópico e laquético. Comunicar unidade receptora para ajuste hemostático.").

% ----------------------------------------------------------
% Categoria 2 — Conduta inadequada iatrogênica
% Base: dados epidemiológicos de vigilância em saúde
% associam essas intervenções a taxas mais altas de
% necrose tecidual e amputações, especialmente em
% acidentes botrópicos com picadas em extremidades.
% ----------------------------------------------------------

alerta(interferencia(garrote),
    "Garrote/torniquete aplicado — remover imediatamente. Aumenta risco de necrose tecidual e síndrome compartimental. Registrar tempo estimado de amarração para a equipe hospitalar.").

alerta(interferencia(corte),
    "Corte no local da picada — risco elevado de infecção secundária e sangramento local. Avaliar necessidade de antibioticoterapia profilática na unidade receptora.").

alerta(interferencia(sucao),
    "Tentativa de sucção no local — risco de infecção e contaminação. Sem eficácia comprovada na remoção do veneno.").

alerta(interferencia(substancia),
    "Aplicação de substância no local (café, ervas, gelo, etc.) — pode mascarar sinais clínicos e aumentar risco de infecção. Documentar a substância aplicada.").

% ----------------------------------------------------------
% Categoria 3 — Localização anatômica de risco
% Base: MS destaca picadas em extremidades (dedos, mãos, pés)
% como maior risco de necrose e síndrome compartimental,
% especialmente em acidentes botrópicos.
% NOTA: local_picada NÃO aperta conduta (não está no catálogo
% flag_ativa), apenas gera alerta educativo.
% ----------------------------------------------------------

alerta(local_picada(dedo),
    "Picada em dedo — extremidade com maior risco de necrose e síndrome compartimental. Monitorar perfusão distal, temperatura e coloração.").

alerta(local_picada(mao),
    "Picada em mão — extremidade com risco elevado de complicações locais. Monitorar edema e comprometimento neurovascular.").

alerta(local_picada(pe),
    "Picada em pé — extremidade com risco elevado de complicações locais. Monitorar edema e comprometimento neurovascular.").

% ==========================================================
% ORQUESTRAÇÃO — avaliar/5
% Ponto de entrada do motor. Recebe o caso completo do
% paciente e devolve o resultado empacotado.
%
% Assinatura:
%   avaliar(Tipo, Sintomas, Flags, Universal, Resultado)
%
% Onde Resultado = resultado(Tipo, Grau, Score, Max, Faixa, Conduta, Alertas)
%
%   Tipo     — átomo do acidente (botropico, laquetico, etc.)
%   Grau     — leve/moderado/grave/picada_seca/observar
%   Score    — pontos brutos (0 em casos sem envenenamento)
%   Max      — teto teórico do tipo (0 em casos sem envenenamento)
%   Faixa    — baixa/media/alta
%   Conduta  — verbo de conduta clínica
%   Alertas  — lista de strings, uma por flag que gerou alerta
% ==========================================================

% Caso com envenenamento: roda os motores completos
avaliar(Tipo, Sintomas, Flags, Universal,
        resultado(Tipo, Grau, Score, Max, Faixa, Conduta, Alertas)) :-
    avaliar_universal(Universal, envenenamento),
    grau_ms(Tipo, Sintomas, Grau),
    score_urgencia(Tipo, Sintomas, Score, Faixa),
    score_maximo(Tipo, Max),
    recomendacao(Grau, Faixa, Flags, Conduta),
    findall(T, (member(F, Flags), alerta(F, T)), Alertas).

% Caso picada_seca ou observar: pula os motores
avaliar(_Tipo, _Sintomas, Flags, Universal,
        resultado(_Tipo, Estado, 0, 0, baixa, Conduta, Alertas)) :-
    avaliar_universal(Universal, Estado),
    Estado \= envenenamento,
    recomendacao(Estado, baixa, Flags, Conduta),
    findall(T, (member(F, Flags), alerta(F, T)), Alertas).