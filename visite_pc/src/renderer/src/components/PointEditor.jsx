import React, { useEffect, useRef, useState } from 'react'
import { GRAVITES, LIBELLE_GRAVITE, estInclus, tempsTotal, formatHeures } from '../../../shared/rapport.js'
import LocaliserModal from './LocaliserModal.jsx'

// Temps saisi ('1,5', '2', '') -> nombre arrondi à la demi-heure, ou null.
export function parseTemps(texte) {
  const t = String(texte ?? '').trim().replace(',', '.')
  if (t === '') return null
  const n = Number(t)
  if (!Number.isFinite(n) || n < 0) return undefined // invalide : on n'enregistre pas
  return Math.round(n * 2) / 2
}

const afficheTemps = (h) => (h === null || h === undefined ? '' : String(h).replace('.', ','))

/** Case de temps (heures) enregistrée à la sortie du champ ou sur Entrée. */
function CaseTemps({ libelle, valeur, onSave }) {
  const [texte, setTexte] = useState(afficheTemps(valeur))
  function valider() {
    const h = parseTemps(texte)
    if (h === undefined) {
      setTexte(afficheTemps(valeur)) // saisie invalide : on revient à la valeur enregistrée
      return
    }
    setTexte(afficheTemps(h))
    if (h !== (valeur ?? null)) onSave(h)
  }
  return (
    <label className="case-temps">
      <span className="etiquette">{libelle}</span>
      <input className="temps" inputMode="decimal" value={texte} placeholder="—"
        onChange={(e) => setTexte(e.target.value)} onBlur={valider}
        onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur() }} />
      <span>h</span>
    </label>
  )
}

/**
 * Saisie d'un point : gravité, temps chaudronnerie / peinture, commentaire,
 * « Dans le rapport », et localisation (rond placé à la main sur un dessin).
 * Enregistrement automatique (commentaire : 500 ms après la frappe et à la
 * sortie du champ). `onLib` reçoit la bibliothèque à jour.
 * @param dessins dessins disponibles dans la visite : [{ dessin, plan }]
 * @param dessinAuto / zoneRect dessin et zone du point (rond automatique)
 */
export default function PointEditor({ visiteId, plan, zone, point, onLib, dessins = [], dessinAuto = null, zoneRect = null }) {
  const [localiser, setLocaliser] = useState(false)
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

  // Fenêtre fermée pendant la frappe (React ne démonte rien) : enregistrement
  // synchrone avant que l'appli se ferme.
  useEffect(() => {
    const avantFermeture = () => {
      if (enAttente.current === null) return
      clearTimeout(minuterie.current)
      window.api.setPointSync({ visiteId, plan, zone, commentaire: enAttente.current })
      enAttente.current = null
    }
    window.addEventListener('beforeunload', avantFermeture)
    return () => window.removeEventListener('beforeunload', avantFermeture)
  }, [visiteId, plan, zone])

  function changerCommentaire(e) {
    const texte = e.target.value
    setCommentaire(texte)
    enAttente.current = texte
    clearTimeout(minuterie.current)
    minuterie.current = setTimeout(() => enregistrerCommentaire(texte), 500)
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
        <CaseTemps libelle="Chaudronnerie" valeur={point?.tempsChaud ?? null}
          onSave={(h) => enregistrer({ tempsChaud: h })} />
        <CaseTemps libelle="Peinture" valeur={point?.tempsPeinture ?? null}
          onSave={(h) => enregistrer({ tempsPeinture: h })} />
        <span className="total-point">= {formatHeures(tempsTotal(point))}</span>
        <label className="inclure">
          <input type="checkbox" checked={inclus}
            onChange={(e) => enregistrer({ inclusion: e.target.checked ? 'oui' : 'non' })} />
          Dans le rapport
        </label>
      </div>
      <div className="ligne localisation">
        <button disabled={dessins.length === 0} onClick={() => setLocaliser(true)}
          title={dessins.length === 0 ? 'Disponible avec un export récent de la tablette (dessins inclus)' : ''}>
          📍 Localiser
        </button>
        <span className="etat-rond">
          {dessins.length === 0 ? 'Pas de dessin dans cet export'
            : point?.marque ? 'Rond placé à la main' : 'Rond automatique sur le point'}
        </span>
      </div>
      <textarea className="commentaire" rows={2} value={commentaire}
        placeholder="Constat et travaux à prévoir…"
        onChange={changerCommentaire}
        onBlur={(e) => enregistrerCommentaire(e.target.value)} />
      {localiser && (
        <LocaliserModal zone={zone} dessins={dessins} dessinAuto={dessinAuto} zoneRect={zoneRect}
          marque={point?.marque ?? null}
          onSave={(marque) => enregistrer({ marque })}
          onClose={() => setLocaliser(false)} />
      )}
    </div>
  )
}
