import React, { useEffect, useState } from 'react'

export default function Lightbox({ photo, onClose }) {
  const [url, setUrl] = useState(null)
  const [erreur, setErreur] = useState(false)
  useEffect(() => {
    setErreur(false)
    window.api.photoUrl(photo.chemin).then(setUrl)
  }, [photo.chemin])
  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="lightbox" onClick={onClose}>
      {url && !erreur && (
        <img src={url} alt={photo.zone}
          onClick={(e) => e.stopPropagation()}
          onError={() => setErreur(true)} />
      )}
      {erreur && (
        <div className="img-manquante" onClick={(e) => e.stopPropagation()}>
          Image manquante
        </div>
      )}
      <div className="lightbox-info">{photo.zone} — {photo.datePrise}</div>
    </div>
  )
}
