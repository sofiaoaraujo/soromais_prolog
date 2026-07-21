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
