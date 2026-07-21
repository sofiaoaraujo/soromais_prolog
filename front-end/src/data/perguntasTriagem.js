// Base de perguntas do questionário de gravidade (bloco universal + blocos específicos por tipo
// de acidente ofídico). Fonte de verdade: planilha perguntas_soromais.csv.
//
// Cada opção tem { label, valor } — "label" é o texto mostrado ao usuário, "valor" é o átomo
// Prolog correspondente. valor === null significa "não gera átomo" (a resposta é omitida da
// lista enviada ao motor), usado para respostas de ausência ("Não", "Normal", "Não sei", etc.).

// Labels legíveis pros átomos que voltam de POST /triagem (grau/conduta do motor Prolog).
export const LABELS_GRAU = {
  picada_seca: 'Picada seca',
  observar: 'Em observação',
  leve: 'Leve',
  moderado: 'Moderado',
  grave: 'Grave',
}

export const LABELS_CONDUTA = {
  alta_orientacoes: 'Alta com orientações',
  observar_6h_unidade: 'Observação de 6h na unidade de saúde',
  hospital_encaminhamento: 'Encaminhar ao hospital',
  transporte_imediato: 'Transporte imediato ao hospital',
  transporte_prioridade_maxima: 'Transporte com prioridade máxima',
}

export const GENERO_PARA_TIPO = {
  Bothrops: 'botropico',
  Lachesis: 'laquetico',
  Crotalus: 'crotalico',
  Micrurus: 'elapidico',
  Leptomicrurus: 'elapidico',
}

export const PERGUNTAS_UNIVERSAIS = [
  {
    id: 'U1',
    destino: 'universal',
    chave: 'tempo_h',
    pergunta: 'Quanto tempo desde a picada? (em horas)',
    tipoInput: 'numero',
  },
  {
    id: 'U2',
    destino: 'universal',
    chave: 'sintoma',
    pergunta: 'Sente algum sintoma agora?',
    tipoInput: 'unica',
    opcoes: [
      { label: 'Não', valor: 'nao' },
      { label: 'Sim', valor: 'sim' },
    ],
  },
  {
    id: 'U3',
    destino: 'flags',
    chave: 'local_picada',
    pergunta: 'Onde foi a picada?',
    tipoInput: 'unica',
    opcoes: [
      { label: 'Dedo', valor: 'dedo' },
      { label: 'Mão', valor: 'mao' },
      { label: 'Pé', valor: 'pe' },
      { label: 'Perna', valor: 'perna' },
      { label: 'Braço', valor: 'braco' },
      { label: 'Tronco', valor: 'tronco' },
      { label: 'Cabeça/Pescoço', valor: 'cabeca_pescoco' },
      { label: 'Não sei', valor: null },
    ],
  },
  {
    id: 'U4',
    destino: 'flags',
    chave: 'interferencia',
    pergunta: 'Foi feito garrote, corte, sucção ou aplicada alguma substância no local?',
    tipoInput: 'unica',
    opcoes: [
      { label: 'Nenhum', valor: null },
      { label: 'Garrote', valor: 'garrote' },
      { label: 'Corte', valor: 'corte' },
      { label: 'Sucção', valor: 'sucao' },
      { label: 'Substância', valor: 'substancia' },
    ],
  },
  {
    id: 'U5',
    destino: 'flags',
    chave: 'contexto_risco',
    pergunta: 'Há alguma condição especial? (marque todas que se aplicam)',
    tipoInput: 'multipla',
    opcoes: [
      { label: 'Nenhuma', valor: null },
      { label: 'Gestação', valor: 'gestacao' },
      { label: 'Anticoagulante', valor: 'anticoagulante' },
      { label: 'Criança (menor de 12)', valor: 'crianca' },
      { label: 'Idoso (maior de 60)', valor: 'idoso' },
    ],
  },
]

