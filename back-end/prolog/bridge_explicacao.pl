:- encoding(utf8).
:- consult('explicacao.pl').
:- use_module(library(http/json)).

% ==========================================================
% bridge_explicacao.pl
% Ponte entre o back-end FastAPI e o Módulo 2 (explicar/5 em
% explicacao.pl). Espelha exatamente a mecânica de bridge.pl
% (Módulo 1), só trocando avaliar/5 por explicar/5 — Opção A
% do roteiro técnico: endpoint separado, sem tocar no bridge.pl
% original.
%
% Lê um JSON pelo stdin no MESMO formato aceito pelo bridge.pl:
%
%   {"tipo": "botropico",
%    "sintomas": [{"chave": "local", "valor": "evidente"}, ...],
%    "flags": [{"chave": "local_picada", "valor": "dedo"}, ...],
%    "universal": {"tempo_h": 5, "sintoma": "sim"}}
%
% Escreve no stdout:
%
%   {"explicacao": ["...", "...", ...]}
%
% ou, em caso de erro:
%
%   {"erro": "..."}
%
% Chamado via: swipl bridge_explicacao.pl < payload.json
% Rota sugerida no FastAPI: POST /triagem/explicacao
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

    ( explicar(Tipo, Sintomas, Flags, Universal, Explicacao)
    -> ResultadoJson = _{ explicacao: Explicacao }
    ; throw(sem_explicacao(Tipo, Sintomas, Flags, Universal))
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