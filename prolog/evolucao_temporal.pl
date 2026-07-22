% =============================================================================
% evolucao_temporal.pl
%
% Simulador de evolução temporal do quadro clínico em acidentes ofídicos.
% Projeta como o quadro tende a piorar SEM soroterapia e indica quando
% reavaliar o paciente (antes e depois do soro).
%
% Base clínica: Manual de Diagnóstico e Tratamento de Acidentes por Animais
% Peçonhentos (FUNASA/Ministério da Saúde, 2ª ed., 2001) — capítulos
% Acidente Botrópico, Crotálico, Laquético e Elapídico, e capítulo
% "Insuficiência Renal Aguda".
%
% -----------------------------------------------------------------------------
% CONTRATO DE INTERFACE com o motor de classificação de gravidade (colega)
% -----------------------------------------------------------------------------
% Assumimos que o outro módulo expõe:
%
%   classificar_gravidade(+Sintomas, +TempoHoras, +Idade, +Especie,
%                          -Envenenamento, -Grau, -Conduta)
%
% onde:
%   Especie        é um dos átomos: bothrops, crotalus, lachesis, micrurus
%   Grau           é um dos átomos: leve, moderado, grave
%                  (lachesis nunca deve gerar `leve` — ver observação em
%                  agravante_grau/5 mais abaixo)
%   TempoHoras     é o tempo decorrido desde a picada, em horas (número)
%   Envenenamento  é efetivo ou nao_efetivo
%
% Este módulo NÃO reclassifica gravidade — ele consome Especie, Grau e
% TempoHoras (já decididos pelo colega) para projetar a evolução futura.
% Se os nomes dos átomos/predicados do colega vierem diferentes, só ajustar
% os fatos/chamadas deste arquivo — a lógica de projeção não muda.
% =============================================================================


% -----------------------------------------------------------------------------
% STUB temporário do motor de gravidade — APAGAR quando o arquivo do colega
% for consultado no lugar deste. Serve só para testar este módulo sozinho.
% -----------------------------------------------------------------------------
:- discontiguous classificar_gravidade/7.

classificar_gravidade(_Sintomas, TempoHoras, _Idade, bothrops,
                       efetivo, grave, soroterapia_imediata) :-
    TempoHoras >= 0.


% =============================================================================
% BASE DE CONHECIMENTO CLÍNICO
% =============================================================================

% marco_base(+Especie, +HoraDecorrida, -Manifestacao, -Urgencia)
%
% Manifestações esperadas SEM soro, independente do grau — refletem a ação
% do veneno ao longo do tempo. HoraDecorrida é o tempo desde a picada (horas).
% Urgencia é um de: baixa, moderada, alta, critica.

% --- Bothrops (acidente botrópico) ------------------------------------------
marco_base(bothrops, 0.5,
    'dor e edema iniciam no local da picada', baixa).
marco_base(bothrops, 3,
    'edema endurado e equimose já evidentes no local', moderada).
marco_base(bothrops, 6,
    'possível progressão do edema para além do segmento picado; risco de sangramento à distância (gengivorragia, epistaxe, hematúria)', moderada).
marco_base(bothrops, 24,
    'sem soro, tempo de coagulação tende a permanecer alterado/incoagulável; risco hemorrágico persiste', alta).
marco_base(bothrops, 48,
    'edema extenso podendo evoluir com necrose tecidual, sobretudo em extremidades', alta).

% --- Crotalus (acidente crotálico) ------------------------------------------
marco_base(crotalus, 1,
    'manifestações locais discretas (pouca dor/edema); pode iniciar parestesia local', baixa).
marco_base(crotalus, 3,
    'possível início de sinais neurotóxicos: ptose palpebral, fácies miastênica, alteração do diâmetro pupilar', moderada).
marco_base(crotalus, 12,
    'mialgia generalizada e escurecimento da urina (mioglobinúria) podem se acentuar', alta).
marco_base(crotalus, 24,
    'pico esperado da creatinoquinase (CK) — indica miólise máxima em curso', alta).
marco_base(crotalus, 48,
    'sem soro, risco de instalação de necrose tubular aguda/insuficiência renal aguda, com oligúria ou anúria', critica).

