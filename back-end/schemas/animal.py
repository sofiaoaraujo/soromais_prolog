from pydantic import BaseModel
from typing import Optional

class AnaliseAnimal(BaseModel):
    especie: str
    lugar: str
    efeitos: str
    tempo_de_acao: str
    o_que_fazer: str
    genero: str

class RespostaIdentificacao(BaseModel):
    status: str
    arquivo: str
    analise_ia: AnaliseAnimal
    foto_url: Optional[str] = None
