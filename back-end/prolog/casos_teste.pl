:- encoding(utf8).
:- consult('motor.pl').

:- encoding(utf8).
:- consult('motor.pl').

% ==========================================================
% casos-teste.pl
% Bateria de validação do motor Soromais.
%
% Cada caso é um cenário clínico específico com resultado
% esperado conhecido. O runner rodar_testes/0 executa cada
% um pela avaliar/5 e compara o resultado obtido com o
% esperado. Serve como:
%
%   1. Regressão — se algum ajuste no motor quebrar um caso
%      previamente correto, aparece imediatamente.
%   2. Documentação — cada caso descreve um cenário clínico
%      com nome legível.
%   3. Validação acadêmica — a bateria cobre os limites do
%      motor e as decisões de design do checkpoint.
%
% Cobertura da bateria:
%   - Casos 1, 5, 6, 8, 9: graus clássicos (moderado, grave, leve)
%     em cada tipo de acidente.
%   - Casos 2, 3: pré-triagem universal (observar, picada seca).
%   - Caso 4: borderline que exercita a Decisão 1 (grau MS
%     mantido, score aperta a conduta).
%   - Caso 7: elapídico assintomático (opção A do tipo — grau
%     grave por definição).
%   - Caso 10: flags contextuais múltiplas (Categorias 1, 2 e 3
%     dos alertas).
% ==========================================================

caso_teste(
    1,
    "Botrópico moderado clássico",
    botropico,
    [local(evidente), sangramento(discreto)],
    [],
    [tempo_h(3), sintoma(sim)],
    resultado(botropico, moderado, 3, 17, baixa, hospital_encaminhamento, [])
).

caso_teste(
    2,
    "Observação (regra das 6h)",
    botropico,
    [],
    [],
    [tempo_h(4), sintoma(nao)],
    resultado(botropico, observar, 0, 0, baixa, observar_6h_unidade, [])
).

caso_teste(
    3,
    "Picada seca",
    botropico,
    [],
    [],
    [tempo_h(10), sintoma(nao)],
    resultado(botropico, picada_seca, 0, 0, baixa, alta_orientacoes, [])
).

caso_teste(
    4,
    "Borderline botrópico (exercita Decisão 1)",
    botropico,
    [local(evidente), sangramento(moderado), coagulacao_proxy(alterada), local_complicacao(bolhas)],
    [],
    [tempo_h(5), sintoma(sim)],
    resultado(botropico, moderado, 8, 17, media, transporte_imediato, [])
).

caso_teste(
    5,
    "Laquético grave típico",
    laquetico,
    [local(intenso), sangramento(intenso), vagais(sim)],
    [],
    [tempo_h(2), sintoma(sim)],
    resultado(laquetico, grave, 9, 14, alta, transporte_prioridade_maxima, [])
).

caso_teste(
    6,
    "Crotálico grave completo",
    crotalico,
    [neuro(evidente), mialgia(intensa), urina_escura(intensa), diurese(oliguria)],
    [],
    [tempo_h(4), sintoma(sim)],
    resultado(crotalico, grave, 11, 16, alta, transporte_prioridade_maxima, [])
).

caso_teste(
    7,
    "Elapídico assintomático (opção A do tipo)",
    elapidico,
    [tipo(elapidico)],
    [],
    [tempo_h(1), sintoma(sim)],
    resultado(elapidico, grave, 3, 9, media, transporte_imediato, [])
).

caso_teste(
    8,
    "Botrópico grave clássico",
    botropico,
    [local(intenso), sangramento(intenso), choque(sim)],
    [],
    [tempo_h(4), sintoma(sim)],
    resultado(botropico, grave, 9, 17, media, transporte_imediato, [])
).

caso_teste(
    9,
    "Crotálico leve isolado",
    crotalico,
    [neuro(discreto)],
    [],
    [tempo_h(2), sintoma(sim)],
    resultado(crotalico, leve, 1, 16, baixa, hospital_encaminhamento, [])
).

caso_teste(
    10,
    "Botrópico moderado com múltiplas flags contextuais",
    botropico,
    [local(evidente), sangramento(discreto)],
    [local_picada(dedo), interferencia(garrote), contexto_risco(gestacao)],
    [tempo_h(3), sintoma(sim)],
    resultado(botropico, moderado, 3, 17, baixa, transporte_imediato,
              ["Picada em dedo — extremidade com maior risco de necrose e síndrome compartimental. Monitorar perfusão distal, temperatura e coloração.",
               "Garrote/torniquete aplicado — remover imediatamente. Aumenta risco de necrose tecidual e síndrome compartimental. Registrar tempo estimado de amarração para a equipe hospitalar.",
               "Gestante — internação obrigatória. Comunicar a unidade receptora com antecedência para preparar equipe obstétrica (risco de hemorragia uterina e sofrimento fetal)."])
).

% ----------------------------------------------------------
% Runner de testes
%
% rodar_testes/0 — ponto de entrada. Coleta todos os casos
% via findall, delega pra rodar_lista com acumuladores de
% passou/falhou, imprime relatório final.
%
% rodar_lista/5 — recursão sobre lista de números de caso.
% Acumula contadores em passagem única. Idioma comum em
% Prolog quando você precisa contar coisas processando lista.
%
% rodar_caso/2 — duas cláusulas mutuamente exclusivas.
% Primeira sucede se avaliar/5 produz Obtido idêntico ao
% Esperado (== é comparação estrita, não unificação).
% Segunda pega os casos que falharam e imprime diff.
% O corte (!) na primeira impede fallback pra segunda no
% caso de sucesso.
% ----------------------------------------------------------

rodar_testes :-
    format("~n=== BATERIA DE TESTES SOROMAIS ===~n~n"),
    findall(N, caso_teste(N, _, _, _, _, _, _), Numeros),
    rodar_lista(Numeros, 0, Passou, 0, Falhou),
    format("~n=== RESULTADO ===~n"),
    format("Passou: ~w~n", [Passou]),
    format("Falhou: ~w~n", [Falhou]),
    Total is Passou + Falhou,
    format("Total:  ~w~n~n", [Total]).

% Percorre a lista de números de caso, acumulando contadores
rodar_lista([], P, P, F, F).
rodar_lista([N | Resto], PAcc, PFinal, FAcc, FFinal) :-
    rodar_caso(N, Resultado),
    (   Resultado = passou
    ->  PNovo is PAcc + 1, FNovo = FAcc
    ;   PNovo = PAcc, FNovo is FAcc + 1
    ),
    rodar_lista(Resto, PNovo, PFinal, FNovo, FFinal).

% Executa um caso individual
rodar_caso(N, passou) :-
    caso_teste(N, Nome, Tipo, Sintomas, Flags, Universal, Esperado),
    avaliar(Tipo, Sintomas, Flags, Universal, Obtido),
    Obtido == Esperado,
    !,
    format("[~w] PASSOU: ~w~n", [N, Nome]).

rodar_caso(N, falhou) :-
    caso_teste(N, Nome, Tipo, Sintomas, Flags, Universal, Esperado),
    avaliar(Tipo, Sintomas, Flags, Universal, Obtido),
    format("[~w] FALHOU: ~w~n", [N, Nome]),
    format("     Esperado: ~w~n", [Esperado]),
    format("     Obtido:   ~w~n", [Obtido]).