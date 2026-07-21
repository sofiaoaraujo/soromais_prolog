from fastapi import APIRouter, HTTPException
from schemas.triagem import TriagemRequest, ResultadoTriagem
from services.prolog_bridge import avaliar_caso

router = APIRouter(prefix="/triagem", tags=["triagem"])


@router.post("", response_model=ResultadoTriagem)
async def avaliar_triagem(dados: TriagemRequest):
    try:
        resultado = avaliar_caso(dados.model_dump())
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Motor de triagem indisponível: {str(e)}")

    return ResultadoTriagem(**resultado)
