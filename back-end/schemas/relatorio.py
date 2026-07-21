from pydantic import BaseModel
from typing import Optional
from uuid import UUID

class DadosRelatorio(BaseModel):
    nome: Optional[str] = None
    idade: Optional[int] = None
    peso: Optional[float] = None
    tempo: Optional[int] = None
    localPicada: Optional[str] = None
    estado: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    ponto_ref: Optional[str] = None
    nome_local: Optional[str] = None
    urbano_rural: Optional[str] = None

class DadosWhatsApp(BaseModel):
    hospital_id: UUID
    nome: Optional[str] = None
    localizacao: Optional[str] = None
    especie: Optional[str] = None
    lugar: Optional[str] = None
    efeitos: Optional[str] = None
    tempo_de_acao: Optional[str] = None
    foto_url: Optional[str] = None
