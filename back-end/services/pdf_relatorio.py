import re
import requests
from io import BytesIO
from pathlib import Path
from datetime import datetime, timezone, timedelta
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak,
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.graphics.shapes import Drawing, Rect

# Logo oficial do app, copiado de front-end/public/icons/soromais_app_icon_512x512.png
# pra dentro do back-end (o PDF é gerado aqui, não tem como referenciar a
# pasta do front-end de forma confiável em produção).
_LOGO_PATH = Path(__file__).parent.parent / "assets" / "logo.png"

# ==========================================================
# Cores de destaque clínico.
#
# O vermelho é reservado para o que exige atenção imediata da
# equipe (sintoma que fechou o grau em "grave", flag que gerou
# alerta, classificação/conduta de maior gravidade) — a ideia é
# que, numa triagem, o olho da equipe médica seja puxado em
# frações de segundo pro que definiu a gravidade do caso, sem
# precisar ler o relatório inteiro primeiro.
# ==========================================================

_GRAU_CORES = {
    "grave": colors.HexColor('#B3261E'),
    "moderado": colors.HexColor('#B98900'),
    "leve": colors.HexColor('#0B6E4F'),
}

_CONDUTA_CORES = {
    "transporte_prioridade_maxima": colors.HexColor('#B3261E'),
    "transporte_imediato": colors.HexColor('#B3261E'),
    "hospital_encaminhamento": colors.HexColor('#B98900'),
    "observar_6h_unidade": colors.HexColor('#0B6E4F'),
    "alta_orientacoes": colors.HexColor('#0B6E4F'),
}

_CONDUTA_LEGIVEL = {
    "transporte_prioridade_maxima": "TRANSPORTE COM PRIORIDADE MÁXIMA",
    "transporte_imediato": "TRANSPORTE IMEDIATO",
    "hospital_encaminhamento": "Encaminhar ao hospital de referência",
    "observar_6h_unidade": "Manter em observação por 6h",
    "alta_orientacoes": "Alta com orientações",
}

_VERDE_ESCURO = colors.HexColor('#0B6E4F')
_CINZA_LINHA = colors.HexColor('#DDDDDD')

# ==========================================================
# Tradução dos nomes técnicos (átomos Prolog) pra rótulos em
# português, sem underline, pro médico ler direto — só troca a
# palavra que aparece na tela, não muda nenhum dado nem lógica.
# ==========================================================

_ROTULOS_TERMO = {
    "local": "Sinal local (dor/edema)",
    "sangramento": "Sangramento",
    "choque": "Choque",
    "diurese": "Diurese",
    "coagulacao_proxy": "Coagulação",
    "local_complicacao": "Complicação local",
    "vagais": "Sinais vagais",
    "neuro": "Sinal neurológico",
    "mialgia": "Mialgia",
    "urina_escura": "Urina escura",
    "progressao_craniocaudal": "Progressão craniocaudal",
    "respiratorio": "Insuficiência respiratória",
    "tipo": "Tipo de acidente",
    "contexto_risco": "Fator de risco",
    "interferencia": "Interferência no atendimento",
    "local_picada": "Local da picada",
}


def _rotulo_termo(nome: str) -> str:
    """Nome técnico -> rótulo legível. Cai num fallback genérico
    (troca '_' por espaço e capitaliza) se o termo não estiver
    mapeado, pra nunca vazar um nome cru na tela."""
    if nome in _ROTULOS_TERMO:
        return _ROTULOS_TERMO[nome]
    return nome.replace("_", " ").capitalize()


def _dividir_termo(termo: str):
    """'urina_escura(discreta)' -> ('urina_escura', 'discreta')."""
    m = re.match(r"^([a-zA-Z_]+)\((.+)\)$", termo)
    if m:
        return m.group(1), m.group(2)
    return termo, None


def _termo_legivel(termo: str) -> str:
    """'urina_escura(discreta)' -> 'Urina escura (discreta)'."""
    nome, valor = _dividir_termo(termo)
    rotulo = _rotulo_termo(nome)
    return f"{rotulo} ({valor})" if valor else rotulo


