import React, { useEffect, useRef, useState } from 'react'
import { GRAVITES, LIBELLE_GRAVITE, estInclus } from '../../../shared/rapport.js'

// Temps saisi ('1,5', '2', '') -> nombre arrondi à la demi-heure, ou null.
export function parseTemps(texte) {
  const t = String(texte ?? '').trim().replace(',', '.')
  if (t === '') return null
  const n = Number(t)
  if (!Number.isFinite(n) || n < 0) return undefined // invalide : on n'enregistre pas
  return Math.round(n * 2) / 2
}

const afficheTemps = (h) => (h === null || h === undefined ? '' : String(h).replace('.', ','))

/**
 * Saisie d'un point : gravité, temps estimé, commentaire, « Dans le rapport ».
 * Enregistrement automatique (commentaire : 500 ms après la frappe et à la
 * sortie du champ). `onLib` reçoit la bibliothèque à jour.
 */
export default function PointEditor({ visiteId, plan, zone, point, onLib }) {
  const [temps, setTemps] = useState(afficheTemps(point?.tempsH))
  const [commentaire, setCommentaire] = useState(point?.commentaire ?? '')
  const minuterie = useRef(null)
  const enAttente = useRef(null) // commentaire tapé, pas encore enregistré
  const dernierCommentaire = useRef(point?.commentaire ?? '')

  async function enregistrer(patch) {
    onLib(await window.api.setPoint({ visiteId, plan, zone, ...patch }))
  }

  function enregistrerCommentaire(texte) {
    clearTimeout(minuterie.current)
    enAttente.current = null
    if (texte === dernierCommentaire.current) return
    dernierCommentaire.current = texte
    enregistrer({ commentaire: texte })
  }

  // Écran quitté pendant la frappe : on enregistre ce qui a été tapé.
  useEffect(() => () => {
    if (enAttente.current !== null) enregistrerCommentaire(enAttente.current)
  }, [])

  function changerCommentaire(e) {
    const texte = e.target.value
    setCommentaire(texte)
    enAttente.current = texte
    clearTimeout(minuterie.current)
    minuterie.current = setTimeout(() => enregistrerCommentaire(texte), 500)
  }

  function validerTemps() {
    const h = parseTemps(temps)
    if (h === undefined) {
      setTemps(afficheTemps(point?.tempsH)) // saisie invalide : on revient à la valeur enregistrée
      return
    }
    setTemps(afficheTemps(h))
    if (h !== (point?.tempsH ?? null)) enregistrer({ tempsH: h })
  }

  const gravite = point?.gravite ?? null
  const inclus = estInclus(point)

  return (
    <div className={`point-editeur ${inclus ? 'inclus' : ''}`}>
      <div className="ligne">
        <span className="etiquette">Gravité</span>
        <div className="gravites">
          {GRAVITES.slice().reverse().map((g) => (
            <button key={g} type="button"
              className={`grav ${g} ${gravite === g ? 'actif' : ''}`}
              onClick={() => enregistrer({ gravite: gravite === g ? null : g })}>
              {LIBELLE_GRAVITE[g]}
            </button>
          ))}
        </div>
        <span className="etiquette">Temps</span>
        <input className="temps" inputMode="decimal" value={temps} placeholder="—"
          onChange={(e) => setTemps(e.target.value)} onBlur={validerTemps}
          onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur() }} />
        <span>h</span>
        <label className="inclure">
          <input type="checkbox" checked={inclus}
            onChange={(e) => enregistrer({ inclusion: e.target.checked ? 'oui' : 'non' })} />
          Dans le rapport
        </label>
      </div>
      <textarea className="commentaire" rows={2} value={commentaire}
        placeholder="Constat et travaux à prévoir…"
        onChange={changerCommentaire}
        onBlur={(e) => enregistrerCommentaire(e.target.value)} />
    </div>
  )
}
