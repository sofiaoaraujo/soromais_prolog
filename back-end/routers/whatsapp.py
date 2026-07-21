import os
import uuid
from fastapi import APIRouter
from twilio.rest import Client
from schemas.relatorio import DadosWhatsApp
from dependencies import supabase
from services.pdf_relatorio import gerar_pdf_relatorio

router = APIRouter(prefix="/enviar-whatsapp", tags=["notificacao"])

BUCKET = "relatorios"

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
        to=f"whatsapp:{telefone}",
    )
    return {"sucesso": True, "sid": message.sid, "pdf_url": url_publica}
