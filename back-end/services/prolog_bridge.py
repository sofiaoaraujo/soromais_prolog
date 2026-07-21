import json
import os
import subprocess
from pathlib import Path

# Caminho do executável do SWI-Prolog. Assume que está no PATH ("swipl"), mas
# pode ser sobrescrito via env var em ambientes onde não está (ex: produção Linux).
_SWIPL = os.getenv("SWIPL_PATH", "swipl")
_BRIDGE_PL = Path(__file__).parent.parent / "prolog" / "bridge.pl"


def avaliar_caso(payload: dict) -> dict:
    resultado = subprocess.run(
        [_SWIPL, str(_BRIDGE_PL)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        encoding="utf-8",
    )

    print("\n=== PROLOG ===\n", resultado.stdout.strip(), "\n==============\n")

    if resultado.returncode != 0:
        raise RuntimeError(f"Erro ao rodar o motor Prolog: {resultado.stderr.strip()}")

    try:
        saida = json.loads(resultado.stdout)
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Motor Prolog retornou saída inválida: {resultado.stdout.strip()}") from e

    if "erro" in saida:
        raise RuntimeError(f"Motor Prolog não encontrou solução para o caso: {saida['erro']}")

    return saida
