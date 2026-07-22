:- encoding(utf8).
:- consult('relatorio.pl').
:- use_module(library(http/json)).

% ==========================================================
% bridge_relatorio.pl
% Ponte entre o back-end FastAPI e relatorio.pl.
% Mesma mecânica de bridge.pl / bridge_explicacao.pl.
%
% Lê o mesmo formato de payload (tipo, sintomas, flags,
% universal) e devolve um relatório completo pronto pra
% acompanhar as respostas do paciente até o médico:
%
%   {
%     "resultado": {tipo, grau, score, max, faixa, conduta, alertas},
%     "explicacao": ["...", "..."],
%     "relatorio_texto": "texto único formatado, pronto pro PDF"
%   }
%
% O back-end pode usar "relatorio_texto" direto (ex: como uma
% seção/página a mais no PDF do routers/relatorio.py, ou no
% corpo da mensagem do routers/whatsapp.py), ou montar seu
% próprio layout usando "resultado" e "explicacao" separados.
%
% Chamado via: swipl bridge_relatorio.pl < payload.json
% Rota sugerida no FastAPI: POST /triagem/relatorio
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

processar(Payload, Dict) :-
    atom_string(Tipo, Payload.tipo),

    UniversalDict = Payload.universal,
    dict_pairs(UniversalDict, _, ParesUniversal),
    maplist(par_para_termo, ParesUniversal, Universal),

    maplist(atomo_para_termo, Payload.sintomas, Sintomas),
    maplist(atomo_para_termo, Payload.flags, Flags),

    ( relatorio_json(Tipo, Sintomas, Flags, Universal, Dict)
    -> true
    ;  throw(sem_relatorio(Tipo, Sintomas, Flags, Universal))
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