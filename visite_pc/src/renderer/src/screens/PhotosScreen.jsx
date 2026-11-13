import React, { useState, useEffect } from 'react'
import { photosForVisite } from '../model.js'
import { findPoint, resumeVisite, formatHeures } from '../../../shared/rapport.js'
import Lightbox from '../components/Lightbox.jsx'
import PointEditor from '../components/PointEditor.jsx'

export default function PhotosScreen({ lib, visiteId, onBack, onLib }) {
  const [filtre, setFiltre] = useState('tous') // 'tous' | 'traitee' | 'non'
  const [apercu, setApercu] = useState(null)

  const f = filtre === 'tous' ? {} : { traitee: filtre === 'traitee' }
  const groups = photosForVisite(lib, visiteId, f)
  const visite = lib.visites.find((v) => v.id === visiteId)
  const resume = resumeVisite(lib, visiteId)
  // Dessins disponibles dans la visite (pour placer le rond à la main).
  const dessins = []
  for (const ph of lib.photos) {
    if (ph.visiteId === visiteId && ph.dessin && !dessins.some((d) => d.dessin === ph.dessin)) {
      dessins.push({ dessin: ph.dessin, plan: ph.plan })
    }
  }

  return (
    <div className="ecran">
      <button className="retour" onClick={onBack}>← Visites</button>
      {visite && (
        <h2 className="titre-visite">
          Rame {visite.rame} — {visite.type} • {visite.niveau} • {visite.dateVisite}
        </h2>
      )}
      <div className="barre-visite">
        <div className="filtres">
          <label>Traitée :</label>
          <select value={filtre} onChange={(e) => setFiltre(e.target.value)}>
            <option value="tous">Toutes</option>
            <option value="traitee">Traitées</option>
            <option value="non">Non traitées</option>
          </select>
        </div>
        <div className="compteur">
          <b>{resume.nbPoints}</b> point{resume.nbPoints > 1 ? 's' : ''} dans le rapport
          — <b>{formatHeures(resume.heures)}</b>
        </div>
      </div>
      {groups.map((g) => (
        <section key={g.plan}>
          <h3>{g.plan}</h3>
          {g.zones.map((z) => (
            <div key={z.zone} className="zone-bloc">
              <div className="zone-nom">{z.zone}</div>
              <div className="grille-photos">
                {z.photos.map((p) => (
                  <Vignette key={p.id} photo={p} legende={lib.legendes?.[p.id] ?? ''}
                    onClick={() => setApercu(p)} onLib={onLib} />
                ))}
              </div>
              <PointEditor key={`${visiteId}|${g.plan}|${z.zone}`}
                visiteId={visiteId} plan={g.plan} zone={z.zone}
                point={findPoint(lib, visiteId, g.plan, z.zone)} onLib={onLib}
                dessins={dessins}
                dessinAuto={z.photos.find((ph) => ph.dessin)?.dessin ?? null}
                zoneRect={z.photos.find((ph) => ph.zoneRect)?.zoneRect ?? null} />
            </div>
          ))}
        </section>
      ))}
      {apercu && <Lightbox photo={apercu} onClose={() => setApercu(null)} />}
    </div>
  )
}

function Vignette({ photo, legende, onClick, onLib }) {
  const [url, setUrl] = useState(null)
  const [erreur, setErreur] = useState(false)
  const [texte, setTexte] = useState(legende)
  useEffect(() => {
    setErreur(false)
    window.api.photoUrl(photo.chemin).then(setUrl)
  }, [photo.chemin])

  async function enregistrer() {
    const t = texte.trim()
    if (t === legende) return
    onLib(await window.api.setLegende(photo.id, t))
  }

  return (
    <div className="vignette-bloc">
      <button className="vignette" onClick={onClick} title={photo.datePrise}>
        {url && !erreur && (
          <img src={url} alt={photo.zone} onError={() => setErreur(true)} />
        )}
        {erreur && <span className="img-manquante">Image manquante</span>}
      </button>
      <input className="legende-photo" value={texte} placeholder="Légende (facultatif)"
        onChange={(e) => setTexte(e.target.value)} onBlur={enregistrer}
        onKeyDown={(e) => { if (e.key === 'Enter') e.currentTarget.blur() }} />
    </div>
  )
}
