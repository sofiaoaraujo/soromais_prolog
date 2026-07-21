import json
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from typing import Optional
from google.genai import types
from schemas.animal import RespostaIdentificacao
from dependencies import gemini_client, supabase
import uuid

router = APIRouter(prefix="/identificar-animal", tags=["identificacao"])

_GENEROS_VALIDOS = ["Bothrops", "Crotalus", "Lachesis", "Micrurus","Leptomicrurus"]
_GENERO_NAO_PECONHENTA = "nao_peconhenta"
_VALORES_GENERO_VALIDOS = set(_GENEROS_VALIDOS) | {_GENERO_NAO_PECONHENTA}

_ANIMAL_SCHEMA = {
    "especie": "Nome popular (ex: Jararaca)",
    "lugar": "Regiões do país e habitats comuns onde é encontrado",
    "efeitos": "Principais sintomas e efeitos do veneno no corpo humano",
    "tempo_de_acao": "Tempo estimado para agravamento ou risco de morte sem socorro",
    "o_que_fazer": "Primeiros socorros específicos para esse animal, do momento da picada/ataque até a chegada ao hospital",
    "genero": f"Um dos gêneros peçonhentos: Bothrops, Crotalus, Lachesis, Micrurus ou Leptomicrurus — ou '{_GENERO_NAO_PECONHENTA}' se a espécie identificada não for peçonhenta",
}


def _build_prompt(localizacao: str) -> str:
    contexto_geo = f"\nLocalização do incidente: {localizacao}" if localizacao else ""
    generos = ", ".join(_GENEROS_VALIDOS)
    return f"""Você é um especialista em serpentes peçonhentas do Brasil.
Analise a imagem e retorne SOMENTE um objeto JSON válido, sem texto adicional, sem markdown, sem explicações.{contexto_geo}

Regras para os valores:
- Identifique a espécie real da serpente, mesmo que não seja peçonhenta ou não pertença a nenhum dos gêneros abaixo
- O campo "genero" deve ser exatamente um destes valores: {generos}, {_GENERO_NAO_PECONHENTA}
- Se a espécie não for peçonhenta ou não pertencer a nenhum desses gêneros, use genero: "{_GENERO_NAO_PECONHENTA}" (preencha os demais campos normalmente com informações reais sobre essa espécie, como ausência de veneno e cuidados com a mordida)
- Sem emojis em nenhum campo
- Textos curtos e diretos, máximo 2 linhas por campo
- O campo "efeitos" deve ser uma lista de 3 a 4 tópicos separados por '\\n', cada um começando com '- '
- O campo "lugar" deve citar apenas regiões/biomas, sem detalhes extensos
- O campo "tempo_de_acao" deve ser uma frase curta (ex: "Sintomas em 30min, risco de morte em 6-24h sem tratamento")
- O campo "o_que_fazer" deve ser uma lista de 4 a 5 tópicos separados por '\\n', cada um começando com '- ', com condutas de primeiros socorros ESPECÍFICAS para essa serpente (ex: manter o membro imobilizado e abaixo do nível do coração; NUNCA sugerir torniquete, sucção, cortes ou remédios caseiros). A foto do animal já foi enviada e a espécie já foi identificada — NUNCA inclua orientações como "tire uma foto do animal" ou "fotografe o animal para identificação"
- Use a localização do incidente (se fornecida) para priorizar espécies nativas dessa região

O JSON deve ter exatamente estas chaves:
{json.dumps(_ANIMAL_SCHEMA, ensure_ascii=False, indent=2)}
"""