% --- Lachesis (acidente laquético) ------------------------------------------
marco_base(lachesis, 1,
    'dor e edema locais, podendo surgir bolhas de conteúdo seroso ou serro-hemorrágico', moderada).
marco_base(lachesis, 3,
    'risco de síndrome vagal: bradicardia, hipotensão arterial, cólicas abdominais e diarreia', alta).
marco_base(lachesis, 24,
    'sem soro específico (raro), quadro local evolui como no acidente botrópico — risco hemorrágico e de necrose', alta).
marco_base(lachesis, 48,
    'edema extenso podendo evoluir com necrose tecidual', alta).

% --- Micrurus (acidente elapídico / coral) ----------------------------------
% É o gênero de evolução mais rápida e potencialmente mais letal sem soro.
marco_base(micrurus, 0.5,
    'quadro pode iniciar com vômitos e discreta dor local com parestesia', baixa).
marco_base(micrurus, 2,
    'fraqueza muscular progressiva: ptose palpebral, oftalmoplegia, fácies miastênica, diplopia', alta).
marco_base(micrurus, 4,
    'dificuldade de deglutição por paralisia do véu palatino; risco de progressão para paralisia da musculatura respiratória', critica).
marco_base(micrurus, 24,
    'observação obrigatória até aqui: sintomas neurotóxicos podem ter aparecimento tardio mesmo sem piora prévia', alta).


% agravante_grau(+Especie, +Grau, +HoraDecorrida, -Manifestacao, -Urgencia)
%
% Manifestações/complicações adicionais específicas de graus mais severos.

agravante_grau(bothrops, grave, 6,
    'edema pode atingir todo o membro; risco de isquemia local por compressão do feixe vásculo-nervoso (síndrome compartimental)', alta).
agravante_grau(bothrops, grave, 12,
    'possível hipotensão arterial, choque ou oligúria — qualquer um destes já define o caso como grave', critica).
agravante_grau(bothrops, grave, 48,
    'sem soro, risco elevado de síndrome compartimental evoluir para necrose extensa/gangrena e infecção secundária (abscesso)', critica).

agravante_grau(crotalus, grave, 3,
    'sinais neurotóxicos evidentes e precoces (fácies miastênica franca, fraqueza muscular)', alta).
agravante_grau(crotalus, grave, 12,
    'mialgia intensa e generalizada; urina francamente escura', alta).

agravante_grau(lachesis, grave, 3,
    'manifestações vagais mais intensas (bradicardia e hipotensão marcantes) — série de grande porte injeta mais veneno', critica).

agravante_grau(micrurus, grave, 4,
    'evolução esperada para paralisia flácida da musculatura respiratória — insuficiência respiratória aguda e apneia', critica).

% Observação de domínio: acidentes laquéticos nunca são classificados como
% `leve` no manual (serpente de grande porte = carga de veneno presumida
% alta). O motor de gravidade do colega não deveria gerar
% classificar_gravidade(..., lachesis, _, leve, _) — se gerar, este módulo
% ainda funciona (só não terá agravantes de grau para somar aos marcos base).


% marco_temporal(+Especie, +Grau, -HoraDecorrida, -Manifestacao, -Urgencia)
%
% União dos marcos base (todo grau) com os agravantes específicos do grau.
marco_temporal(Especie, _Grau, Hora, Manifestacao, Urgencia) :-
    marco_base(Especie, Hora, Manifestacao, Urgencia).
marco_temporal(Especie, Grau, Hora, Manifestacao, Urgencia) :-
    agravante_grau(Especie, Grau, Hora, Manifestacao, Urgencia).


% =============================================================================
% PROJEÇÃO DE EVOLUÇÃO SEM SORO
% =============================================================================

