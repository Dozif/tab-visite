import React, { useEffect, useRef, useState } from 'react'

// Rayon du rond en fraction de la LARGEUR du dessin.
export const TAILLES = { petit: 0.015, moyen: 0.025, grand: 0.04 }

/**
 * Marque (rond visuellement circulaire) centrée en (cx, cy), coordonnées 0–1.
 * ry est exprimé en fraction de la HAUTEUR : on le corrige du ratio de l'image.
 */
export function marqueRonde(dessin, cx, cy, taille, largeur, hauteur) {
  const r = TAILLES[taille] ?? TAILLES.moyen
  const ratio = largeur > 0 && hauteur > 0 ? largeur / hauteur : 1
  const arrondi = (v) => Math.round(v * 10000) / 10000
  return { dessin, cx: arrondi(cx), cy: arrondi(cy), rx: arrondi(r), ry: arrondi(r * ratio) }
}

// Taille la plus proche d'une marque existante.
function tailleDe(marque) {
  if (!marque) return 'moyen'
  return Object.entries(TAILLES)
    .sort((a, b) => Math.abs(a[1] - marque.rx) - Math.abs(b[1] - marque.rx))[0][0]
}

/**
 * Fenêtre « Localiser » : le dessin de la voiture en grand ; un clic place le
 * rond rouge. Choix du dessin (autre voiture de la visite), taille du rond,
 * retour au rond automatique (sur la zone du point).
 */
export default function LocaliserModal({ zone, dessins, dessinAuto, zoneRect, marque, onSave, onClose }) {
  const [dessin, setDessin] = useState(marque?.dessin ?? dessinAuto ?? dessins[0]?.dessin)
  const [taille, setTaille] = useState(tailleDe(marque))
  const [url, setUrl] = useState(null)
  const img = useRef(null)

  useEffect(() => {
    let actif = true
    setUrl(null)
    window.api.photoUrl(dessin).then((u) => { if (actif) setUrl(u) })
    return () => { actif = false }
  }, [dessin])

  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const dims = () => [img.current?.naturalWidth ?? 1, img.current?.naturalHeight ?? 1]

  function placer(e) {
    const rect = e.currentTarget.getBoundingClientRect()
    const cx = (e.clientX - rect.left) / rect.width
    const cy = (e.clientY - rect.top) / rect.height
    onSave(marqueRonde(dessin, cx, cy, taille, ...dims()))
  }

  function changerTaille(t) {
    setTaille(t)
    if (marque && marque.dessin === dessin) {
      onSave(marqueRonde(dessin, marque.cx, marque.cy, t, ...dims()))
    }
  }

  // Rond affiché : la marque si elle est sur ce dessin, sinon le rond
  // automatique (pointillé) si on regarde le dessin du point.
  let rond = null
  let auto = false
  if (marque && marque.dessin === dessin) {
    rond = marque
  } else if (!marque && dessin === dessinAuto && zoneRect) {
    const { x, y, l, h } = zoneRect
    rond = { cx: x + l / 2, cy: y + h / 2, rx: l / 2 + 0.012, ry: h / 2 + 0.024 }
    auto = true
  }

  return (
    <div className="modal-fond" onClick={onClose}>
      <div className="modal localiser" onClick={(e) => e.stopPropagation()}>
        <div className="modal-tete">
          <b>Localiser {zone}</b>
          <select value={dessin} onChange={(e) => setDessin(e.target.value)}>
            {dessins.map((d) => <option key={d.dessin} value={d.dessin}>{d.plan}</option>)}
          </select>
          <button className="fermer" onClick={onClose}>✕</button>
        </div>
        <p className="aide">
          Cliquez sur le dessin à l'endroit de la photo pour y placer le rond rouge.
          {auto && ' (En pointillé : le rond automatique actuel.)'}
        </p>
        <div className="localiser-dessin">
          {url && (
            <span className="cadre" onClick={placer}>
              <img ref={img} src={url} alt={zone} draggable={false} />
              {rond && (
                <svg viewBox="0 0 1 1" preserveAspectRatio="none">
                  <ellipse cx={rond.cx} cy={rond.cy} rx={rond.rx} ry={rond.ry} fill="none"
                    stroke="#dc0000" strokeWidth="3" vectorEffect="non-scaling-stroke"
                    strokeDasharray={auto ? '6 4' : undefined} />
                </svg>
              )}
            </span>
          )}
        </div>
        <div className="modal-pied">
          <span className="etiquette">Taille du rond</span>
          {Object.keys(TAILLES).map((t) => (
            <button key={t} className={`taille ${taille === t ? 'actif' : ''}`}
              onClick={() => changerTaille(t)}>{t[0].toUpperCase() + t.slice(1)}</button>
          ))}
          <span className="espace" />
          <button disabled={!marque} onClick={() => onSave(null)}>Revenir à l'automatique</button>
          <button className="principal" onClick={onClose}>Terminé</button>
        </div>
      </div>
    </div>
  )
}