@router.post("", response_model=RespostaIdentificacao)
async def identificar_animal(
    file: UploadFile = File(...),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    ponto_ref: Optional[str] = Form(None),
):
    imagem_bytes = await file.read()
    mime_type = file.content_type or "image/jpeg"

    extensao = mime_type.split("/")[-1] or "jpg"
    nome_arquivo = f"{uuid.uuid4()}.{extensao}"
    supabase.storage.from_("fotos-animais").upload(
        nome_arquivo, imagem_bytes, {"content-type": mime_type}
    )
    foto_url = supabase.storage.from_("fotos-animais").get_public_url(nome_arquivo)

    localizacao = ponto_ref or (f"lat {lat}, lng {lng} (Brasil)" if lat and lng else "")
    prompt = _build_prompt(localizacao)

    conteudo = [
        types.Part.from_bytes(data=imagem_bytes, mime_type=mime_type),
        prompt,
    ]

    try:
        response = gemini_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=conteudo,
        )

        raw = response.text.strip()
        print("\n=== GEMINI ===\n", raw, "\n==============\n")

        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1].rsplit("```", 1)[0].strip()

        analise = json.loads(raw)

        if analise.get("genero") not in _VALORES_GENERO_VALIDOS:
            analise["genero"] = _GENERO_NAO_PECONHENTA

        return RespostaIdentificacao(
            status="sucesso",
            arquivo=file.filename,
            analise_ia=analise,
            foto_url=foto_url,
        )

    except json.JSONDecodeError as e:
        raise HTTPException(status_code=422, detail=f"IA retornou resposta mal formatada: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Não foi possível processar a imagem: {str(e)}")


@router.post("/por-nome", response_model=RespostaIdentificacao)
async def identificar_por_nome(nome_animal: str = Form(...)):
    generos = ", ".join(_GENEROS_VALIDOS)
    prompt = f"""Você é um especialista em serpentes peçonhentas do Brasil.
A espécie é "{nome_animal}". Retorne SOMENTE um objeto JSON válido, sem texto adicional, sem markdown, sem explicações.

Regras para os valores:
- Identifique a espécie real da serpente, mesmo que não seja peçonhenta ou não pertença a nenhum dos gêneros abaixo
- O campo "genero" deve ser exatamente um destes valores: {generos}, {_GENERO_NAO_PECONHENTA}
- Se a espécie não for peçonhenta ou não pertencer a nenhum desses gêneros, use genero: "{_GENERO_NAO_PECONHENTA}" (preencha os demais campos normalmente com informações reais sobre essa espécie, como ausência de veneno e cuidados com a mordida)
- Sem emojis em nenhum campo
- Textos curtos e diretos, máximo 2 linhas por campo
- O campo "efeitos" deve ser uma lista de 3 a 4 tópicos separados por '\\n', cada um começando com '- '
- O campo "lugar" deve citar apenas regiões/biomas, sem detalhes extensos
- O campo "tempo_de_acao" deve ser uma frase curta (ex: "Sintomas em 30min, risco de morte em 6-24h sem tratamento")
- O campo "o_que_fazer" deve ser uma lista de 4 a 5 tópicos separados por '\\n', cada um começando com '- ', com condutas de primeiros socorros ESPECÍFICAS para essa serpente (ex: manter o membro imobilizado e abaixo do nível do coração; NUNCA sugerir torniquete, sucção, cortes ou remédios caseiros). A foto do animal já foi enviada e a espécie já foi identificada — NUNCA inclua orientações como "tire uma foto do animal" ou "fotografe o animal para identificação"

O JSON deve ter exatamente estas chaves:
{json.dumps(_ANIMAL_SCHEMA, ensure_ascii=False, indent=2)}
"""

    try:
        response = gemini_client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )

        raw = response.text.strip()
        print("\n=== GEMINI POR NOME ===\n", raw, "\n======================\n")

        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1].rsplit("```", 1)[0].strip()

        analise = json.loads(raw)

        if analise.get("genero") not in _VALORES_GENERO_VALIDOS:
            analise["genero"] = _GENERO_NAO_PECONHENTA

        return RespostaIdentificacao(
            status="sucesso",
            arquivo=nome_animal,
            analise_ia=analise,
        )

    except json.JSONDecodeError as e:
        raise HTTPException(status_code=422, detail=f"IA retornou resposta mal formatada: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Não foi possível processar: {str(e)}")