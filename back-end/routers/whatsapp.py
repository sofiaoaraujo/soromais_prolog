import os
import re
import uuid
from fastapi import APIRouter
from twilio.rest import Client
from schemas.relatorio import DadosWhatsApp
from dependencies import supabase
from services.pdf_relatorio import gerar_pdf_relatorio

router = APIRouter(prefix="/enviar-whatsapp", tags=["notificacao"])

BUCKET = "relatorios"


def _formatar_e164(telefone: str) -> str:
    """
    Normaliza um telefone pro formato E.164 exigido pelo Twilio:
    só dígitos, com código do país na frente, prefixado por '+'.
    Ex: "83 3281-2640" -> "+558332812640"
        "+55 83 99999-0000" -> "+5583999990000"
    Assume Brasil (55) quando o número não vem com código de país.
    """
    digitos = re.sub(r"\D", "", telefone or "")
    if not digitos:
        return telefone
    if not digitos.startswith("55"):
        digitos = "55" + digitos
    return f"+{digitos}"


@router.post("")
async def enviar_whatsapp(dados: DadosWhatsApp):
    hospital = supabase.table("hospital").select("*").eq("id", str(dados.hospital_id)).execute()
    if not hospital.data:
        return {"erro": "Hospital não encontrado"}
    telefone = hospital.data[0].get("telefone")
    if not telefone:
        return {"erro": "Hospital sem telefone cadastrado"}
    hospital_nome = hospital.data[0].get("nome", "Hospital")

    pdf_bytes = gerar_pdf_relatorio(dados, hospital_nome)
    nome_arquivo = f"relatorio_{uuid.uuid4()}.pdf"

    supabase.storage.from_(BUCKET).upload(
        nome_arquivo,
        pdf_bytes,
        {"content-type": "application/pdf"},
    )
    url_publica = supabase.storage.from_(BUCKET).get_public_url(nome_arquivo)

    twilio = Client(os.getenv("TWILIO_ACCOUNT_SID"), os.getenv("TWILIO_AUTH_TOKEN"))

    legenda = (
        f"*RELATÓRIO DE ACIDENTE - SOROMAIS*\n"
        f"Espécie: {dados.especie or 'Não identificado'}\n"
        f"Paciente: {dados.nome or 'Não informado'}"
    )

    message = twilio.messages.create(
        from_=f"whatsapp:{os.getenv('TWILIO_WHATSAPP_NUMBER')}",
        body=legenda,
        media_url=[url_publica],
        to=f"whatsapp:{_formatar_e164(telefone)}",
    )
    return {"sucesso": True, "sid": message.sid, "pdf_url": url_publica}