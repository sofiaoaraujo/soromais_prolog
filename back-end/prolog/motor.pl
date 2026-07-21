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
aperta(_,                            transporte_imediato).

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