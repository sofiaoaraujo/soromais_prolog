:- encoding(utf8).

% ==========================================================
% main.pl
% Ponto de entrada do motor Soromais.
%
% Carrega o motor completo. Ferramentas externas (back-end
% FastAPI, testes, integração com Luciana e Pierre) devem
% consultar este arquivo e chamar avaliar/5 para usar o
% motor sem depender da estrutura interna dos arquivos.
%
% Interface pública:
%   avaliar(Tipo, Sintomas, Flags, Universal, Resultado)
%
% Estrutura interna carregada:
%   conhecimento_ms.pl — base de fatos do Quadro 1 (MS)
%   pesos.pl           — tabelas de pesos e faixas
%   motor.pl           — motores + orquestração + alertas
% ==========================================================

:- consult('motor.pl').