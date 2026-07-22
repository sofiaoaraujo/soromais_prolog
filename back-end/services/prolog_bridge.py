import json
import os
import subprocess
from pathlib import Path

# Caminho do executável do SWI-Prolog. Assume que está no PATH ("swipl"), mas
# pode ser sobrescrito via env var em ambientes onde não está (ex: produção Linux).
_SWIPL = os.getenv("SWIPL_PATH", "swipl")
_PROLOG_DIR = Path(__file__).parent.parent / "prolog"
_BRIDGE_PL = _PROLOG_DIR / "bridge.pl"
_BRIDGE_EXPLICACAO_PL = _PROLOG_DIR / "bridge_explicacao.pl"
_BRIDGE_RELATORIO_PL = _PROLOG_DIR / "bridge_relatorio.pl"


def _rodar_bridge(caminho_pl: Path, payload: dict) -> dict:
    """
    Mecânica compartilhada por todas as pontes Prolog do projeto
    (Módulo 1 - avaliar, Módulo 2 - explicar, relatório): sobe um
    processo swipl, manda o payload como JSON pelo stdin, lê o
    JSON de volta pelo stdout.
    """
    resultado = subprocess.run(
        [_SWIPL, str(caminho_pl)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )

    print(f"\n=== PROLOG ({caminho_pl.name}) ===\n", resultado.stdout.strip(), "\n==============\n")

    if resultado.returncode != 0:
        raise RuntimeError(f"Erro ao rodar o motor Prolog ({caminho_pl.name}): {resultado.stderr.strip()}")

    try:
        saida = json.loads(resultado.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Motor Prolog ({caminho_pl.name}) retornou saída inválida: {resultado.stdout.strip()}") from e

    if "erro" in saida:
        raise RuntimeError(f"Motor Prolog ({caminho_pl.name}) não encontrou solução para o caso: {saida['erro']}")

    return saida


def avaliar_caso(payload: dict) -> dict:
    """Módulo 1 — grau/score/faixa/conduta/alertas via avaliar/5 (bridge.pl)."""
    return _rodar_bridge(_BRIDGE_PL, payload)


def explicar_caso(payload: dict) -> dict:
    """Módulo 2 — cadeia de raciocínio via explicar/5 (bridge_explicacao.pl)."""
    return _rodar_bridge(_BRIDGE_EXPLICACAO_PL, payload)


def gerar_relatorio_caso(payload: dict) -> dict:
    """
    Módulo 2 (relatório) — resultado + explicação + texto único
    já formatado, via relatorio_json/5 (bridge_relatorio.pl).
    """
    return _rodar_bridge(_BRIDGE_RELATORIO_PL, payload)