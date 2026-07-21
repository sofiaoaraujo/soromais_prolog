import requests
from io import BytesIO
from datetime import datetime, timezone, timedelta
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle


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


def gerar_pdf_relatorio(dados, hospital_nome: str) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=2 * cm, bottomMargin=2 * cm)
    styles = getSampleStyleSheet()

    titulo_style = ParagraphStyle('Titulo', parent=styles['Heading1'], textColor=colors.HexColor('#0B6E4F'))
    secao_style = ParagraphStyle('Secao', parent=styles['Heading2'], spaceBefore=12, spaceAfter=6)
    alerta_style = ParagraphStyle('Alerta', parent=styles['Heading2'], textColor=colors.HexColor('#B3261E'), spaceBefore=12, spaceAfter=6)
    normal = styles['Normal']

    elementos = []
    elementos.append(Paragraph("RELATÓRIO DE ACIDENTE - SOROMAIS", titulo_style))
    fuso_brasil = timezone(timedelta(hours=-3))
    agora_brasil = datetime.now(fuso_brasil)
    elementos.append(Paragraph(f"Gerado em: {agora_brasil.strftime('%d/%m/%Y %H:%M')}", normal))
    elementos.append(Paragraph(f"Hospital de destino: {hospital_nome}", normal))
    elementos.append(Spacer(1, 0.5 * cm))

    foto_url = getattr(dados, "foto_url", None)
    if foto_url:
        imagem = _baixar_imagem(foto_url)
        if imagem:
            elementos.append(imagem)
            elementos.append(Spacer(1, 0.3 * cm))

    if dados.especie:
        elementos.append(Paragraph("Animal Identificado", secao_style))
        elementos.append(Paragraph(f"<b>Espécie:</b> {dados.especie}", normal))
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

    elementos.append(Paragraph("Dados da Vítima", secao_style))
    dados_vitima = [
        ["Nome", dados.nome or "Não informado"]
    ]
    tabela = Table(dados_vitima, colWidths=[5 * cm, 10 * cm])
    tabela.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('LINEBELOW', (0, 0), (-1, -1), 0.5, colors.HexColor('#CCCCCC')),
    ]))
    elementos.append(tabela)

    if dados.localizacao:
        elementos.append(Paragraph("Localização", secao_style))
        elementos.append(Paragraph(dados.localizacao, normal))

    doc.build(elementos)
    return buffer.getvalue()
