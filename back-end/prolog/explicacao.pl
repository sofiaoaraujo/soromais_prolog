:- encoding(utf8).
:- consult('main.pl').

% ==========================================================
% explicacao.pl
% Módulo 2 — Explicação / Prova do motor Soromais.
%
% NÃO reimplementa nenhuma regra clínica. Todo o raciocínio
% (graus, pesos, score, faixa, conduta, alertas) continua
% sendo decidido exclusivamente pelos predicados já
% consolidados em motor.pl / pesos.pl / conhecimento_ms.pl,
% carregados via main.pl.
%
% Este arquivo só CONSULTA esses predicados e monta, a partir
% deles, uma narrativa textual (lista de strings) explicando
% por que o motor chegou ao resultado que chegou.
%
% Predicados reaproveitados (não reimplementados):
%   sintoma_grau/3, peso/3, pior_grau/3, pior_grau_lista/2,
%   score_maximo/2, faixa_score/2, grau_ms/3, score_urgencia/4,
%   recomendacao/4, recomendacao_base/3, flag_ativa/1,
%   tem_flag_ativa/1, aperta/2, alerta/2, avaliar_universal/2,
%   ordem_grau/2.
%
% Interface pública (espelha avaliar/5 do Módulo 1):
%   explicar(Tipo, Sintomas, Flags, Universal, Explicacao)
%   Explicacao = lista de strings, pronta pra ser exibida ou
%   serializada em JSON pelo bridge_explicacao.pl.
% ==========================================================


% ----------------------------------------------------------
% EIXO 1 — Por sintoma
% Para cada sintoma relatado, mostra o grau que ele dispara
% (sintoma_grau/3) e os pontos que ele soma no score (peso/3).
% Sintomas que não graduam nesse Tipo (catálogo de outro tipo)
% são ignorados silenciosamente — igual ao motor.
% ----------------------------------------------------------

explicar_por_sintoma(Tipo, Sintomas, Linhas) :-
    findall(Linha, (
        member(Sintoma, Sintomas),
        sintoma_grau(Tipo, Sintoma, Grau),
        peso(Tipo, Sintoma, Peso),
        format(string(Linha),
               "~w → grau ~w, +~w ponto(s)",
               [Sintoma, Grau, Peso])
    ), Linhas).

% ----------------------------------------------------------
% EIXO 2 — Grau final (motor categórico)
% grau_ms/3 devolve só o pior grau, sem dizer qual sintoma foi
% o responsável. Aqui pareamos cada sintoma com seu grau
% (Sintoma-Grau) e reduzimos a lista com a MESMA lógica de
% pior_grau/3 (reaproveitada, não reimplementada), só que
% carregando o sintoma-origem junto pra poder narrar.
% ----------------------------------------------------------

% Compara dois pares Sintoma-Grau e devolve o pior, usando
% pior_grau/3 já existente em motor.pl para decidir a ordem.
pior_par(S1-G1, _S2-G2, S1-G1) :-
    pior_grau(G1, G2, GVencedor),
    GVencedor == G1.
pior_par(_S1-G1, S2-G2, S2-G2) :-
    pior_grau(G1, G2, GVencedor),
    GVencedor == G2,
    GVencedor \== G1.

pior_par_lista([Par], Par).
pior_par_lista([Par | Resto], Pior) :-
    pior_par_lista(Resto, PiorDaCauda),
    pior_par(Par, PiorDaCauda, Pior).

explicar_grau_final(Tipo, Sintomas, Grau, Linha) :-
    findall(Sintoma-G, (
        member(Sintoma, Sintomas),
        sintoma_grau(Tipo, Sintoma, G)
    ), Pares),
    Pares \= [],
    pior_par_lista(Pares, SintomaResponsavel-Grau),
    format(string(Linha),
           "Grau final: ~w — resultado do pior grau entre os sintomas marcados; o sintoma decisivo foi ~w.",
           [Grau, SintomaResponsavel]).

% ----------------------------------------------------------
% EIXO 3 — Score (motor de pontuação)
% Reaproveita score_urgencia/4 (soma + faixa) e score_maximo/2.
% O percentual exibido é o mesmo cálculo que score_urgencia/4
% já faz internamente para escolher a faixa via faixa_score/2 —
% aqui só é recalculado para poder ser mostrado na narrativa,
% nenhuma regra nova de decisão é introduzida.
% ----------------------------------------------------------

explicar_score(Tipo, Sintomas, Score, Faixa, Linha) :-
    score_urgencia(Tipo, Sintomas, Score, Faixa),
    score_maximo(Tipo, Max),
    Percentual is (Score * 100) / Max,
    format(string(Linha),
           "Score: ~w de ~w pontos possíveis (~1f%), classificado na faixa '~w'.",
           [Score, Max, Percentual, Faixa]).

% ----------------------------------------------------------
% EIXO 4 — Conduta & agravamentos
% Mostra a conduta base (recomendacao_base/3) para o par
% Grau/Faixa e, se houver flag ativa (tem_flag_ativa/1),
% narra o aperto feito por aperta/2 (recomendacao/4 por trás
% das cortinas é exatamente essa composição).
% ----------------------------------------------------------

