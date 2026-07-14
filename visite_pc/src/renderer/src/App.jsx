import React, { useEffect, useState } from 'react'
import RamesScreen from './screens/RamesScreen.jsx'
import RameScreen from './screens/RameScreen.jsx'
import './styles.css'

export default function App() {
  const [lib, setLib] = useState({ version: 1, visites: [], photos: [] })
  const [rame, setRame] = useState(null)
  const [message, setMessage] = useState('')

  async function refresh() {
    setLib(await window.api.getLibrary())
  }
  useEffect(() => { refresh() }, [])

  async function importer() {
    const res = await window.api.importDialog()
    if (res) {
      setMessage(`Import : ${res.visites} visite(s), ${res.photos} photo(s).`)
      await refresh()
    }
  }

  return (
    <div className="app">
      <header className="topbar">
        <strong>Visites — PC</strong>
        <button onClick={importer}>Importer un export</button>
        {message && <span className="message">{message}</span>}
      </header>
      {rame === null
        ? <RamesScreen lib={lib} onOpen={setRame} />
        : <RameScreen lib={lib} rame={rame} onBack={() => setRame(null)} />}
    </div>
  )
}