export const PERGUNTAS_POR_TIPO = {
  botropico: [
    {
      id: 'B1', destino: 'sintomas', chave: 'local', tipoInput: 'unica',
      pergunta: 'Como está o local da picada (dor, inchaço, mancha roxa)?',
      opcoes: [
        { label: 'Sem alteração', valor: null },
        { label: 'Discreto', valor: 'discreto' },
        { label: 'Evidente', valor: 'evidente' },
        { label: 'Intenso', valor: 'intenso' },
      ],
    },
    {
      id: 'B2', destino: 'sintomas', chave: 'sangramento', tipoInput: 'unica',
      pergunta: 'Está sangrando (gengiva, nariz, pele, urina, vômito)?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Pouco', valor: 'discreto' },
        { label: 'Sim, sem passar mal', valor: 'moderado' },
        { label: 'Hemorragia forte', valor: 'intenso' },
      ],
    },
    {
      id: 'B3', destino: 'sintomas', chave: 'choque', tipoInput: 'unica',
      pergunta: 'Sente tontura, desmaio, suor frio ou palidez?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'sim' },
      ],
    },
    {
      id: 'B4', destino: 'sintomas', chave: 'diurese', tipoInput: 'unica',
      pergunta: 'Parou ou reduziu muito a urina?',
      opcoes: [
        { label: 'Normal', valor: null },
        { label: 'Reduziu', valor: 'oliguria' },
        { label: 'Parou', valor: 'anuria' },
      ],
    },
    {
      id: 'B5', destino: 'sintomas', chave: 'coagulacao_proxy', tipoInput: 'unica',
      pergunta: 'O sangue no local da picada continua saindo depois de bastante tempo, sem coagular?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'alterada' },
        { label: 'Não sei', valor: null },
      ],
    },
    {
      id: 'B6', destino: 'sintomas', chave: 'local_complicacao', tipoInput: 'unica',
      pergunta: 'Apareceram bolhas na pele ao redor da picada, ou alguma parte está ficando preta / muito escura?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Bolhas', valor: 'bolhas' },
        { label: 'Escurecimento', valor: 'necrose' },
        { label: 'Ambos', valor: 'ambas' },
      ],
    },
  ],
  laquetico: [
    {
      id: 'L1', destino: 'sintomas', chave: 'local', tipoInput: 'unica',
      pergunta: 'Como está o local da picada?',
      opcoes: [
        { label: 'Sem alteração', valor: null },
        { label: 'Presente', valor: 'evidente' },
        { label: 'Intenso', valor: 'intenso' },
      ],
    },
    {
      id: 'L2', destino: 'sintomas', chave: 'sangramento', tipoInput: 'unica',
      pergunta: 'Está sangrando?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Pouco', valor: null },
        { label: 'Hemorragia forte', valor: 'intenso' },
      ],
    },
    {
      id: 'L3', destino: 'sintomas', chave: 'vagais', tipoInput: 'unica',
      pergunta: 'Náusea, vômito, cólica ou diarreia?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'sim' },
      ],
    },
    {
      id: 'L4', destino: 'sintomas', chave: 'coagulacao_proxy', tipoInput: 'unica',
      pergunta: 'O sangue no local da picada continua saindo sem coagular?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'alterada' },
        { label: 'Não sei', valor: null },
      ],
    },
    {
      id: 'L5', destino: 'sintomas', chave: 'local_complicacao', tipoInput: 'unica',
      pergunta: 'Apareceram bolhas na pele ou área escurecida ao redor da picada?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Bolhas', valor: 'bolhas' },
        { label: 'Escurecimento', valor: 'necrose' },
        { label: 'Ambos', valor: 'ambas' },
      ],
    },
  ],
  crotalico: [
    {
      id: 'C1', destino: 'sintomas', chave: 'neuro', tipoInput: 'unica',
      pergunta: 'Pálpebra caída, visão embaçada/dupla, rosto "molenga"?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Leve', valor: 'discreto' },
        { label: 'Forte', valor: 'evidente' },
      ],
    },
    {
      id: 'C2', destino: 'sintomas', chave: 'mialgia', tipoInput: 'unica',
      pergunta: 'Dor muscular espalhada pelo corpo?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Leve', valor: 'discreta' },
        { label: 'Forte', valor: 'intensa' },
      ],
    },
    {
      id: 'C3', destino: 'sintomas', chave: 'urina_escura', tipoInput: 'unica',
      pergunta: 'Urina escura (cor de Coca-Cola ou chá)?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Meio escura', valor: 'discreta' },
        { label: 'Bem escura', valor: 'intensa' },
      ],
    },
    {
      id: 'C4', destino: 'sintomas', chave: 'diurese', tipoInput: 'unica',
      pergunta: 'Reduziu muito o volume de urina?',
      opcoes: [
        { label: 'Normal', valor: null },
        { label: 'Reduziu', valor: 'oliguria' },
      ],
    },
    {
      id: 'C5', destino: 'sintomas', chave: 'progressao_craniocaudal', tipoInput: 'unica',
      pergunta: 'Está babando muito, com dificuldade de engolir ou voz enfraquecida?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'sim' },
      ],
    },
    {
      id: 'C6', destino: 'sintomas', chave: 'respiratorio', tipoInput: 'unica',
      pergunta: 'Sente falta de ar ou dificuldade para respirar?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'sim' },
      ],
    },
  ],
  elapidico: [
    {
      // Sem pergunta ao usuário — o átomo tipo(elapidico) é sempre incluído automaticamente.
      id: 'E0', destino: 'sintomas', chave: 'tipo', tipoInput: 'automatica', valorFixo: 'elapidico',
    },
    {
      id: 'E1', destino: 'sintomas', chave: 'respiratorio', tipoInput: 'unica',
      pergunta: 'Dificuldade de respirar, engolir ou pálpebra caindo?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'sim' },
      ],
    },
    {
      id: 'E2', destino: 'sintomas', chave: 'progressao_craniocaudal', tipoInput: 'unica',
      pergunta: 'Está babando, voz enfraquecida ou rosto "caindo" progressivamente?',
      opcoes: [
        { label: 'Não', valor: null },
        { label: 'Sim', valor: 'sim' },
      ],
    },
  ],
}
