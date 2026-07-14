import React from 'react'
import { rames } from '../model.js'

export default function RamesScreen({ lib, onOpen }) {
  const items = rames(lib)
  if (items.length === 0) {
    return <p className="vide">Aucune visite. Cliquez « Importer un export ».</p>
  }
  return (
    <div className="grille-rames">
      {items.map((r) => (
        <button key={r.rame} className="carte-rame" onClick={() => onOpen(r.rame)}>
          <div className="rame-num">Rame {r.rame}</div>
          <div className="rame-info">{r.nbVisites} visite(s)</div>
          <div className="rame-info">dernière : {r.derniereDate}</div>
        </button>
      ))}
    </div>
  )
}
