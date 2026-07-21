:- encoding(utf8).

% ==========================================================
% conhecimento_ms.pl
% Base de fatos derivada do Quadro 1 do Ministério da Saúde
% (Guia de Vigilância em Saúde, 6ª ed., 2024)
%
% Predicado principal: sintoma_grau/3
%   sintoma_grau(TipoAcidente, Sintoma, Grau)
%   "no acidente T, o sintoma S dispara o grau G"
%
% Convenção: ausência de fato = sintoma não gradua.
% ==========================================================

% ----------------------------------------------------------
% BOTRÓPICO (jararaca, urutu, caissaca)
% ----------------------------------------------------------

% Sinal local (dor, edema, equimose)
sintoma_grau(botropico, local(discreto), leve).
sintoma_grau(botropico, local(evidente), moderado).
sintoma_grau(botropico, local(intenso), grave).

% Sangramento sistêmico (gengiva, nariz, pele, urina, vômito)
sintoma_grau(botropico, sangramento(discreto), leve).
sintoma_grau(botropico, sangramento(moderado), moderado).
sintoma_grau(botropico, sangramento(intenso), grave).

% Choque hipovolêmico (tontura, desmaio, suor frio, palidez)
sintoma_grau(botropico, choque(sim), grave).

% Alteração renal (redução ou parada da diurese)
sintoma_grau(botropico, diurese(oliguria), grave).
sintoma_grau(botropico, diurese(anuria), grave).

%Coagulação (normal, alterada, desconhecida)
sintoma_grau(botropico, coagulacao_proxy(alterada),leve).

% Complicações locais (não, bolhas, escurecimento, ambos)
sintoma_grau(botropico, local_complicacao(bolhas), moderado).
sintoma_grau(botropico, local_complicacao(necrose), grave).
sintoma_grau(botropico, local_complicacao(ambos), grave).

% ----------------------------------------------------------
% LAQUÉTICO (surucucu)
% Peculiaridades: não existe caso leve; o sinal vagal é o
% discriminador clínico contra o botrópico grave.
% ----------------------------------------------------------

% Sinal local (dor, edema, equimose)
sintoma_grau(laquetico, local(evidente), moderado).
sintoma_grau(laquetico, local(intenso), grave).

% Sangramento sistêmico (gengiva, nariz, pele, urina, vômito)
sintoma_grau(laquetico, sangramento(intenso), grave).

% Síndrome vagal (náusea, vômito, cólica, diarreia) — confirma laquético
sintoma_grau(laquetico, vagais(sim), grave).

% Coagulopatia (proxy: sangramento persistente no local sem coagular)
sintoma_grau(laquetico, coagulacao_proxy(alterada), moderado).

% Complicações locais (bolhas serosas/hemorrágicas, necrose)
sintoma_grau(laquetico, local_complicacao(bolhas), moderado).
sintoma_grau(laquetico, local_complicacao(necrose), grave).
sintoma_grau(laquetico, local_complicacao(ambas), grave).

% ----------------------------------------------------------
% CROTÁLICO (cascavel)
% Peculiaridades: quadro neuroparalítico (fácies miastênica),
% mialgia com mioglobinúria e comprometimento renal por
% rabdomiólise. O sinal neuro discreto isolado é o único
% caminho pro grau leve.
% ----------------------------------------------------------

% Sinal neurológico (ptose palpebral, visão embaçada, fácies miastênica)
sintoma_grau(crotalico, neuro(discreto), leve).
sintoma_grau(crotalico, neuro(evidente), moderado).

% Mialgia (dor muscular difusa por rabdomiólise)
sintoma_grau(crotalico, mialgia(discreta), moderado).
sintoma_grau(crotalico, mialgia(intensa), grave).

% Mioglobinúria (urina escura por lesão muscular)
sintoma_grau(crotalico, urina_escura(discreta), moderado).
sintoma_grau(crotalico, urina_escura(intensa), grave).

% Alteração renal (oligúria por rabdomiólise/insuficiência renal)
sintoma_grau(crotalico, diurese(oliguria), grave).

% Progressão craniocaudal (sialorreia, disfagia, voz enfraquecida)
sintoma_grau(crotalico, progressao_craniocaudal(sim), moderado).

% Insuficiência respiratória (raro, mas descrito no MS)
sintoma_grau(crotalico, respiratorio(sim), grave).

% ----------------------------------------------------------
% ELAPÍDICO / coral (Micrurus)
% Peculiaridade (Opção A): todo acidente elapídico é grave
% por definição do tipo — o fato `tipo(elapidico)` como
% "sintoma" dispara grave sozinho. Sinais respiratórios e
% de progressão craniocaudal reforçam o grave e vão ativar
% alertas de transporte na camada de recomendação.
% ----------------------------------------------------------

% Tipo elapídico = grave por definição (risco de insuficiência respiratória)
sintoma_grau(elapidico, tipo(elapidico), grave).

% Insuficiência respiratória (musculatura torácica comprometida)
sintoma_grau(elapidico, respiratorio(sim), grave).

% Progressão da paralisia flácida (sialorreia, disfagia, fácies caindo)
sintoma_grau(elapidico, progressao_craniocaudal(sim), grave).