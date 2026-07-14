import React, { useState, useEffect } from 'react'
import { photosForVisite } from '../model.js'
import Lightbox from '../components/Lightbox.jsx'

export default function PhotosScreen({ lib, visiteId, onBack }) {
  const [filtre, setFiltre] = useState('tous') // 'tous' | 'traitee' | 'non'
  const [apercu, setApercu] = useState(null)

  const f = filtre === 'tous' ? {} : { traitee: filtre === 'traitee' }
  const groups = photosForVisite(lib, visiteId, f)

  return (
    <div className="ecran">
      <button className="retour" onClick={onBack}>← Visites</button>
      <div className="filtres">
        <label>Traitée :</label>
        <select value={filtre} onChange={(e) => setFiltre(e.target.value)}>
          <option value="tous">Toutes</option>
          <option value="traitee">Traitées</option>
          <option value="non">Non traitées</option>
        </select>
      </div>
      {groups.map((g) => (
        <section key={g.plan}>
          <h3>{g.plan}</h3>
          {g.zones.map((z) => (
            <div key={z.zone} className="zone-bloc">
              <div className="zone-nom">{z.zone}</div>
              <div className="grille-photos">
                {z.photos.map((p) => (
                  <Vignette key={p.id} photo={p} onClick={() => setApercu(p)} />
                ))}
              </div>
            </div>
          ))}
        </section>
      ))}
      {apercu && <Lightbox photo={apercu} onClose={() => setApercu(null)} />}
    </div>
  )
}

function Vignette({ photo, onClick }) {
  const [url, setUrl] = useState(null)
  const [erreur, setErreur] = useState(false)
  useEffect(() => {
    setErreur(false)
    window.api.photoUrl(photo.chemin).then(setUrl)
  }, [photo.chemin])
  return (
    <button className="vignette" onClick={onClick} title={photo.datePrise}>
      {url && !erreur && (
        <img src={url} alt={photo.zone} onError={() => setErreur(true)} />
      )}
      {erreur && <span className="img-manquante">Image manquante</span>}
    </button>
  )
}