% projecao_evolucao(+Especie, +Grau, +TempoAtual, -Timeline)
%
% Timeline é uma lista ordenada por tempo de termos:
%   marco(HoraDecorrida, Manifestacao, Urgencia)
% contendo apenas marcos ainda não alcançados (Hora > TempoAtual), ou seja,
% a projeção "daqui pra frente" caso o soro não seja administrado.
% Usa msort/2 (e não predsort/3) de propósito: predsort descarta um dos
% termos quando dois marcos caem na mesma hora (ex.: um marco_base e um
% agravante_grau ambos em Hora=6), tratando-os como duplicata. msort ordena
% pela Hora e, em caso de empate, pela Manifestacao — sem perder marcos.
projecao_evolucao(Especie, Grau, TempoAtual, Timeline) :-
    findall(marco(Hora, Manifestacao, Urgencia),
            ( marco_temporal(Especie, Grau, Hora, Manifestacao, Urgencia),
              Hora > TempoAtual
            ),
            Marcos),
    msort(Marcos, Timeline).


% proxima_reavaliacao_sem_soro(+Especie, +Grau, +TempoAtual, -Reavaliacao)
%
% Reavaliacao = reavaliacao(HoraRecomendada, Manifestacao, Urgencia)
% Indica o próximo marco clínico esperado — é quando o quadro do relatório
% deveria recomendar reavaliar o paciente, caso o soro ainda não tenha sido
% administrado.
proxima_reavaliacao_sem_soro(Especie, Grau, TempoAtual, Reavaliacao) :-
    projecao_evolucao(Especie, Grau, TempoAtual, [marco(Hora, Manif, Urg) | _]),
    !,
    Reavaliacao = reavaliacao(Hora, Manif, Urg).
proxima_reavaliacao_sem_soro(_Especie, _Grau, _TempoAtual, Reavaliacao) :-
    % Não há mais marcos previstos na base (ex.: TempoAtual já além de 48h) —
    % ainda assim, sem soro administrado, a recomendação nunca deixa de valer.
    Reavaliacao = reavaliacao(imediata,
        'sem soro administrado, o risco de complicações graves persiste; buscar atendimento e soroterapia imediatamente',
        critica).


% =============================================================================
% REAVALIAÇÃO PÓS-SORO
% =============================================================================
% Critérios objetivos do manual para quando reavaliar UM PACIENTE JÁ TRATADO.

% reavaliacao_pos_soro(+Especie, -HorasAposSoro, -Motivo, -AcaoSeAlterado)
reavaliacao_pos_soro(bothrops, 24,
    'reavaliar Tempo de Coagulação (TC)',
    'se TC permanecer alterado: dose adicional de 2 ampolas de antiveneno').
reavaliacao_pos_soro(lachesis, 24,
    'reavaliar Tempo de Coagulação (TC)',
    'sem soro específico amplamente disponível: manter reavaliação clínica e de hemostasia').
reavaliacao_pos_soro(crotalus, 24,
    'reavaliar CK, mioglobinúria e diurese',
    'monitorar função renal; risco de instalação de insuficiência renal aguda até 48h').
reavaliacao_pos_soro(micrurus, 24,
    'manter observação clínica e ventilatória',
    'sintomas neurotóxicos podem ser tardios; risco de insuficiência respiratória mesmo após melhora inicial').


% =============================================================================
% PREDICADO DE CONVENIÊNCIA PARA O RELATÓRIO
% =============================================================================

% relatorio_evolucao(+Especie, +Grau, +TempoAtual, -SoroAdministrado, -Relatorio)
%
% Relatorio = evolucao(Timeline, ProximaReavaliacao)
% Ponto único de entrada para o back-end (routers/relatorio.py) montar o
% relatório: recebe Especie/Grau (vindos do motor de gravidade do colega),
% o tempo já decorrido e se o soro já foi administrado.
relatorio_evolucao(Especie, Grau, TempoAtual, nao, evolucao(Timeline, ProximaReavaliacao)) :-
    projecao_evolucao(Especie, Grau, TempoAtual, Timeline),
    proxima_reavaliacao_sem_soro(Especie, Grau, TempoAtual, ProximaReavaliacao).
relatorio_evolucao(Especie, _Grau, _TempoAtual, sim, evolucao([], ProximaReavaliacao)) :-
    reavaliacao_pos_soro(Especie, Horas, Motivo, Acao),
    ProximaReavaliacao = reavaliacao_pos_soro(Horas, Motivo, Acao).
