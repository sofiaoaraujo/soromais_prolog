:- encoding(utf8).
:- consult('explicacao.pl').

% ==========================================================
% relatorio.pl
% Relatório clínico-textual pra acompanhar as respostas do
% paciente até o médico/hospital receptor.
%
% NÃO reimplementa nada: só chama avaliar/5 (Módulo 1) e
% explicar/5 (Módulo 2, explicacao.pl) e formata os dois
% resultados num texto único, corrido, com seções — pensado
% pra ser embutido no PDF que o back-end já gera (routers/
% relatorio.py) ou no corpo da mensagem de WhatsApp
% (routers/whatsapp.py), junto com os dados de identificação
% do paciente e da localização (que ficam por conta do
% back-end/Supabase, fora do escopo do motor Prolog).
%
% Interface pública:
%   relatorio(Tipo, Sintomas, Flags, Universal, Texto)
%   Texto = string única, já formatada, pronta pra impressão/PDF.
%
%   relatorio_json(Tipo, Sintomas, Flags, Universal, Dict)
%   Dict = resultado + explicacao + relatorio_texto num só
%   payload, pra quem preferir montar o layout do PDF no
%   próprio back-end em vez de usar o texto pronto.
% ==========================================================

rotulo_tipo(botropico, "Botrópico (jararaca/urutu/caiçaca)").
rotulo_tipo(laquetico, "Laquético (surucucu)").
rotulo_tipo(crotalico, "Crotálico (cascavel)").
rotulo_tipo(elapidico, "Elapídico (coral)").
rotulo_tipo(Tipo, Tipo) :- \+ member(Tipo, [botropico, laquetico, crotalico, elapidico]).

rotulo_grau(picada_seca, "PICADA SECA (sem envenenamento)").
rotulo_grau(observar,    "OBSERVAÇÃO (sem sintomas até o momento)").
rotulo_grau(leve,        "LEVE").
rotulo_grau(moderado,    "MODERADO").
rotulo_grau(grave,       "GRAVE").

rotulo_conduta(alta_orientacoes,             "Alta com orientações").
rotulo_conduta(observar_6h_unidade,          "Manter em observação por 6h na unidade").
rotulo_conduta(hospital_encaminhamento,      "Encaminhar ao hospital de referência").
rotulo_conduta(transporte_imediato,          "TRANSPORTE IMEDIATO ao hospital de referência").
rotulo_conduta(transporte_prioridade_maxima, "TRANSPORTE COM PRIORIDADE MÁXIMA").

% Lista legível dos sintomas/flags informados, sem julgar grau
% (é só o "que o paciente/socorrista marcou", pro médico
% conferir contra a classificação logo abaixo).
listar_termos(Lista, "Nenhum") :- Lista == [], !.
listar_termos(Lista, Texto) :-
    Lista \= [],
    findall(S, (member(Item, Lista), format(string(S), "~w", [Item])), Strings),
    atomic_list_concat(Strings, ", ", Concat),
    Texto = Concat.

% ----------------------------------------------------------
% relatorio/5 — texto único e formatado
% ----------------------------------------------------------

relatorio(Tipo, Sintomas, Flags, Universal, Texto) :-
    avaliar(Tipo, Sintomas, Flags, Universal,
            resultado(_, Grau, Score, Max, Faixa, Conduta, _Alertas)),
    explicar(Tipo, Sintomas, Flags, Universal, Explicacao),

    rotulo_tipo(Tipo, TipoLegivel),
    rotulo_grau(Grau, GrauLegivel),
    rotulo_conduta(Conduta, CondutaLegivel),
    listar_termos(Sintomas, SintomasTexto),
    listar_termos(Flags, FlagsTexto),
    ( memberchk(tempo_h(TempoH), Universal) -> true ; TempoH = "não informado" ),

    atomic_list_concat(Explicacao, "\n", ExplicacaoTexto),

    ( (Grau == picada_seca ; Grau == observar)
    -> format(string(BlocoScore),
              "Score de gravidade: não se aplica (motores de gravidade não acionados nesta fase).",
              [])
    ;  format(string(BlocoScore),
              "Score de gravidade: ~w de ~w pontos (faixa ~w).",
              [Score, Max, Faixa])
    ),

    format(string(Texto),
"RELATÓRIO DE TRIAGEM — SOROMAIS
========================================

DADOS DO ACIDENTE (informados pelo paciente/socorrista)
Tipo de serpente/acidente: ~w
Tempo estimado desde a picada: ~w h
Sintomas marcados: ~w
Fatores de contexto/flags: ~w

RESULTADO DA TRIAGEM (motor de inferência)
Classificação (grau MS): ~w
~w
Conduta recomendada: ~w

RACIOCÍNIO DO MOTOR (auditável, gerado automaticamente)
----------------------------------------
~w
----------------------------------------

Este relatório foi gerado automaticamente pelo SoroMais a partir das respostas
do paciente/socorrista e não substitui a avaliação clínica presencial.
",
        [TipoLegivel, TempoH, SintomasTexto, FlagsTexto,
         GrauLegivel, BlocoScore, CondutaLegivel,
         ExplicacaoTexto]).

% ----------------------------------------------------------
% relatorio_json/5 — resultado + explicação + texto num dict,
% pra quem preferir montar o layout do PDF no back-end.
% ----------------------------------------------------------

relatorio_json(Tipo, Sintomas, Flags, Universal, Dict) :-
    avaliar(Tipo, Sintomas, Flags, Universal,
            resultado(TipoR, Grau, Score, Max, Faixa, Conduta, Alertas)),
    explicar(Tipo, Sintomas, Flags, Universal, Explicacao),
    relatorio(Tipo, Sintomas, Flags, Universal, Texto),
    Dict = _{
        resultado: _{
            tipo: TipoR, grau: Grau, score: Score, max: Max,
            faixa: Faixa, conduta: Conduta, alertas: Alertas
        },
        explicacao: Explicacao,
        relatorio_texto: Texto
    }.