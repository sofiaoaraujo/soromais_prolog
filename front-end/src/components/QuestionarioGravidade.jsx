import { useMemo, useState } from 'react'
import { PERGUNTAS_UNIVERSAIS, PERGUNTAS_POR_TIPO, GENERO_PARA_TIPO } from '../data/perguntasTriagem'

export default function QuestionarioGravidade({ genero, onConcluir }) {
  const tipo = GENERO_PARA_TIPO[genero] ?? null

  const perguntasEspecificas = useMemo(
    () => (tipo ? PERGUNTAS_POR_TIPO[tipo].filter((p) => p.tipoInput !== 'automatica') : []),
    [tipo]
  )

  const [emBlocoEspecifico, setEmBlocoEspecifico] = useState(false)
  const [indice, setIndice] = useState(0)
  const [universal, setUniversal] = useState({})
  const [flags, setFlags] = useState([])
  const [sintomas, setSintomas] = useState([])
  const [concluido, setConcluido] = useState(false)

  const [valorNumero, setValorNumero] = useState('')
  const [selecaoMultipla, setSelecaoMultipla] = useState([])

  const perguntas = emBlocoEspecifico ? perguntasEspecificas : PERGUNTAS_UNIVERSAIS
  const pergunta = perguntas[indice]
  const totalPerguntas = perguntas.length

  const finalizar = (universalFinal, flagsFinal, sintomasFinal) => {
    const resultado = {
      tipo,
      sintomas: sintomasFinal,
      flags: flagsFinal,
      universal: universalFinal,
    }
    setConcluido(true)
    onConcluir?.(resultado)
  }

  const irParaProxima = (universalNovo, flagsNovo, sintomasNovo) => {
    setUniversal(universalNovo)
    setFlags(flagsNovo)
    setSintomas(sintomasNovo)
    setValorNumero('')
    setSelecaoMultipla([])

    const proximoIndice = indice + 1

    if (!emBlocoEspecifico) {
      if (proximoIndice < PERGUNTAS_UNIVERSAIS.length) {
        setIndice(proximoIndice)
        return
      }

      const temBlocoEspecifico = universalNovo.sintoma === 'sim' && perguntasEspecificas.length > 0
      if (temBlocoEspecifico) {
        const sintomasIniciais = tipo === 'elapidico'
          ? [...sintomasNovo, { chave: 'tipo', valor: 'elapidico' }]
          : sintomasNovo
        setSintomas(sintomasIniciais)
        setEmBlocoEspecifico(true)
        setIndice(0)
        return
      }

      finalizar(universalNovo, flagsNovo, sintomasNovo)
      return
    }

    if (proximoIndice < perguntasEspecificas.length) {
      setIndice(proximoIndice)
      return
    }
    finalizar(universalNovo, flagsNovo, sintomasNovo)
  }

  const responderUnica = (valor) => {
    const universalNovo = pergunta.destino === 'universal'
      ? { ...universal, [pergunta.chave]: valor }
      : universal
    const flagsNovo = pergunta.destino === 'flags' && valor !== null
      ? [...flags, { chave: pergunta.chave, valor }]
      : flags
    const sintomasNovo = pergunta.destino === 'sintomas' && valor !== null
      ? [...sintomas, { chave: pergunta.chave, valor }]
      : sintomas

    irParaProxima(universalNovo, flagsNovo, sintomasNovo)
  }

  const responderNumero = () => {
    const numero = Number(valorNumero)
    if (valorNumero === '' || Number.isNaN(numero)) return
    irParaProxima({ ...universal, [pergunta.chave]: numero }, flags, sintomas)
  }

  const alternarSelecaoMultipla = (valor) => {
    if (valor === null) {
      // "Nenhuma" é excludente com as demais opções
      setSelecaoMultipla((prev) => (prev.includes(null) ? [] : [null]))
      return
    }
    setSelecaoMultipla((prev) => {
      const semNenhuma = prev.filter((v) => v !== null)
      return semNenhuma.includes(valor)
        ? semNenhuma.filter((v) => v !== valor)
        : [...semNenhuma, valor]
    })
  }

  const confirmarMultipla = () => {
    const novosFlags = [
      ...flags,
      ...selecaoMultipla
        .filter((valor) => valor !== null)
        .map((valor) => ({ chave: pergunta.chave, valor })),
    ]
    irParaProxima(universal, novosFlags, sintomas)
  }

  if (!tipo) return null

  if (concluido) {
    return (
      <section className="border border-outline-variant bg-white p-md rounded-xl shadow-sm">
        <div className="flex items-center gap-xs mb-xs">
          <span className="material-symbols-outlined text-primary">task_alt</span>
          <h3 className="font-headline-sm text-headline-sm">Análise de Gravidade</h3>
        </div>
        <p className="font-body-md text-on-surface-variant">
          Questionário concluído. As respostas foram registradas.
        </p>
      </section>
    )
  }

  return (
    <section className="border border-outline-variant bg-white p-md rounded-xl shadow-sm">
      <div className="flex items-center justify-between mb-sm">
        <div className="flex items-center gap-xs">
          <span className="material-symbols-outlined text-primary">priority_high</span>
          <h3 className="font-headline-sm text-headline-sm">Análise de Gravidade</h3>
        </div>
        <span className="font-label-caps text-label-caps text-on-surface-variant">
          {indice + 1}/{totalPerguntas}
        </span>
      </div>

      <div>
        <label className="font-label-caps text-label-caps text-on-surface-variant uppercase mb-1 block">
          {pergunta.pergunta}
        </label>

        {pergunta.tipoInput === 'numero' && (
          <div className="flex gap-sm items-center">
            <input
              type="number"
              min="0"
              value={valorNumero}
              onChange={(e) => setValorNumero(e.target.value)}
              placeholder="Horas"
              className="flex-1 bg-surface-container-low border border-outline-variant rounded-lg px-md py-2 font-body-lg text-on-surface focus:border-primary focus:outline-none"
            />
            <button
              type="button"
              onClick={responderNumero}
              disabled={valorNumero === ''}
              className="bg-primary text-on-primary px-lg py-2 rounded-lg font-semibold active:scale-95 transition-transform disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Continuar
            </button>
          </div>
        )}

        {pergunta.tipoInput === 'unica' && (
          <div className="grid grid-cols-2 gap-sm">
            {pergunta.opcoes.map((opcao) => (
              <button
                key={opcao.label}
                type="button"
                onClick={() => responderUnica(opcao.valor)}
                className="border border-primary text-primary py-2 rounded-lg font-semibold text-[13px] active:scale-95 transition-transform hover:bg-primary/5"
              >
                {opcao.label}
              </button>
            ))}
          </div>
        )}

        {pergunta.tipoInput === 'multipla' && (
          <div className="space-y-sm">
            <div className="grid grid-cols-2 gap-sm">
              {pergunta.opcoes.map((opcao) => {
                const selecionado = selecaoMultipla.includes(opcao.valor)
                return (
                  <button
                    key={opcao.label}
                    type="button"
                    onClick={() => alternarSelecaoMultipla(opcao.valor)}
                    className={`py-2 rounded-lg font-semibold text-[13px] active:scale-95 transition-transform border ${
                      selecionado
                        ? 'bg-primary text-on-primary border-primary'
                        : 'border-primary text-primary hover:bg-primary/5'
                    }`}
                  >
                    {opcao.label}
                  </button>
                )
              })}
            </div>
            <button
              type="button"
              onClick={confirmarMultipla}
              className="w-full bg-primary text-on-primary py-2 rounded-lg font-semibold active:scale-95 transition-transform"
            >
              Continuar
            </button>
          </div>
        )}
      </div>
    </section>
  )
}