def _humanizar_condutas(texto: str) -> str:
    """Troca átomos de conduta entre aspas simples (ex: 'transporte_
    prioridade_maxima') pelo rótulo legível já usado no resto do
    relatório, só na apresentação — o texto/raciocínio em si não muda."""
    def substituir(m):
        atomo = m.group(1)
        legivel = _CONDUTA_LEGIVEL.get(atomo, atomo.replace("_", " "))
        return f"'{legivel}'"
    return re.sub(r"'([a-z0-9_]+)'", substituir, texto)


def _humanizar_termos_em_frase(texto: str) -> str:
    """Troca qualquer 'nome(valor)' embutido numa frase livre (ex: 'o
    sintoma decisivo foi urina_escura(discreta)') pelo rótulo legível,
    sem tocar no resto da frase."""
    def substituir(m):
        return _termo_legivel(m.group(0))
    return re.sub(r"\b[a-zA-Z_]+\([a-zà-ú]+\)", substituir, texto)


def _baixar_imagem(url: str, largura_max=8 * cm):
    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        img_buffer = BytesIO(resp.content)
        img = Image(img_buffer)
        proporcao = img.imageHeight / float(img.imageWidth)
        img.drawWidth = largura_max
        img.drawHeight = largura_max * proporcao
        return img
    except Exception as e:
        print(f'ERRO AO BAIXAR IMAGEM: {e}')
        return None


def _logo_cruz(lado=1.5 * cm):
    """Fallback: selo verde com uma cruz branca, desenhado, usado só se
    o arquivo de logo real (_LOGO_PATH) não for encontrado."""
    d = Drawing(lado, lado)
    raio = lado * 0.18
    d.add(Rect(0, 0, lado, lado, rx=raio, ry=raio, fillColor=_VERDE_ESCURO, strokeColor=None))
    espessura = lado * 0.22
    comprimento = lado * 0.62
    cx, cy = lado / 2, lado / 2
    d.add(Rect(cx - comprimento / 2, cy - espessura / 2, comprimento, espessura, fillColor=colors.white, strokeColor=None))
    d.add(Rect(cx - espessura / 2, cy - comprimento / 2, espessura, comprimento, fillColor=colors.white, strokeColor=None))
    return d


def _logo_app(lado=1.5 * cm):
    """Logo oficial do app (front-end/public/icons/soromais_app_icon_512x512.png,
    copiado pro back-end em services/../assets/logo.png). Se o arquivo não
    existir por algum motivo, cai de volta pro selo desenhado, pra nunca
    quebrar a geração do PDF por causa de um asset faltando."""
    if _LOGO_PATH.exists():
        try:
            img = Image(str(_LOGO_PATH))
            img.drawWidth = lado
            img.drawHeight = lado
            return img
        except Exception as e:
            print(f"ERRO AO CARREGAR LOGO: {e}")
    return _logo_cruz(lado)


# ----------------------------------------------------------
# Extração dos campos do texto único gerado por relatorio.pl
# (relatorio_json/5). Os padrões abaixo casam exatamente com o
# formato fixo que o próprio relatorio.pl/explicacao.pl emite —
# nenhuma regra clínica é recalculada aqui, só lida de volta.
# ----------------------------------------------------------

def _extrair(padrao, texto, grupo=1):
    m = re.search(padrao, texto, re.MULTILINE)
    return m.group(grupo).strip() if m else None


def _parse_termos(lista_str):
    """'neuro(discreto), mialgia(discreta)' -> [('neuro','discreto'), ...]"""
    if not lista_str or lista_str.strip().lower() == "nenhum":
        return []
    itens = [i.strip() for i in lista_str.split(",") if i.strip()]
    resultado = []
    for item in itens:
        m = re.match(r"^([a-zA-Z_]+)\((.+)\)$", item)
        if m:
            resultado.append((m.group(1), m.group(2)))
        else:
            resultado.append((item, ""))
    return resultado


