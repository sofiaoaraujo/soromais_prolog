import { useState, useRef, useEffect } from 'react'

const API_URL = import.meta.env.VITE_API_URL
import TopAppBar from '../components/TopAppBar'
import BottomNav from '../components/BottomNav'
import BottomSheet from '../components/BottomSheet'
import { useGeolocalizacao } from '../context/GeolocalizacaoContext'
import { useHospitais } from '../context/HospitaisContext'
import MapaHospital from '../components/MapaHospital'
import QuestionarioGravidade from '../components/QuestionarioGravidade'
import { LABELS_GRAU, LABELS_CONDUTA } from '../data/perguntasTriagem'

export default function Relatorio() {
  const [sheetOpen, setSheetOpen] = useState(false)
  const [form, setForm] = useState(() => {
    const salvo = sessionStorage.getItem('soromais_form')
    return salvo ? JSON.parse(salvo) : { nome: '' }
  })

  const { status, coords, requestLocation, canRetry } = useGeolocalizacao()
  const { hospitais } = useHospitais()
  const hospitalMaisProximo = hospitais[0] ?? null
  const [pontoReferencia, setPontoReferencia] = useState('');

  useEffect(() => {
    if (status === "granted" && coords) {
      fetch(`${API_URL}/relatorio/buscar-endereco?lat=${coords.latitude}&lng=${coords.longitude}`)
        .then(res => res.json())
        .then(dados => {
          if (dados.endereco) {
            setPontoReferencia(dados.endereco);
          }
        })
        .catch(err => console.error("Erro ao buscar endereço:", err));
    }
  }, [status, coords]);

  const fileInputRef = useRef(null);
  const [carregando, setCarregando] = useState(false)
  const [fotoArquivo, setFotoArquivo] = useState(null)
  
  const [mostrarDescricao, setMostrarDescricao] = useState(false)
  const [descricaoManual, setDescricaoManual] = useState('')
  const [sugestoes, setSugestoes] = useState(null)
  const [carregandoSugestoes, setCarregandoSugestoes] = useState(false)

  const [resultadoIa, setResultadoIa] = useState(() => {
    const salvo = sessionStorage.getItem('soromais_ia');
    return salvo ? JSON.parse(salvo) : null;
  });

  const [fotoPreview, setFotoPreview] = useState(() => {
    return sessionStorage.getItem('soromais_preview') || null;
  });

  const handleFileChange = async (e) => {
    const arquivo = e.target.files[0];
    if (!arquivo) return; 
    
    const urlImagem = URL.createObjectURL(arquivo);
    setFotoArquivo(arquivo);
    setFotoPreview(urlImagem);
    setCarregando(true);

    const formData = new FormData();
    formData.append('file', arquivo);
    if (coords) {
      formData.append('lat', coords.latitude);
      formData.append('lng', coords.longitude);
    }
    if (pontoReferencia) {
      formData.append('ponto_ref', pontoReferencia);
    }

    try {
      const resposta = await fetch(`${API_URL}/identificar-animal`, {
        method: 'POST',
        body: formData,
      });
      
      const dados = await resposta.json();
      const ia = dados.analise_ia;

      if (ia) {
        const novoResultado = {
          especie: ia.especie,
          lugar: ia.lugar,
          efeitos: ia.efeitos,
          tempo_de_acao: ia.tempo_de_acao,
          o_que_fazer: ia.o_que_fazer,
          genero: ia.genero,
          foto_url: dados.foto_url,
        };

        setResultadoIa(novoResultado);
        setSecoesAbertas(SECOES_PADRAO);
        sessionStorage.setItem('soromais_ia', JSON.stringify(novoResultado));
        sessionStorage.setItem('soromais_preview', urlImagem);
      }
      
    } catch (erro) {
      alert("Caiu no CATCH! Erro: " + erro.message);
    } finally {
      setCarregando(false);
    }
  };  
  
  const handleRemoveFile = () => {
    setFotoArquivo(null)
    setFotoPreview(null)
    setResultadoIa(null)
    setForm({ nome: '' })
    sessionStorage.removeItem('soromais_ia')
    sessionStorage.removeItem('soromais_preview')
    sessionStorage.removeItem('soromais_form')
    
    if (fileInputRef.current) {
      fileInputRef.current.value = ""
    }
  }

  const handleSugerirEspecies = async () => {
    if (!descricaoManual.trim()) return
    setCarregandoSugestoes(true)

    const formData = new FormData()
    formData.append('descricao', descricaoManual)
    if (coords) {
      formData.append('lat', coords.latitude)
      formData.append('lng', coords.longitude)
    }
    if (pontoReferencia) formData.append('ponto_ref', pontoReferencia)

    try {
      const resposta = await fetch(`${API_URL}/sugerir-especies`, {
        method: 'POST',
        body: formData,
      })
      const dados = await resposta.json()
      setSugestoes(dados.sugestoes)
      setMostrarDescricao(false)
    } catch (erro) {
      alert("Erro ao buscar sugestões: " + erro.message)
    } finally {
      setCarregandoSugestoes(false)
    }
  }

  const handleSelecionarEspecie = async (especie) => {
    setCarregandoSugestoes(true)
    setSugestoes(null)

    if (especie.imagem_url) {
      setFotoPreview(especie.imagem_url)
      sessionStorage.setItem('soromais_preview', especie.imagem_url)
    }

    const formData = new FormData()
    formData.append('nome_cientifico', especie.nome_cientifico)

    try {
      const resposta = await fetch(`${API_URL}/identificar-animal/por-nome`, {
        method: 'POST',
        body: formData,
      })
      const dados = await resposta.json()
      const ia = dados.analise_ia

      if (ia) {
        const novoResultado = {
          especie: ia.especie,
          lugar: ia.lugar,
          efeitos: ia.efeitos,
          tempo_de_acao: ia.tempo_de_acao,
          o_que_fazer: ia.o_que_fazer,
          genero: ia.genero,
        }
        setResultadoIa(novoResultado)
        setSecoesAbertas(SECOES_PADRAO)
        sessionStorage.setItem('soromais_ia', JSON.stringify(novoResultado))
      }
    } catch (erro) {
      alert("Erro ao identificar espécie: " + erro.message)
    } finally {
      setCarregandoSugestoes(false)
    }
  }

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value })
  }

  const SECOES_PADRAO = { dados: false, efeitos: true, oQueFazer: true }
  const [secoesAbertas, setSecoesAbertas] = useState(SECOES_PADRAO)
  const toggleSecao = (chave) => setSecoesAbertas(prev => ({ ...prev, [chave]: !prev[chave] }))

  const [triagemGravidade, setTriagemGravidade] = useState(null)
  const [resultadoTriagem, setResultadoTriagem] = useState(null)
  const [carregandoTriagem, setCarregandoTriagem] = useState(false)
  const [erroTriagem, setErroTriagem] = useState(null)

  const handleConcluirTriagem = async (payload) => {
    setTriagemGravidade(payload)
    setResultadoTriagem(null)
    setErroTriagem(null)
    setCarregandoTriagem(true)

    try {
      const resposta = await fetch(`${API_URL}/triagem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      const dados = await resposta.json()

      if (!resposta.ok) {
        setErroTriagem(dados.detail || 'Não foi possível avaliar a gravidade.')
      } else {
        setResultadoTriagem(dados)
      }
    } catch (erro) {
      setErroTriagem(erro.message)
    } finally {
      setCarregandoTriagem(false)
    }
  }

  const animal = resultadoIa

  const dadosRelatorio = {
    nome: form.nome || null,
    localizacao: pontoReferencia || (coords ? `${coords.latitude}, ${coords.longitude}` : null),
    especie: animal?.especie || null,
    lugar: animal?.lugar || null,
    efeitos: animal?.efeitos || null,
    tempo_de_acao: animal?.tempo_de_acao || null,
    foto_url: animal?.foto_url || null,
  }

  return (
    <>
      <TopAppBar />

      <main className="pt-14 px-container-margin space-y-lg max-w-[800px] mx-auto pb-36">

        {/* Foto / Identificação */}
        <section className="mt-lg">
          <div className="high-contrast-card rounded-xl overflow-hidden shadow-sm border border-outline-variant bg-white">
            <input 
              type="file"
              id="fileInput" 
              accept="image/*" 
              onChange={(evento) => handleFileChange(evento)} 
              className="hidden" 
            />

            {fotoPreview ? (
              <div className="relative h-64 w-full">
                <img src={fotoPreview} alt="Foto do animal" className="w-full h-full object-cover" />
                {!carregando && (
                <button
                  type="button"
                  onClick={handleRemoveFile}
                  className="absolute top-3 right-3 bg-surface-container-highest text-on-surface-variant hover:bg-error-container hover:text-on-error-container h-10 w-10 rounded-full flex items-center justify-center shadow-md transition-colors active:scale-95 duration-200 z-10"
                  title="Remover foto"
                >
                  <span className="material-symbols-outlined text-[22px]">close</span>
                </button>
              )}

                {carregando && (
                  <div className="absolute inset-0 bg-black/60 flex flex-col items-center justify-center text-white p-4">
                    <span className="material-symbols-outlined animate-spin text-4xl mb-2">sync</span>
                    <p className="font-semibold">Analisando a foto...</p>
                  </div>
                )}
              </div>
            ) : sugestoes ? (
              <div className="p-md">
                <div className="flex items-center gap-xs mb-md">
                  <span className="material-symbols-outlined text-primary">help</span>
                  <h3 className="font-headline-sm text-headline-sm">Qual se parece mais?</h3>
                </div>
                <div className="grid grid-cols-2 gap-sm">
                  {sugestoes.map((especie, i) => (
                    <button
                      key={i}
                      type="button"
                      onClick={() => handleSelecionarEspecie(especie)}
                      className="flex flex-col rounded-xl overflow-hidden border border-outline-variant bg-white active:scale-95 transition-transform shadow-sm text-left"
                    >
                      {especie.imagem_url ? (
                        <img src={especie.imagem_url} alt={especie.nome_popular} className="w-full h-32 object-cover" />
                      ) : (
                        <div className="w-full h-32 bg-surface-container flex items-center justify-center">
                          <span className="material-symbols-outlined text-on-surface-variant text-4xl">pest_control</span>
                        </div>
                      )}
                      <div className="p-xs">
                        <p className="font-label-lg text-on-surface font-semibold leading-tight">{especie.nome_popular}</p>
                        <p className="font-body-sm text-on-surface-variant italic leading-tight">{especie.nome_cientifico}</p>
                      </div>
                    </button>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={() => { setSugestoes(null); setMostrarDescricao(true) }}
                  className="mt-md w-full py-2 rounded-lg border border-outline-variant text-on-surface-variant font-semibold active:scale-95 transition-transform hover:bg-surface-container"
                >
                  Nenhuma delas — tentar novamente
                </button>
              </div>
            ) : (
              <div className="min-h-64 w-full bg-surface-container flex flex-col items-center justify-center gap-sm p-md">
                <span className="material-symbols-outlined text-primary text-5xl">photo_camera</span>
                <h2 className="font-headline-md text-headline-md text-on-surface text-center">
                  Tire ou Envie uma Foto
                </h2>
                <p className="font-body-md text-body-md text-on-surface-variant italic text-center">
                  Identificaremos a espécie automaticamente
                </p>
                
                <label 
                  htmlFor="fileInput" 
                  className="mt-2 border border-primary text-primary px-lg py-2 rounded-lg font-semibold active:scale-95 transition-transform hover:bg-primary/5 cursor-pointer inline-block text-center"
                >
                  Enviar foto
                </label>

                  <button
                    type="button"
                    onClick={() => setMostrarDescricao(prev => !prev)}
                    className="text-primary px-lg py-2 rounded-lg font-semibold active:scale-95 transition-transform hover:bg-primary/5 underline"
                  >
                    {mostrarDescricao ? 'Cancelar' : 'Descrever animal manualmente'}
                  </button>

                  {mostrarDescricao && (
                    <div className="w-full border-t border-outline-variant pt-md">
                      {carregandoSugestoes ? (
                        <div className="flex flex-col items-center justify-center gap-sm py-lg">
                          <span className="material-symbols-outlined animate-spin text-primary text-4xl">sync</span>
                          <p className="font-body-md text-on-surface-variant">Buscando...</p>
                        </div>
                      ) : (
                        <>
                          <label className="font-label-caps text-label-caps text-on-surface-variant uppercase mb-1 block">
                            Descreva o animal
                          </label>
                          <textarea
                            value={descricaoManual}
                            onChange={(e) => setDescricaoManual(e.target.value)}
                            placeholder="Ex: Cobra escura com manchas amarelas, corpo grosso, cabeça triangular..."
                            rows={4}
                            className="w-full bg-surface-container-low border border-outline-variant rounded-lg px-md py-2 font-body-lg text-on-surface focus:border-primary focus:outline-none resize-y"
                          />
                          <button
                            type="button"
                            onClick={handleSugerirEspecies}
                            disabled={!descricaoManual.trim()}
                            className="mt-sm w-full flex items-center justify-center gap-xs border border-primary text-primary py-2 rounded-lg font-semibold active:scale-95 transition-transform hover:bg-primary/5 disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            <span className="material-symbols-outlined text-[20px]">send</span>
                            Identificar pelo texto
                          </button>
                        </>
                      )}
                    </div>
                  )}
              </div>
            )}
          </div>
        </section>

        {carregandoSugestoes && fotoPreview && (
          <section className="bg-surface-container-low border border-outline-variant rounded-xl p-md shadow-sm flex flex-col items-center justify-center gap-sm py-lg">
            <span className="material-symbols-outlined animate-spin text-primary text-4xl">sync</span>
            <p className="font-body-md text-on-surface-variant">Buscando informações...</p>
          </section>
        )}

        {animal && (
          <section className="relative bg-surface-container-low border border-outline-variant rounded-xl p-md shadow-sm">
            <button
              type="button"
              onClick={() => toggleSecao('dados')}
              className="absolute top-2 right-2 w-8 h-8 flex items-center justify-center rounded-full text-on-surface-variant hover:bg-black/5 active:scale-95 transition-transform"
              aria-label={secoesAbertas.dados ? 'Minimizar' : 'Expandir'}
            >
              <span className={`text-lg font-bold inline-block transition-transform duration-200 ${secoesAbertas.dados ? '' : 'rotate-180'}`}>
                &lt;
              </span>
            </button>

            <div className="flex items-center gap-xs mb-xs pr-8">
              <span className="material-symbols-outlined text-primary">psychology</span>
              <h3 className="font-headline-sm text-headline-sm text-primary">{animal.especie}</h3>
            </div>

            {secoesAbertas.dados && (
              <>
                <ul className="space-y-1 mt-xs">
                  {animal.lugar.split('.').filter(Boolean).map((item, i) => (
                    <li key={i} className="font-body-md text-on-surface flex gap-2">
                      <span>•</span><span>{item.trim()}</span>
                    </li>
                  ))}
                </ul>

                <ul className="space-y-1 mt-xs">
                  {animal.tempo_de_acao.split('.').filter(Boolean).map((item, i) => (
                    <li key={i} className="font-body-md text-on-surface flex gap-2">
                      <span>•</span><span>{item.trim()}</span>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </section>
        )}

        {animal?.efeitos && (
          <section className="relative bg-error-container/40 border border-error/30 rounded-xl p-md">
            <button
              type="button"
              onClick={() => toggleSecao('efeitos')}
              className="absolute top-2 right-2 w-8 h-8 flex items-center justify-center rounded-full text-error hover:bg-black/5 active:scale-95 transition-transform"
              aria-label={secoesAbertas.efeitos ? 'Minimizar' : 'Expandir'}
            >
              <span className={`text-lg font-bold inline-block transition-transform duration-200 ${secoesAbertas.efeitos ? '' : 'rotate-180'}`}>
                &lt;
              </span>
            </button>

            <div className="flex items-center gap-xs mb-sm pr-8">
              <span className="material-symbols-outlined text-error">cancel</span>
              <h3 className="font-headline-sm text-headline-sm text-error">
                Efeitos do Veneno
              </h3>
            </div>
            {secoesAbertas.efeitos && (
              <ul className="space-y-1">
                {animal.efeitos.split('\n').filter(Boolean).map((e, i) => (
                  <li key={i} className="font-body-md text-on-error-container flex gap-2">
                    <span>•</span><span>{e.replace(/^-\s*/, '')}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}

        {animal?.o_que_fazer && (
          <section className="relative bg-secondary-container/40 border border-secondary/30 rounded-xl p-md">
            <button
              type="button"
              onClick={() => toggleSecao('oQueFazer')}
              className="absolute top-2 right-2 w-8 h-8 flex items-center justify-center rounded-full text-secondary hover:bg-black/5 active:scale-95 transition-transform"
              aria-label={secoesAbertas.oQueFazer ? 'Minimizar' : 'Expandir'}
            >
              <span className={`text-lg font-bold inline-block transition-transform duration-200 ${secoesAbertas.oQueFazer ? '' : 'rotate-180'}`}>
                &lt;
              </span>
            </button>

            <div className="flex items-center gap-xs mb-sm pr-8">
              <span className="material-symbols-outlined text-secondary">medical_services</span>
              <h3 className="font-headline-sm text-headline-sm text-secondary">
                O que fazer?
              </h3>
            </div>
            {secoesAbertas.oQueFazer && (
              <ul className="space-y-1">
                {animal.o_que_fazer.split('\n').filter(Boolean).map((item, i) => (
                  <li key={i} className="font-body-md text-on-secondary-container flex gap-2">
                    <span>•</span><span>{item.replace(/^-\s*/, '')}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}

        {animal?.genero && (
          <QuestionarioGravidade
            key={`${animal.genero}-${animal.especie}`}
            genero={animal.genero}
            onConcluir={handleConcluirTriagem}
          />
        )}

        {carregandoTriagem && (
          <section className="bg-surface-container-low border border-outline-variant rounded-xl p-md shadow-sm flex flex-col items-center justify-center gap-sm py-lg">
            <span className="material-symbols-outlined animate-spin text-primary text-4xl">sync</span>
            <p className="font-body-md text-on-surface-variant">Avaliando gravidade...</p>
          </section>
        )}

        {erroTriagem && (
          <section className="bg-error-container/40 border border-error/30 rounded-xl p-md">
            <div className="flex items-center gap-xs mb-xs">
              <span className="material-symbols-outlined text-error">error</span>
              <h3 className="font-headline-sm text-headline-sm text-error">Não foi possível avaliar</h3>
            </div>
            <p className="font-body-md text-on-error-container">{erroTriagem}</p>
          </section>
        )}

        {resultadoTriagem && (
          <section className={`border rounded-xl p-md shadow-sm ${
            resultadoTriagem.grau === 'grave'
              ? 'bg-error-container/40 border-error/30'
              : resultadoTriagem.grau === 'moderado'
                ? 'bg-secondary-container/40 border-secondary/30'
                : 'bg-surface-container-low border-outline-variant'
          }`}>
            <div className="flex items-center gap-xs mb-sm">
              <span className={`material-symbols-outlined ${
                resultadoTriagem.grau === 'grave' ? 'text-error' : resultadoTriagem.grau === 'moderado' ? 'text-secondary' : 'text-primary'
              }`}>emergency</span>
              <h3 className={`font-headline-sm text-headline-sm ${
                resultadoTriagem.grau === 'grave' ? 'text-error' : resultadoTriagem.grau === 'moderado' ? 'text-secondary' : 'text-on-surface'
              }`}>
                Resultado da Triagem — {LABELS_GRAU[resultadoTriagem.grau] || resultadoTriagem.grau}
              </h3>
            </div>
            <p className="font-body-lg font-semibold text-on-surface">
              {LABELS_CONDUTA[resultadoTriagem.conduta] || resultadoTriagem.conduta}
            </p>
            {resultadoTriagem.alertas.length > 0 && (
              <ul className="space-y-1 mt-sm">
                {resultadoTriagem.alertas.map((alerta, i) => (
                  <li key={i} className="font-body-md text-on-surface flex gap-2">
                    <span>⚠</span><span>{alerta}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}

        {/* Dados da Vítima */}
        <section className="border border-outline-variant bg-white p-md rounded-xl shadow-sm">
          <div className="flex items-center gap-xs mb-sm">
            <span className="material-symbols-outlined text-primary">person</span>
            <h3 className="font-headline-sm text-headline-sm">Identificação</h3>
          </div>
          <div className="space-y-sm">
            <div>
              <label className="font-label-caps text-label-caps text-on-surface-variant uppercase mb-1 block">
                NOME
              </label>
              <input
                name="nome"
                value={form.nome}
                onChange={handleChange}
                placeholder="Nome"
                className="w-full bg-surface-container-low border border-outline-variant rounded-lg px-2 py-2 font-body-lg text-on-surface focus:border-primary focus:outline-none"
              />
            </div>
            <button
              onClick={() => sessionStorage.setItem('soromais_form', JSON.stringify(form))}
              className="w-full flex items-center justify-center gap-xs bg-primary text-on-primary py-2 rounded-lg font-semibold mt-2 active:scale-95 transition-transform"
            >
              <span className="material-symbols-outlined text-[20px]">save</span>
              Salvar
            </button>
          </div>
        </section>

        {/* Localização */}
        <section className="border border-outline-variant bg-white p-md rounded-xl shadow-sm">
          <div className="flex items-center gap-xs mb-sm">
            <span className="material-symbols-outlined text-primary">location_on</span>
            <h3 className="font-headline-sm text-headline-sm">Localização</h3>
          </div>
          <div className="space-y-sm">
            <div className="h-48 w-full rounded-lg overflow-hidden border border-outline-variant mb-sm relative z-0">
              {hospitalMaisProximo
                ? <MapaHospital lat={hospitalMaisProximo.lat} lng={hospitalMaisProximo.lng} nome={hospitalMaisProximo.nome} />
                : <div className="w-full h-full bg-surface-container flex items-center justify-center">
                    <span className="material-symbols-outlined text-on-surface-variant text-4xl">map</span>
                  </div>
              }
            </div>

            {status === "denied" && (
              <div className="text-sm text-error font-medium space-y-1">
                <p>Permissão de localização negada.</p>
                {canRetry ? (
                  <>
                    <p className="text-on-surface-variant font-normal">
                      Toque em "Tentar novamente" para pedir a permissão de novo.
                    </p>
                    <button
                      type="button"
                      onClick={requestLocation}
                      className="mt-1 text-primary font-semibold underline"
                    >
                      Tentar novamente
                    </button>
                  </>
                ) : (
                  <p className="text-on-surface-variant font-normal">
                    O navegador não vai perguntar de novo automaticamente. Ative a permissão de localização para este site nas configurações do navegador — a página atualiza sozinha assim que você reativar.
                  </p>
                )}
              </div>
            )}

            {status === "error" && (
              <p className="text-sm text-error font-medium">
                GPS não suportado ou indisponível neste navegador.
              </p>
            )}

            {hospitalMaisProximo && (
              <div className="border-t border-outline-variant pt-sm mt-sm">
                <p className="font-label-caps text-label-caps text-on-surface-variant uppercase mb-1">Hospital Mais Próximo</p>
                <p className="font-body-lg font-bold text-on-surface">{hospitalMaisProximo.nome}</p>
                {hospitalMaisProximo.endereco && (
                  <p className="font-body-sm text-on-surface-variant mt-0.5">{hospitalMaisProximo.endereco}</p>
                )}
                <div className="flex gap-3 mt-sm">
                  <a
                    href={`https://maps.google.com/?q=${hospitalMaisProximo.lat},${hospitalMaisProximo.lng}`}
                    target="_blank"
                    rel="noreferrer"
                    className="flex-1 h-[44px] bg-primary text-white rounded-xl font-bold flex justify-center items-center gap-2 active:scale-95 transition-transform"
                  >
                    <span className="material-symbols-outlined text-[20px]">directions</span>
                    Rota
                  </a>
                  <a
                    href={`tel:${hospitalMaisProximo.telefone}`}
                    className="flex-1 h-[44px] border-2 border-primary text-primary rounded-xl font-bold flex justify-center items-center gap-2 active:scale-95 transition-transform"
                  >
                    <span className="material-symbols-outlined text-[20px]">call</span>
                    Ligar
                  </a>
                </div>
                <button
                  onClick={() => animal && setSheetOpen(true)}
                  disabled={!animal}
                  className={`w-full h-[36px] mt-2 flex items-center justify-center gap-2 rounded-xl font-bold text-sm active:scale-95 transition-transform
                    ${animal
                      ? 'bg-primary text-on-primary cursor-pointer'
                      : 'bg-outline-variant text-on-surface-variant cursor-not-allowed'
                    }`}
                >
                  <span className="material-symbols-outlined text-[16px]">share</span>
                  Compartilhar
                </button>
              </div>
            )}
          </div>
        </section>
      </main>
      <BottomSheet open={sheetOpen} onClose={() => setSheetOpen(false)} dadosRelatorio={dadosRelatorio} />
      <BottomNav />
    </>
  )
}