# SoroMais

Aplicativo web que identifica serpentes peçonhentas por foto, avalia a gravidade do acidente com um motor de inferência em Prolog e conecta a vítima ao hospital de referência com soro antiofídico mais próximo — em poucos toques, direto do celular.

![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.136-009688?logo=fastapi&logoColor=white)
![Prolog](https://img.shields.io/badge/SWI--Prolog-motor%20de%20infer%C3%AAncia-A11B47?logo=prolog&logoColor=white)
![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)
![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20PostGIS-3ECF8E?logo=supabase&logoColor=white)
![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)

## Sobre o projeto

Acidentes com serpentes peçonhentas exigem atendimento rápido e específico: perder tempo procurando qual hospital certo pode ser fatal. O SoroMais nasceu para reduzir esse tempo de resposta.

O usuário tira uma foto do animal, a IA identifica a espécie e o gênero, um questionário guiado de gravidade alimenta um motor de inferência em Prolog (baseado no Quadro de Classificação do Ministério da Saúde) que classifica o grau do acidente e a conduta recomendada, o app busca no mapa o hospital de referência mais próximo com base nos Dados Oficiais da PESA (Ponto Estratégico de Soro Antiveneno) — calculado via geolocalização/PostGIS — e monta um relatório do acidente enviado por WhatsApp direto para o hospital, com PDF anexado, antes mesmo da vítima chegar lá.

**Público-alvo**: vítimas de acidentes ofídicos, acompanhantes e socorristas em campo (zona rural/áreas remotas), principalmente na *Paraíba*, onde a base de hospitais de referência já está mapeada.

**Status**: em desenvolvimento (MVP funcional, com fluxo completo de identificação → triagem de gravidade → hospital → envio de relatório).

> ⚠️ **Nota**: por se tratar de um site de teste, o relatório **não é enviado para nenhum hospital real**. Ao popular a tabela `hospital` no Supabase, substitua o número de telefone do hospital mais próximo pelo seu próprio número (ver seção [Back-end](#3-back-end)), para que o envio via WhatsApp chegue até você durante os testes.

## Funcionalidades principais

- 📷 **Identificação por foto** — envia uma imagem da serpente e recebe espécie, gênero (Bothrops, Crotalus, Lachesis, Micrurus ou Leptomicrurus), habitat, efeitos do veneno, tempo de ação e primeiros socorros, via Gemini.
- 🧠 **Triagem de gravidade (motor Prolog)** — questionário guiado (tempo desde a picada, sintomas, local da picada, sinais de coagulação/sangramento etc.) processado por um motor de inferência em Prolog (SWI-Prolog) que classifica o grau do acidente (leve/moderado/grave/observação/picada seca), a conduta recomendada e gera uma cadeia de raciocínio auditável, explicando passo a passo por que chegou àquele resultado.
- 🏥 **Hospitais de referência mais próximos** — busca geoespacial (PostGIS) que retorna os 5 hospitais com soro antiofídico mais próximos da localização do usuário, com rota e telefone.
- 📍 **Geolocalização e endereço automático** — captura a posição do usuário e converte em endereço legível.
- 📄 **Relatório em PDF** — gera um relatório do acidente (foto, espécie, efeitos, resultado da triagem, dados da vítima, localização) pronto para enviar ao hospital.
- 💬 **Envio direto por WhatsApp** — dispara o relatório em PDF para o hospital escolhido via Twilio.
- 📱 **PWA (instalável)** — funciona como web app no celular, mesmo com conexão instável em campo.

## Tecnologias utilizadas

**Back-end**
- [FastAPI](https://fastapi.tiangolo.com/) — API REST
- [Google Gemini](https://ai.google.dev/) (`google-genai`) — identificação de espécies e geração de conteúdo
- [SWI-Prolog](https://www.swi-prolog.org/) — motor de inferência da triagem de gravidade (base de conhecimento do Quadro do Ministério da Saúde, pesos, explicação e geração de relatório), acionado via subprocesso a partir do back-end (`services/prolog_bridge.py`)
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
- [SWI-Prolog](https://www.swi-prolog.org/download/stable) instalado e com o executável `swipl` disponível no PATH (ou configurado via variável de ambiente `SWIPL_PATH`) — necessário para o motor de triagem
- Uma conta [Supabase](https://supabase.com/) (com as extensões **PostGIS** e `pgcrypto`/`gen_random_uuid` habilitadas)
- Uma chave de API do [Google Gemini](https://ai.google.dev/)
- Uma conta [Twilio](https://www.twilio.com/) com WhatsApp habilitado (sandbox ou número aprovado)

## Instalação e configuração

### 1. Clonar o repositório

```bash
git clone https://github.com/sofiaoaraujo/soromais_prolog.git
cd soromais_prolog
```

### 2. Banco de dados (Supabase)

Abra o **SQL Editor** do seu projeto Supabase e rode os blocos abaixo, na ordem.

**2.1. Tipos e tabelas de local / paciente**

```sql
create type public.tipo_local as enum (
  'urbano',
  'rural'
);

create table public.local (
  id uuid not null default gen_random_uuid (),
  lat double precision not null,
  long double precision not null,
  ponto_ref text null,
  urbano_rural public.tipo_local null,
  nome text null,
  constraint local_pkey primary key (id)
);

create type public.estado_paciente as enum (
  'leve',
  'moderado',
  'grave',
  'observacao',
  'picada_seca',
  'nao_identificado'
);

create table public.bixo (
  id uuid not null default gen_random_uuid (),
  nome text not null,
  tipo_acidente text null check (
    tipo_acidente in ('botropico','crotalico','laquetico','elapidico','outro')
  ),
  efeitos_do_veneno text null,
  foto text null,
  constraint bixo_pkey primary key (id)
);

create table public.paciente (
  id uuid not null default gen_random_uuid (),
  nome_do_paciente text not null,
  idade integer null,
  tempo_decorrido integer null,
  local_da_picada text null,
  estado_do_paciente text null,
  animal_pego uuid null,
  localizacao uuid null,
  created_at timestamp with time zone null default now(),
  constraint paciente_pkey primary key (id),
  constraint paciente_animal_pego_fkey foreign key (animal_pego) references bixo (id),
  constraint paciente_localizacao_fkey foreign key (localizacao) references local (id)
);
```

**2.2. Tabela de hospitais (com PostGIS)**

```sql
-- Habilita o PostGIS (necessário pro tipo geometry)
create extension if not exists postgis;

-- Função que mantém a coluna "location" (geometry) sincronizada com lat/lng
CREATE OR REPLACE FUNCTION public.atualizar_location()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.location = ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
  RETURN NEW;
END;
$function$;

create table public.hospital (
  id uuid not null default gen_random_uuid(),
  nome text not null,
  endereco text null,
  telefone text null,
  lat double precision null,
  lng double precision null,
  cnes text null,
  email text null,
  location geometry null,
  constraint hospital_pkey primary key (id),
  constraint hospital_cnes_key unique (cnes)
);

-- Dispara a função acima a cada insert/update, gerando "location" a partir de lat/lng
create trigger trigger_location
  before insert or update on hospital
  for each row
  execute function atualizar_location();
```

**2.3. Função de busca dos hospitais mais próximos**

Usada pela rota `GET /hospitais/proximos` (busca geoespacial via PostGIS/`geography`, ordenando pela distância real até o usuário):

```sql
create or replace function buscar_hospitais_proximos(user_lat double precision, user_lng double precision)
returns setof hospital
language sql
stable
as $$
  select *
  from hospital
  where lat is not null and lng is not null
  order by
    geography(ST_MakePoint(lng::double precision, lat::double precision))
      <-> geography(ST_MakePoint(user_lng, user_lat))
  limit 5;
$$;
```

**2.4. Storage (buckets)**

Em **Storage**, crie dois buckets públicos:

| Bucket | Público | Limite de tamanho | MIME types permitidos | Uso |
|---|---|---|---|---|
| `fotos-animais` | Sim | 4 MB | `image/jpeg`, `image/png` | Fotos enviadas para identificação da serpente |
| `relatorios` | Sim | 1 MB | Qualquer | PDFs do relatório de acidente enviados por WhatsApp |

**2.5. RLS (Row Level Security)**

RLS fica habilitado por padrão em todas as tabelas do projeto (`hospital`, `local`, `bixo`, `paciente`), sem nenhuma policy definida — ou seja, acesso é bloqueado por padrão para chaves anônimas/autenticadas. O back-end usa a **service role key** do Supabase (`SUPABASE_KEY` no `.env`), que ignora RLS, então nenhuma policy adicional é necessária para a API funcionar.

Para conferir o estado do RLS a qualquer momento:

```sql
-- Tabelas e se RLS está habilitado
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public';

-- Policies existentes (vazio = tudo bloqueado por padrão, exceto via service role key)
select * from pg_policies where schemaname = 'public';
```

Também dá pra conferir/alterar pelo painel: **Table Editor** → tabela → toggle "RLS" no topo (e botão **Policies** ao lado), ou em **Authentication → Policies**.

### 3. Back-end

```bash
cd back-end
python -m venv venv

# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

pip install -r requirements.txt
```

Confirme que o SWI-Prolog está instalado e acessível:

```bash
swipl --version
```

Crie um arquivo `.env` dentro de `back-end/` com:

```env
SUPABASE_URL=https://xxxxxxx.supabase.co
SUPABASE_KEY=sua_service_role_key

GEMINI_API_KEY=sua_chave_gemini

TWILIO_ACCOUNT_SID=sua_account_sid
TWILIO_AUTH_TOKEN=seu_auth_token
TWILIO_WHATSAPP_NUMBER=+14155238886

# Opcional: só se "swipl" não estiver no PATH
SWIPL_PATH=/caminho/para/swipl
```

Para popular a tabela de hospitais com dados reais (CNES + PDF de hospitais de referência):

```bash
python scripts/pipeline.py   # baixa/organiza os dados
python scripts/seed.py       # popula o Supabase
```

> ⚠️ Como este é um site de teste, o relatório não é de fato enviado para nenhum hospital. Após popular a tabela `hospital`, substitua na coluna `telefone` o número do hospital mais próximo (o que aparecerá para o seu teste) pelo seu próprio número, para receber o relatório via WhatsApp em vez do hospital real.

Suba a API:

```bash
# Windows: se "uvicorn.exe" for bloqueado por política de Controle de Aplicativo,
# use o módulo diretamente (invoca o python.exe, que já é confiável):
python -m uvicorn main:app --reload
```

A API sobe em `http://localhost:8000` (documentação interativa em `/docs`).

### 4. Front-end

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
2. Na tela de identificação, tire/envie uma foto da serpente.
3. Confira a espécie identificada, os efeitos do veneno e as orientações de primeiros socorros.
4. Responda o questionário de gravidade — o motor Prolog classifica o grau do acidente (leve/moderado/grave/observação/picada seca) e a conduta recomendada.
5. Veja o hospital de referência mais próximo, já com rota e telefone.
6. Preencha os dados da vítima e envie o relatório (PDF, já com o resultado da triagem) direto para o hospital pelo botão de WhatsApp.

Exemplo de chamada direta à API (avaliação de gravidade via motor Prolog):

```bash
curl -X POST http://localhost:8000/triagem \
  -H "Content-Type: application/json" \
  -d '{
    "tipo": "botropico",
    "sintomas": [{"chave": "local", "valor": "evidente"}],
    "flags": [{"chave": "local_picada", "valor": "braco"}],
    "universal": {"tempo_h": 1.0, "sintoma": "sim"}
  }'
```

## Estrutura de pastas

```
soromais_prolog/
├── back-end/
│   ├── main.py                     # ponto de entrada da API (FastAPI)
│   ├── dependencies.py             # clientes compartilhados (Supabase, Gemini)
│   ├── prolog/                     # motor de inferência da triagem (SWI-Prolog)
│   │   ├── main.pl                 # ponto de entrada — carrega motor.pl
│   │   ├── conhecimento_ms.pl      # base de fatos (Quadro de Classificação do MS)
│   │   ├── pesos.pl                # tabelas de pesos e faixas de gravidade
│   │   ├── motor.pl                # motor de avaliação + orquestração + alertas
│   │   ├── explicacao.pl           # cadeia de raciocínio (Módulo 2)
│   │   ├── relatorio.pl            # texto final do relatório de triagem
│   │   ├── bridge.pl               # ponte JSON (stdin/stdout) — avaliar/5
│   │   ├── bridge_explicacao.pl    # ponte JSON — explicar/5
│   │   ├── bridge_relatorio.pl     # ponte JSON — relatorio_json/5
│   │   └── casos_teste.pl          # casos de teste do motor
│   ├── routers/                    # rotas da API
│   │   ├── identificacao.py        # identificação da serpente por foto
│   │   ├── triagem.py              # avaliação/explicação/relatório de gravidade (Prolog)
│   │   ├── hospitais.py            # listagem e busca de hospitais próximos
│   │   ├── relatorio.py            # salvar relatório / geocodificação
│   │   └── whatsapp.py             # geração de PDF e envio via WhatsApp
│   ├── schemas/                    # modelos Pydantic
│   ├── services/                   # integrações (localização, ponte Prolog, PDF)
│   │   └── prolog_bridge.py        # sobe o swipl como subprocesso e troca JSON
│   └── scripts/
│       ├── pipeline.py              # orquestra a importação de dados de hospitais
│       ├── pipeline/                # etapas individuais do pipeline
│       └── seed.py                  # popula o Supabase com os hospitais
└── front-end/
    └── src/
        ├── pages/                # telas (Identificar, Relatório, Hospitais)
        ├── components/           # componentes reutilizáveis (inclui QuestionarioGravidade)
        ├── data/                 # perguntas do questionário de triagem
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

Desenvolvido por [Pierre Queiroz](https://github.com/pierrequeiroz2006), [Sofia Araújo](https://github.com/sofiaoaraujo) e [Luciana Nascimento](https://github.com/lucianahonorio).

Repositório: [github.com/sofiaoaraujo/soromais_prolog](https://github.com/sofiaoaraujo/soromais_prolog)
