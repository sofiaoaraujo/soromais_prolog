:- encoding(utf8).
:- consult('main.pl').
:- use_module(library(json)).

% ==========================================================
% bridge.pl
% Ponte entre o back-end FastAPI e o motor Prolog (avaliar/5
% em motor.pl). Lê um JSON pelo stdin no formato:
%
%   {"tipo": "botropico",
%    "sintomas": [{"chave": "local", "valor": "evidente"}, ...],
%    "flags": [{"chave": "local_picada", "valor": "dedo"}, ...],
%    "universal": {"tempo_h": 5, "sintoma": "sim"}}
%
% Converte pros termos que avaliar/5 espera, roda a consulta e
% escreve o resultado (ou um erro) como JSON no stdout.
%
% Chamado via: swipl bridge.pl < payload.json
% ==========================================================

main :-
    set_stream(user_input, encoding(utf8)),
    set_stream(user_output, encoding(utf8)),
    json_read_dict(user_input, Payload),
    catch(
        processar(Payload, ResultadoJson),
        Erro,
        formatar_erro(Erro, ResultadoJson)
    ),
    json_write_dict(user_output, ResultadoJson),
    nl.

processar(Payload, ResultadoJson) :-
    atom_string(Tipo, Payload.tipo),

    UniversalDict = Payload.universal,
    dict_pairs(UniversalDict, _, ParesUniversal),
    maplist(par_para_termo, ParesUniversal, Universal),

    maplist(atomo_para_termo, Payload.sintomas, Sintomas),
    maplist(atomo_para_termo, Payload.flags, Flags),

    ( avaliar(Tipo, Sintomas, Flags, Universal,
              resultado(TipoR, Grau, Score, Max, Faixa, Conduta, Alertas))
    -> ResultadoJson = _{
           tipo: TipoR,
           grau: Grau,
           score: Score,
           max: Max,
           faixa: Faixa,
           conduta: Conduta,
           alertas: Alertas
       }
    ; throw(sem_solucao(Tipo, Sintomas, Flags, Universal))
    ).

% {"chave": "local", "valor": "evidente"} -> local(evidente)
atomo_para_termo(Item, Termo) :-
    atom_string(Chave, Item.chave),
    valor_para_termo_arg(Item.valor, Valor),
    Termo =.. [Chave, Valor].

% pares do dict "universal" (Chave já vem como átomo) -> chave(valor)
par_para_termo(Chave-ValorBruto, Termo) :-
    valor_para_termo_arg(ValorBruto, Valor),
    Termo =.. [Chave, Valor].

% número (ex: tempo_h) passa direto; string vira átomo
valor_para_termo_arg(Valor, Valor) :- number(Valor), !.
valor_para_termo_arg(Valor, Atom) :- atom_string(Atom, Valor).

formatar_erro(Erro, _{erro: Mensagem}) :-
    term_string(Erro, Mensagem).

:- initialization(main, main).
