from pydantic import BaseModel
from typing import Literal


class AtomoResposta(BaseModel):
    chave: str
    valor: str


class UniversalTriagem(BaseModel):
    tempo_h: float
    sintoma: Literal["sim", "nao"]


class TriagemRequest(BaseModel):
    tipo: str
    sintomas: list[AtomoResposta] = []
    flags: list[AtomoResposta] = []
    universal: UniversalTriagem


class ResultadoTriagem(BaseModel):
    tipo: str
    grau: str
    score: float
    max: float
    faixa: str
    conduta: str
    alertas: list[str]


class ExplicacaoTriagem(BaseModel):
    """Módulo 2 — cadeia de raciocínio, uma linha por passo."""
    explicacao: list[str]


class RelatorioTriagem(BaseModel):
    """
    Módulo 2 (relatório) — resultado da triagem + explicação +
    texto único já formatado, pronto pra acompanhar as respostas
    do paciente até o médico (ex: embutido no PDF do routers/relatorio.py
    ou no corpo da mensagem do routers/whatsapp.py).
    """
    resultado: ResultadoTriagem
    explicacao: list[str]
    relatorio_texto: str