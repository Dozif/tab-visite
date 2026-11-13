import React, { useState } from 'react'
import { visitesForRame } from '../model.js'
import { resumeVisite, formatHeures } from '../../../shared/rapport.js'
import PhotosScreen from './PhotosScreen.jsx'
import RapportScreen from './RapportScreen.jsx'

export default function RameScreen({ lib, rame, onBack, onLib }) {
  const [visiteId, setVisiteId] = useState(null)
  const [rapport, setRapport] = useState(false)
  const visites = visitesForRame(lib, rame)

  if (visiteId) {
    return <PhotosScreen lib={lib} visiteId={visiteId} onBack={() => setVisiteId(null)} onLib={onLib} />
  }
  if (rapport) {
    return <RapportScreen lib={lib} rame={rame} onBack={() => setRapport(false)} onLib={onLib} />
  }
  return (
    <div className="ecran">
      <button className="retour" onClick={onBack}>← Rames</button>
      <div className="entete-rame">
        <h2>Rame {rame}</h2>
        <button className="principal" onClick={() => setRapport(true)}>Créer un rapport</button>
      </div>
      <ul className="liste-visites">
        {visites.map((v) => {
          const r = resumeVisite(lib, v.id)
          return (
            <li key={v.id}>
              <button onClick={() => setVisiteId(v.id)}>
                {v.type} • {v.niveau} • {v.dateVisite} — {v.nbPhotos} photo(s)
                {r.nbPoints > 0 && <span className="pastille">{r.nbPoints} point(s) · {formatHeures(r.heures)}</span>}
              </button>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
