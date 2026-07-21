:- consult('conhecimento_ms.pl').

% ----------------------------------------------------------
% peso/3 — pontos de cada sintoma
% peso(TipoAcidente, Sintoma, Pontos)
%
% Derivação automática do grau na tabela sintoma_grau/3.
% ----------------------------------------------------------

% Exceção: coagulacao_proxy(alterada) vale 2 pontos em qualquer
% tipo, apesar de graduar como 'leve' no botrópico.
% Justificativa: MS trata coagulopatia como possibilidade em
% todos os graus (checkpoint, Decisão de peso).
peso(_, coagulacao_proxy(alterada), 2).

% Regras gerais (derivadas de sintoma_grau/3)
peso(Tipo, Sintoma, 3) :-
    sintoma_grau(Tipo, Sintoma, grave).

peso(Tipo, Sintoma, 2) :-
    Sintoma \= coagulacao_proxy(alterada),
    sintoma_grau(Tipo, Sintoma, moderado).

peso(Tipo, Sintoma, 1) :-
    Sintoma \= coagulacao_proxy(alterada),
    sintoma_grau(Tipo, Sintoma, leve).

% ----------------------------------------------------------
% score_maximo/2 — máximo teórico de pontos por tipo
% Soma dos pesos máximos de cada pergunta gradante do tipo.
% Serve pra normalizar o score em percentual.
% ----------------------------------------------------------

score_maximo(botropico, 17).
score_maximo(laquetico, 14).
score_maximo(crotalico, 16).
score_maximo(elapidico, 9).

% ----------------------------------------------------------
% faixa_score/2 — classifica um percentual em faixa
% faixa_score(Percentual, Faixa)
%
% Percentual esperado como valor 0-100 (não 0.0-1.0)
% ----------------------------------------------------------

faixa_score(P, baixa) :- P < 30.
faixa_score(P, media) :- P >= 30, P =< 60.
faixa_score(P, alta)  :- P > 60.