from fastapi import APIRouter, HTTPException
from schemas.triagem import (
    TriagemRequest,
    ResultadoTriagem,
    ExplicacaoTriagem,
    RelatorioTriagem,
)
from services.prolog_bridge import avaliar_caso, explicar_caso, gerar_relatorio_caso

router = APIRouter(prefix="/triagem", tags=["triagem"])


@router.post("", response_model=ResultadoTriagem)
async def avaliar_triagem(dados: TriagemRequest):
    try:
        resultado = avaliar_caso(dados.model_dump())
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Motor de triagem indisponível: {str(e)}")

    return ResultadoTriagem(**resultado)


@router.post("/explicacao", response_model=ExplicacaoTriagem)
async def explicar_triagem(dados: TriagemRequest):
    """
    Módulo 2 — reconstrói a cadeia de raciocínio do motor
    (por sintoma, grau final, score, conduta, alertas) em
    texto legível.
    """
    try:
        resultado = explicar_caso(dados.model_dump())
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Motor de explicação indisponível: {str(e)}")

    return ExplicacaoTriagem(**resultado)


@router.post("/relatorio", response_model=RelatorioTriagem)
async def relatorio_triagem(dados: TriagemRequest):
    """
    Módulo 2 (relatório) — resultado + explicação + texto único
    já formatado, pronto pra acompanhar as respostas do paciente
    até o médico/hospital (ex: seção extra no PDF de
    routers/relatorio.py + routers/whatsapp.py).
    """
    try:
        resultado = gerar_relatorio_caso(dados.model_dump())
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Motor de relatório indisponível: {str(e)}")

    return RelatorioTriagem(**resultado)