def _extrair_dados_triagem(texto: str) -> dict:
    por_sintoma = re.findall(
        r"^(.+?) → grau (leve|moderado|grave), \+(\d+) ponto\(s\)$", texto, re.MULTILINE
    )
    alertas = re.findall(r"^Flag (.+?) → (.+)$", texto, re.MULTILINE)
    return {
        "tipo_serpente": _extrair(r"^Tipo de serpente/acidente:\s*(.+)$", texto),
        "tempo_picada": _extrair(r"^Tempo estimado desde a picada:\s*(.+)$", texto),
        "sintomas_raw": _extrair(r"^Sintomas marcados:\s*(.+)$", texto),
        "flags_raw": _extrair(r"^Fatores de contexto/flags:\s*(.+)$", texto),
        "classificacao": _extrair(r"^Classificação \(grau MS\):\s*(.+)$", texto),
        "score_linha": _extrair(r"^(Score de gravidade.+)$", texto),
        "conduta_recomendada": _extrair(r"^Conduta recomendada:\s*(.+)$", texto),
        "por_sintoma": por_sintoma,
        "grau_final_texto": _extrair(r"^(Grau final \(motor categórico\):.+)$", texto),
        "score_motor_texto": _extrair(r"^(Score \(motor de pontuação\):.+)$", texto),
        "conduta_agrav_texto": _extrair(r"^(Conduta (?:final|base para).+)$", texto),
        "alertas": alertas,
    }


def _tabela(linhas_paragrafos, larguras):
    t = Table(linhas_paragrafos, colWidths=larguras)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), _VERDE_ESCURO),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('LINEBELOW', (0, 0), (-1, -1), 0.5, _CINZA_LINHA),
        ('LINEBEFORE', (0, 0), (0, -1), 0.5, _CINZA_LINHA),
        ('LINEAFTER', (-1, 0), (-1, -1), 0.5, _CINZA_LINHA),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    return t


