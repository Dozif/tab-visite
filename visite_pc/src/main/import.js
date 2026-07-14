import * as XLSX from 'xlsx'
import AdmZip from 'adm-zip'
import { mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { loadLibrary, saveLibrary, photosDir } from './library.js'

export function parseDataXlsx(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' })
  const ws = wb.Sheets['Photos'] ?? wb.Sheets[wb.SheetNames[0]]
  const raw = XLSX.utils.sheet_to_json(ws, { defval: '' })
  return raw.map((r) => ({
    rame: Number(r['Rame']),
    type: String(r['Type']),
    niveau: String(r['Niveau']),
    dateVisite: String(r['Date visite']),
    plan: String(r['Plan']),
    zone: String(r['Zone']),
    datePrise: String(r['Date prise']),
    traitee: String(r['Traitée']).toLowerCase() === 'oui',
    cheminPhoto: String(r['Chemin photo']),
    visiteId: String(r['Visite ID']),
    photoId: String(r['Photo ID'])
  }))
}

export function upsertLibrary(lib, rows) {
  const touchedVisites = new Set(rows.map((r) => r.visiteId))

  // On repart des visites/photos NON concernées par cet import.
  const visites = lib.visites.filter((v) => !touchedVisites.has(v.id))
  const photos = lib.photos.filter((p) => !touchedVisites.has(p.visiteId))

  const importeLe = new Date().toISOString()
  const seenVisite = new Set()
  for (const r of rows) {
    if (!seenVisite.has(r.visiteId)) {
      seenVisite.add(r.visiteId)
      visites.push({
        id: r.visiteId, rame: r.rame, type: r.type,
        niveau: r.niveau, dateVisite: r.dateVisite, importeLe
      })
    }
    photos.push({
      id: r.photoId, visiteId: r.visiteId, plan: r.plan, zone: r.zone,
      datePrise: r.datePrise, traitee: r.traitee,
      chemin: `photos/${r.visiteId}/${r.photoId}.jpg`
    })
  }

  return {
    lib: { version: 1, visites, photos },
    resume: { visites: seenVisite.size, photos: rows.length }
  }
}

export function importZip(zipPath, libraryDir) {
  const zip = new AdmZip(zipPath)
  const dataEntry = zip.getEntry('data.xlsx')
  if (!dataEntry) throw new Error('data.xlsx introuvable dans le ZIP')
  const rows = parseDataXlsx(dataEntry.getData())

  // Supprimer les dossiers photos des visites ré-importées (remplacement).
  for (const visiteId of new Set(rows.map((r) => r.visiteId))) {
    rmSync(join(photosDir(libraryDir), visiteId), { recursive: true, force: true })
  }

  // Copier chaque photo présente dans le ZIP vers photos/<visiteId>/<photoId>.jpg.
  for (const r of rows) {
    const entry = zip.getEntry(r.cheminPhoto)
    if (!entry) continue // photo absente du ZIP : ignorée
    const dest = join(photosDir(libraryDir), r.visiteId, `${r.photoId}.jpg`)
    mkdirSync(join(photosDir(libraryDir), r.visiteId), { recursive: true })
    writeFileSync(dest, entry.getData())
  }

  const { lib, resume } = upsertLibrary(loadLibrary(libraryDir), rows)
  saveLibrary(libraryDir, lib)
  return resume
}
