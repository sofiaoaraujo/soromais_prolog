# SoroMais

Aplicativo web que identifica serpentes peçonhentas por foto ou descrição, orienta os primeiros socorros e conecta a vítima ao hospital de referência com soro antiofídico mais próximo — em poucos toques, direto do celular.

![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.136-009688?logo=fastapi&logoColor=white)
![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20PostGIS-3ECF8E?logo=supabase&logoColor=white)
![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)

## Sobre o projeto

Acidentes com serpentes peçonhentas exigem atendimento rápido e específico: perder tempo procurando qual hospital certo pode ser fatal. O SoroMais nasceu para reduzir esse tempo de resposta.

O usuário tira uma foto do animal (ou descreve o que viu), a IA identifica a espécie e o gênero, o app já busca no mapa o hospital de referência mais próximo baseado nos Dados Oficiais da PESA(Ponto Estratégico de Soro Antiveneno)(calculado via geolocalização/PostGIS) e monta um relatório do acidente — enviado por WhatsApp direto para o hospital, com PDF anexado, antes mesmo da vítima chegar lá.

**Público-alvo**: vítimas de acidentes ofídicos, acompanhantes e socorristas em campo (zona rural/áreas remotas), principalmente na *Paraíba*, onde a base de hospitais de referência já está mapeada.

**Status**: em desenvolvimento (MVP funcional, com fluxo completo de identificação → hospital → envio de relatório).

## Funcionalidades principais

- 📷 **Identificação por foto** — envia uma imagem da serpente e recebe espécie, gênero (Bothrops, Crotalus, Lachesis ou Micrurus), habitat, efeitos do veneno, tempo de ação e primeiros socorros, via Gemini.
- ✍️ **Identificação por descrição** — quando não dá para tirar foto, o usuário descreve o animal em texto e a IA sugere as 4 espécies mais prováveis (com imagem de referência) para o usuário escolher.
- 🏥 **Hospitais de referência mais próximos** — busca geoespacial (PostGIS) que retorna os 5 hospitais com soro antiofídico mais próximos da localização do usuário, com rota e telefone.
- 📍 **Geolocalização e endereço automático** — captura a posição do usuário e converte em endereço legível.
- 📄 **Relatório em PDF** — gera um relatório do acidente (foto, espécie, efeitos, dados da vítima, localização) pronto para enviar ao hospital.
- 💬 **Envio direto por WhatsApp** — dispara o relatório em PDF para o hospital escolhido via Twilio.
- 📱 **PWA (instalável)** — funciona como web app no celular, mesmo com conexão instável em campo.

## Tecnologias utilizadas