def gerar_pdf_relatorio(dados, hospital_nome: str) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=1.8 * cm, bottomMargin=1.8 * cm)
    styles = getSampleStyleSheet()

    titulo_style = ParagraphStyle('Titulo', parent=styles['Heading1'], textColor=_VERDE_ESCURO, spaceAfter=2)
    secao_style = ParagraphStyle('Secao', parent=styles['Heading2'], spaceBefore=14, spaceAfter=6)
    alerta_style = ParagraphStyle('Alerta', parent=styles['Heading2'], textColor=colors.HexColor('#B3261E'), spaceBefore=12, spaceAfter=6)
    subsub_style = ParagraphStyle('SubSub', parent=styles['Heading4'], textColor=_VERDE_ESCURO, fontName='Helvetica-BoldOblique', fontSize=10.5, spaceBefore=10, spaceAfter=4)
    normal = styles['Normal']
    bullet_style = ParagraphStyle('Bullet', parent=normal, leftIndent=10, spaceAfter=5)

    cel = ParagraphStyle('Cel', parent=normal, fontSize=9.3, leading=12.5)
    cel_bold = ParagraphStyle('CelBold', parent=cel, fontName='Helvetica-Bold')
    cel_header = ParagraphStyle('CelHeader', parent=cel_bold, textColor=colors.white)

    def cel_critica(texto, negrito=True):
        estilo = ParagraphStyle('CelCritica', parent=cel_bold if negrito else cel, textColor=colors.HexColor('#B3261E'))
        return Paragraph(texto, estilo)

    elementos = []

    # --- Cabeçalho com selo ---
    fuso_brasil = timezone(timedelta(hours=-3))
    agora_brasil = datetime.now(fuso_brasil)
    bloco_titulo = [
        Paragraph("RELATÓRIO DE ACIDENTE - SOROMAIS", titulo_style),
        Paragraph(f"Gerado em: {agora_brasil.strftime('%d/%m/%Y %H:%M')}", normal),
        Paragraph(f"Hospital de destino: {hospital_nome}", normal),
    ]
    cabecalho = Table([[_logo_app(), bloco_titulo]], colWidths=[2.1 * cm, 14 * cm])
    cabecalho.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (1, 0), (1, 0), 12),
        ('LEFTPADDING', (0, 0), (0, 0), 0),
    ]))
    elementos.append(cabecalho)
    elementos.append(Spacer(1, 0.5 * cm))

    foto_url = getattr(dados, "foto_url", None)
    if foto_url:
        imagem = _baixar_imagem(foto_url)
        if imagem:
            elementos.append(imagem)
            elementos.append(Spacer(1, 0.3 * cm))

    if dados.especie:
        elementos.append(Paragraph("Animal Identificado", secao_style))
        elementos.append(Paragraph(
            f'<b>Espécie:</b> <span backColor="#DCEFE6">{dados.especie}</span>', normal
        ))
        if dados.lugar:
            elementos.append(Paragraph(f"<b>Habitat/Ocorrência:</b> {dados.lugar}", normal))
        if dados.tempo_de_acao:
            elementos.append(Paragraph(f"<b>Tempo de ação do veneno:</b> {dados.tempo_de_acao}", normal))

    if dados.efeitos:
        elementos.append(Paragraph("Efeitos do Veneno", alerta_style))
        for linha in dados.efeitos.split('\n'):
            linha = linha.strip().lstrip('-').strip()
            if linha:
                elementos.append(Paragraph(f"• {linha}", normal))

    # --- Módulo 2: Triagem clínica ---
    conduta_triagem = getattr(dados, "conduta_triagem", None)
    relatorio_triagem = getattr(dados, "relatorio_triagem", None)
    grau_triagem = getattr(dados, "grau_triagem", None)

    if conduta_triagem or relatorio_triagem:
        elementos.append(Paragraph("Triagem Clínica (SoroMais)", secao_style))

        if grau_triagem:
            cor_grau = _GRAU_CORES.get(grau_triagem, colors.black)
            elementos.append(Paragraph(
                f'Grau: <font color="{cor_grau.hexval()}"><b>{grau_triagem.upper()}</b></font>', normal
            ))
        if conduta_triagem:
            cor_conduta = _CONDUTA_CORES.get(conduta_triagem, colors.HexColor('#B98900'))
            texto_conduta = _CONDUTA_LEGIVEL.get(conduta_triagem, conduta_triagem)
            conduta_destaque_style = ParagraphStyle(
                'CondutaDestaque', parent=normal, textColor=cor_conduta,
                fontName='Helvetica-BoldOblique', spaceBefore=2,
            )
            elementos.append(Paragraph(f"Conduta recomendada: {texto_conduta}", conduta_destaque_style))

    # --- Dados da Vítima (tabela) ---
    elementos.append(Paragraph("Dados da Vítima", secao_style))
    linhas_vitima = [
        [Paragraph("Campo", cel_header), Paragraph("Informação", cel_header)],
        [Paragraph("Nome", cel_bold), Paragraph(dados.nome or "Não informado", cel)],
    ]
    if dados.localizacao:
        linhas_vitima.append([Paragraph("Localização", cel_bold), Paragraph(dados.localizacao, cel)])
    elementos.append(_tabela(linhas_vitima, [5.5 * cm, 10 * cm]))

    # --- Bloco detalhado da triagem (páginas seguintes) ---
    if relatorio_triagem:
        d = _extrair_dados_triagem(relatorio_triagem)

        if d["por_sintoma"] or d["tipo_serpente"]:
            elementos.append(PageBreak())

            elementos.append(Paragraph("Dados do Acidente (informados pelo paciente/socorrista)", secao_style))
            linhas_dados = [[Paragraph("Campo", cel_header), Paragraph("Informação", cel_header)]]
            if d["tipo_serpente"]:
                linhas_dados.append([Paragraph("Tipo de serpente/acidente", cel_bold), Paragraph(d["tipo_serpente"], cel)])
            if d["tempo_picada"]:
                linhas_dados.append([Paragraph("Tempo estimado desde a picada", cel_bold), Paragraph(d["tempo_picada"], cel)])
            elementos.append(_tabela(linhas_dados, [7 * cm, 8.5 * cm]))

            # Sintomas marcados — grau "grave" em vermelho: foi o que
            # fechou (ou ajudou a fechar) a classificação do caso.
            termos_sintomas = _parse_termos(d["sintomas_raw"])
            if termos_sintomas:
                grau_por_termo = {termo: grau for termo, grau, _ in d["por_sintoma"]}
                elementos.append(Paragraph("Sintomas marcados:", subsub_style))
                linhas_sint = [[Paragraph("Sintoma", cel_header), Paragraph("Intensidade / Status", cel_header)]]
                for nome, valor in termos_sintomas:
                    termo = f"{nome}({valor})"
                    grave = grau_por_termo.get(termo) == "grave"
                    rotulo_nome = _rotulo_termo(nome)
                    if grave:
                        linhas_sint.append([cel_critica(rotulo_nome), cel_critica(valor)])
                    else:
                        linhas_sint.append([Paragraph(rotulo_nome, cel_bold), Paragraph(valor, cel)])
                elementos.append(_tabela(linhas_sint, [7 * cm, 8.5 * cm]))

            # Flags/fatores de contexto — sempre em destaque: por
            # definição, todo flag reconhecido pelo motor gera alerta
            # clínico (ver alerta/2), então merece atenção da equipe.
            termos_flags = _parse_termos(d["flags_raw"])
            if termos_flags:
                elementos.append(Paragraph("Fatores de contexto/flags:", subsub_style))
                linhas_flags = [[Paragraph("Fator", cel_header), Paragraph("Detalhe", cel_header)]]
                for nome, valor in termos_flags:
                    linhas_flags.append([cel_critica(_rotulo_termo(nome)), cel_critica(valor)])
                elementos.append(_tabela(linhas_flags, [7 * cm, 8.5 * cm]))

            if d["alertas"]:
                elementos.append(Paragraph("ALERTA", secao_style))
                for flag_termo, texto_alerta in d["alertas"]:
                    elementos.append(Paragraph(f"• <b>{_termo_legivel(flag_termo)}:</b> {texto_alerta}", bullet_style))

            elementos.append(Paragraph("Resultado da Triagem (motor de inferência)", secao_style))
            linhas_resultado = [[Paragraph("Indicador", cel_header), Paragraph("Resultado", cel_header)]]
            if d["classificacao"]:
                linhas_resultado.append([
                    Paragraph("Classificação (grau MS)", cel_bold),
                    cel_critica(d["classificacao"]) if d["classificacao"].lower() == "grave"
                    else Paragraph(d["classificacao"], cel_bold),
                ])
            if d["score_linha"]:
                rotulo, _, resto = d["score_linha"].partition(":")
                linhas_resultado.append([Paragraph(rotulo, cel_bold), Paragraph(resto.strip(), cel)])
            if d["conduta_recomendada"]:
                critico = conduta_triagem in ("transporte_imediato", "transporte_prioridade_maxima")
                linhas_resultado.append([
                    Paragraph("Conduta recomendada", cel_bold),
                    cel_critica(d["conduta_recomendada"]) if critico else Paragraph(d["conduta_recomendada"], cel_bold),
                ])
            elementos.append(_tabela(linhas_resultado, [7 * cm, 8.5 * cm]))

            # --- Raciocínio do motor (Módulo 2) ---
            elementos.append(PageBreak())
            elementos.append(Paragraph("Raciocínio do Motor (auditável, gerado automaticamente)", secao_style))

            if d["por_sintoma"]:
                elementos.append(Paragraph("Por sintoma:", subsub_style))
                linhas_raciocinio = [[
                    Paragraph("Sintoma Avaliado", cel_header),
                    Paragraph("Grau", cel_header),
                    Paragraph("Pontuação", cel_header),
                ]]
                for termo, grau, pontos in d["por_sintoma"]:
                    linhas_raciocinio.append([
                        Paragraph(_termo_legivel(termo), cel_bold),
                        Paragraph(grau, cel),
                        Paragraph(f"+{pontos} ponto(s)", cel),
                    ])
                elementos.append(_tabela(linhas_raciocinio, [7 * cm, 4 * cm, 4.5 * cm]))

            if d["grau_final_texto"]:
                elementos.append(Paragraph("Grau final", subsub_style))
                elementos.append(Paragraph(_humanizar_termos_em_frase(d["grau_final_texto"]), normal))
            if d["score_motor_texto"]:
                elementos.append(Paragraph("Score", subsub_style))
                elementos.append(Paragraph(d["score_motor_texto"], normal))
            if d["conduta_agrav_texto"]:
                elementos.append(Paragraph("Conduta e agravamentos", subsub_style))
                elementos.append(Paragraph(_humanizar_condutas(d["conduta_agrav_texto"]), normal))

    # --- Rodapé / aviso ---
    elementos.append(Spacer(1, 0.6 * cm))
    rodape = Table(
        [[_logo_app(1.1 * cm), Paragraph(
            "Este relatório foi gerado automaticamente pelo SoroMais a partir das respostas "
            "do paciente/socorrista e não substitui a avaliação clínica presencial.", normal
        )]],
        colWidths=[1.6 * cm, 14.5 * cm],
    )
    rodape.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'MIDDLE'), ('LEFTPADDING', (1, 0), (1, 0), 10)]))
    elementos.append(rodape)

    doc.build(elementos)
    return buffer.getvalue()