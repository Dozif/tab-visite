import React, { useState } from 'react'
import { visitesForRame } from '../model.js'
import PhotosScreen from './PhotosScreen.jsx'

export default function RameScreen({ lib, rame, onBack }) {
  const [visiteId, setVisiteId] = useState(null)
  const visites = visitesForRame(lib, rame)

  if (visiteId) {
    return <PhotosScreen lib={lib} visiteId={visiteId} onBack={() => setVisiteId(null)} />
  }
  return (
    <div className="ecran">
      <button className="retour" onClick={onBack}>← Rames</button>
      <h2>Rame {rame}</h2>
      <ul className="liste-visites">
        {visites.map((v) => (
          <li key={v.id}>
            <button onClick={() => setVisiteId(v.id)}>
              {v.type} • {v.niveau} • {v.dateVisite} — {v.nbPhotos} photo(s)
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
