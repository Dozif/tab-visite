import React, { useState } from 'react'
import { resumeVisite, visitesParDefaut, formatHeures, PERIMETRE } from '../../../shared/rapport.js'

// 'dd/MM/yyyy' -> nombre triable.
const cle = (d) => {
  const [j, m, a] = String(d).split('/').map(Number)
  return (a || 0) * 10000 + (m || 0) * 100 + (j || 0)
}

/**
 * Génération du rapport d'une rame : choix des visites (par défaut celles de
 * la date la plus récente), rédacteur, aperçu, enregistrement du PDF.
 */
export default function RapportScreen({ lib, rame, onBack, onLib }) {
  const visites = lib.visites
    .filter((v) => v.rame === rame)
    .sort((a, b) => cle(b.dateVisite) - cle(a.dateVisite) || a.type.localeCompare(b.type))
  const [cochees, setCochees] = useState(() => new Set(visitesParDefaut(lib, rame)))
  const [redacteur, setRedacteur] = useState(lib.reglages?.redacteur ?? '')
  const [message, setMessage] = useState('')
  const [occupe, setOccupe] = useState(false)

  const lignes = visites.map((v) => ({ v, ...resumeVisite(lib, v.id) }))
  const choisies = lignes.filter((l) => cochees.has(l.v.id))
  const total = {
    nbPoints: choisies.reduce((s, l) => s + l.nbPoints, 0),
    heures: choisies.reduce((s, l) => s + l.heures, 0)
  }
  const dates = new Set(choisies.map((l) => l.v.dateVisite))
  const possible = total.nbPoints > 0 && !occupe

  function basculer(id) {
    const s = new Set(cochees)
    if (s.has(id)) s.delete(id)
    else s.add(id)
    setCochees(s)
  }

  const opts = () => ({ rame, visiteIds: [...cochees], redacteur: redacteur.trim() })

  async function lancer(action) {
    setOccupe(true)
    setMessage('')
    try {
      if (action === 'apercu') {
        await window.api.rapportApercu(opts())
      } else {
        const res = await window.api.rapportPdf(opts())
        if (res) {
          setMessage(`Rapport ${res.numero} enregistré : ${res.chemin}`)
          onLib(await window.api.getLibrary())
        }
      }
    } catch (e) {
      setMessage(`Échec : ${String(e?.message ?? e).replace(/^Error invoking remote method '[^']+': (Error: )?/, '')}`)
    } finally {
      setOccupe(false)
    }
  }

  return (
    <div className="ecran rapport">
      <button className="retour" onClick={onBack}>← Rame {rame}</button>
      <h2>Rapport — Rame {rame}</h2>
      <p className="aide">
        Cochez les visites à inclure. Par défaut : les visites de la date la plus récente.
        Pour un rapport séparé, ne cochez qu'une visite.
      </p>
      <table className="table-visites">
        <thead>
          <tr><th></th><th>Type</th><th>Périmètre</th><th>Niveau</th><th>Date</th>
            <th className="num">Points</th><th className="num">Temps</th></tr>
        </thead>
        <tbody>
          {lignes.map(({ v, nbPoints, heures }) => (
            <tr key={v.id} onClick={() => basculer(v.id)} className={cochees.has(v.id) ? 'coche' : ''}>
              <td><input type="checkbox" checked={cochees.has(v.id)} onChange={() => basculer(v.id)}
                onClick={(e) => e.stopPropagation()} /></td>
              <td><b>{v.type}</b></td><td>{PERIMETRE[v.type] ?? v.type}</td><td>{v.niveau}</td>
              <td>{v.dateVisite}</td><td className="num">{nbPoints}</td>
              <td className="num">{formatHeures(heures)}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr><td colSpan={5}>Total</td><td className="num">{total.nbPoints}</td>
            <td className="num">{formatHeures(total.heures)}</td></tr>
        </tfoot>
      </table>
      {dates.size > 1 && (
        <p className="avertissement">Attention : les visites cochées ont des dates différentes.</p>
      )}
      <div className="champ">
        <label htmlFor="redacteur">Rédigé par</label>
        <input id="redacteur" value={redacteur} onChange={(e) => setRedacteur(e.target.value)}
          placeholder="Votre nom" />
      </div>
      <div className="actions">
        <button disabled={!possible} onClick={() => lancer('apercu')}>Aperçu</button>
        <button className="principal" disabled={!possible} onClick={() => lancer('pdf')}>
          Enregistrer le PDF…
        </button>
      </div>
      {total.nbPoints === 0 && (
        <p className="aide">
          Aucun point à inclure : renseignez la gravité et le temps des points dans
          chaque visite (ou cochez « Dans le rapport »).
        </p>
      )}
      {message && <p className="message-rapport">{message}</p>}
    </div>
  )
}