explicar_conduta(Grau, Faixa, Flags, Linhas) :-
    ( (Grau == picada_seca ; Grau == observar) ->
        recomendacao(Grau, Faixa, Flags, Conduta),
        format(string(L),
               "Conduta: ~w — caso sem envenenamento confirmado pela pré-triagem universal, os motores de gravidade não chegam a ser acionados.",
               [Conduta]),
        Linhas = [L]
    ;
        recomendacao_base(Grau, Faixa, CondutaBase),
        ( tem_flag_ativa(Flags) ->
            aperta(CondutaBase, CondutaFinal),
            ( CondutaBase == CondutaFinal ->
                format(string(L),
                       "Conduta base para grau ~w + faixa ~w já é '~w'. Há flag(s) contextual(is) ativa(s), mas não é preciso elevar mais nada — conduta mantida.",
                       [Grau, Faixa, CondutaBase])
            ;
                format(string(L),
                       "Conduta base para grau ~w + faixa ~w seria '~w'. Como há flag(s) contextual(is) ativa(s), a conduta final foi elevada para '~w'.",
                       [Grau, Faixa, CondutaBase, CondutaFinal])
            ),
            Linhas = [L]
        ;
            format(string(L),
                   "Conduta final: ~w (grau ~w + faixa ~w, sem flags ativas que exijam aperto).",
                   [CondutaBase, Grau, Faixa]),
            Linhas = [L]
        )
    ).

% ----------------------------------------------------------
% EIXO 5 — Alertas
% Reaproveita integralmente os textos de alerta/2, um por
% flag informada que exista no catálogo.
% ----------------------------------------------------------

explicar_alertas(Flags, Linhas) :-
    findall(Linha, (
        member(Flag, Flags),
        alerta(Flag, Texto),
        format(string(Linha), "Flag ~w → ~w", [Flag, Texto])
    ), Encontrados),
    ( Encontrados == []
    -> Linhas = ["Nenhuma flag contextual presente na entrada gerou alerta."]
    ;  Linhas = Encontrados
    ).

% ----------------------------------------------------------
% explicar/5 — ponto de entrada do Módulo 2
% Espelha avaliar/5: mesma entrada, saída é a narrativa.
% ----------------------------------------------------------

explicar(Tipo, Sintomas, Flags, Universal, Explicacao) :-
    avaliar_universal(Universal, Estado),
    Estado == envenenamento,
    !,
    explicar_por_sintoma(Tipo, Sintomas, LinhasSintomas),
    explicar_grau_final(Tipo, Sintomas, Grau, LinhaGrau),
    explicar_score(Tipo, Sintomas, _Score, Faixa, LinhaScore),
    explicar_conduta(Grau, Faixa, Flags, LinhasConduta),
    explicar_alertas(Flags, LinhasAlertas),
    append([
        ["=== Por sintoma ==="], LinhasSintomas,
        ["", "=== Grau final ==="], [LinhaGrau],
        ["", "=== Score ==="], [LinhaScore],
        ["", "=== Conduta e agravamentos ==="], LinhasConduta,
        ["", "=== Alertas ==="], LinhasAlertas
    ], Explicacao).

% Caso sem envenenamento (picada_seca / observar): motores de
% grau e score não rodam — igual à segunda cláusula de avaliar/5.
explicar(_Tipo, _Sintomas, Flags, Universal, Explicacao) :-
    avaliar_universal(Universal, Estado),
    Estado \== envenenamento,
    format(string(LinhaEstado),
           "Pré-triagem universal: ~w — sem sintoma relatado no bloco universal (ou tempo insuficiente/excedido conforme a regra das 6h), então os motores de grau e score sequer são chamados.",
           [Estado]),
    explicar_conduta(Estado, baixa, Flags, LinhasConduta),
    explicar_alertas(Flags, LinhasAlertas),
    append([
        [LinhaEstado],
        ["", "=== Conduta ==="], LinhasConduta,
        ["", "=== Alertas ==="], LinhasAlertas
    ], Explicacao).


% ==========================================================
% Validação manual (Seção 5 do roteiro): roda explicar/5 para
% os mesmos 10 casos de casos_teste.pl e imprime a narrativa,
% pra conferir "na mão" se bate com o resultado/7 esperado.
% Não reimplementa a bateria — só reaproveita caso_teste/7.
% ==========================================================

rodar_explicacoes :-
    consult('casos_teste.pl'),
    format("~n=== NARRATIVAS DE EXPLICAÇÃO — MÓDULO 2 ===~n"),
    forall(
        caso_teste(N, Nome, Tipo, Sintomas, Flags, Universal, Esperado),
        (
            format("~n--- Caso ~w: ~w ---~n", [N, Nome]),
            format("Resultado esperado (Módulo 1): ~w~n~n", [Esperado]),
            explicar(Tipo, Sintomas, Flags, Universal, Explicacao),
            forall(member(Linha, Explicacao), format("~s~n", [Linha]))
        )
    ),
    nl.