**Back-end**
- [FastAPI](https://fastapi.tiangolo.com/) — API REST
- [Google Gemini](https://ai.google.dev/) (`google-genai`) — identificação de espécies e geração de conteúdo
- [Supabase](https://supabase.com/) — banco Postgres, Storage (fotos/PDFs) e extensão PostGIS (busca geoespacial)
- [Twilio](https://www.twilio.com/) — envio de mensagens/mídia via WhatsApp
- [ReportLab](https://www.reportlab.com/) — geração de PDF
- [geopy](https://geopy.readthedocs.io/) — geocodificação reversa
- [pandas](https://pandas.pydata.org/) / [pdfplumber](https://github.com/jsvine/pdfplumber) — pipeline de importação de dados de hospitais (CNES + PDFs do Ministério da Saúde)

**Front-end**
- [React 18](https://react.dev/) + [Vite](https://vitejs.dev/)
- [React Router](https://reactrouter.com/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Leaflet](https://leafletjs.com/) / react-leaflet — mapas
- [vite-plugin-pwa](https://vite-pwa-org.netlify.app/) — suporte a PWA

## Pré-requisitos

- [Python 3.11+](https://www.python.org/)
- [Node.js 18+](https://nodejs.org/) e npm
- Uma conta [Supabase](https://supabase.com/) (com a extensão **PostGIS** habilitada)
- Uma chave de API do [Google Gemini](https://ai.google.dev/)
- Uma conta [Twilio](https://www.twilio.com/) com WhatsApp habilitado (sandbox ou número aprovado)

## Instalação e configuração

### 1. Clonar o repositório

```bash
git clone https://github.com/sofiaoaraujo/soromais_prolog.git
cd soromais_prolog
```

### 2. Back-end

```bash
cd back-end
python -m venv venv

# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

pip install -r requirements.txt
```

Crie um arquivo `.env` dentro de `back-end/` com:

```env
SUPABASE_URL=https://xxxxxxx.supabase.co
SUPABASE_KEY=sua_service_role_key

GEMINI_API_KEY=sua_chave_gemini

TWILIO_ACCOUNT_SID=sua_account_sid
TWILIO_AUTH_TOKEN=seu_auth_token
TWILIO_WHATSAPP_NUMBER=+14155238886
```

No Supabase, crie:
- As tabelas `hospital`, `local` e `paciente`.
- Os buckets de Storage `fotos-animais` e `relatorios` (públicos).
- A função de busca geoespacial rodando o SQL em `back-end/scripts/sql/buscar_hospitais_proximos.sql` no SQL Editor.

Para popular a tabela de hospitais com dados reais (CNES + PDF de hospitais de referência):

```bash
python scripts/pipeline.py   # baixa/organiza os dados
python scripts/seed.py       # popula o Supabase
```

Suba a API:

```bash
uvicorn main:app --reload
```

A API sobe em `http://localhost:8000` (documentação interativa em `/docs`).

### 3. Front-end

```bash
cd front-end
npm install
```

Crie um arquivo `.env` dentro de `front-end/` com:

```env
VITE_API_URL=http://localhost:8000
```

Suba o front-end:

```bash
npm run dev
```

Acesse em `http://localhost:5173`.

## Como usar

1. Abra o app e permita o acesso à localização.
2. Na tela de identificação, tire/envie uma foto da serpente **ou** descreva o animal em texto.
3. Confira a espécie identificada, os efeitos do veneno e as orientações de primeiros socorros.
4. Veja o hospital de referência mais próximo, já com rota e telefone.
5. Preencha os dados da vítima e envie o relatório (PDF) direto para o hospital pelo botão de WhatsApp.

Exemplo de chamada direta à API (identificação por descrição):

```bash
curl -X POST http://localhost:8000/sugerir-especies \
  -F "descricao=Cobra escura com manchas amarelas, corpo grosso, cabeça triangular" \
  -F "lat=-7.1195" \
  -F "lng=-34.8450"
```

## Estrutura de pastas

```
soromais_prolog/
├── back-end/
│   ├── main.py                  # ponto de entrada da API (FastAPI)
│   ├── dependencies.py          # clientes compartilhados (Supabase, Gemini)
│   ├── routers/                 # rotas da API
│   │   ├── identificacao.py     # identificação por foto/nome
│   │   ├── sugerir_especies.py  # sugestão de espécies por descrição
│   │   ├── hospitais.py         # listagem e busca de hospitais próximos
│   │   ├── relatorio.py         # salvar relatório / geocodificação
│   │   └── whatsapp.py          # geração de PDF e envio via WhatsApp
│   ├── schemas/                 # modelos Pydantic
│   ├── services/                # integrações (localização, imagens, PDF)
│   └── scripts/
│       ├── pipeline.py          # orquestra a importação de dados de hospitais
│       ├── pipeline/            # etapas individuais do pipeline
│       ├── seed.py              # popula o Supabase com os hospitais
│       └── sql/                 # funções SQL (ex: busca geoespacial)
└── front-end/
    └── src/
        ├── pages/                # telas (Identificar, Relatório, Hospitais)
        ├── components/           # componentes reutilizáveis
        ├── context/              # contexto de geolocalização e hospitais
        └── hooks/                # hooks customizados
```

## Como contribuir

1. Faça um fork do repositório.
2. Crie uma branch a partir da `main`: `git checkout -b minha-feature`.
3. Faça suas alterações e commits (mensagens curtas e descritivas).
4. Abra um Pull Request explicando o que foi alterado e por quê.

## Licença

Este projeto ainda não possui uma licença definida. Até lá, todos os direitos são reservados aos autores.

## Contato / autores

Desenvolvido por [Pierre](https://github.com/pierrequeiroz2006) e [Sofia Araújo](https://github.com/sofiaoaraujo).

Repositório: [github.com/sofiaoaraujo/soromais_prolog](https://github.com/sofiaoaraujo/soromais_prolog)
