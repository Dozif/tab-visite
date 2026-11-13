import * as XLSX from 'xlsx'
import AdmZip from 'adm-zip'
import { mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { join, basename } from 'node:path'
import { loadLibrary, saveLibrary, photosDir, dessinsDir, migrateLibrary } from './library.js'

// Nombre décimal écrit par la tablette ('0.25') ; tolère la virgule.
function nombre(v) {
  if (v === '' || v === null || v === undefined) return NaN
  return Number(String(v).replace(',', '.'))
}

// Rectangle du point sur son dessin (coordonnées 0–1), ou null si l'export
// est ancien (colonnes absentes) ou incomplet.
function zoneRect(r) {
  const x = nombre(r['Zone X'])
  const y = nombre(r['Zone Y'])
  const l = nombre(r['Zone largeur'])
  const h = nombre(r['Zone hauteur'])
  return [x, y, l, h].every(Number.isFinite) ? { x, y, l, h } : null
}

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
    photoId: String(r['Photo ID']),
    fichierDessin: String(r['Fichier dessin'] ?? ''),
    zoneRect: zoneRect(r)
  }))
}

// Chemin (relatif à la bibliothèque) du dessin d'une ligne, ou null.
function cheminDessin(r) {
  return r.fichierDessin ? `dessins/${r.visiteId}/${basename(r.fichierDessin)}` : null
}

export function upsertLibrary(lib, rows) {
  const base = migrateLibrary(lib)
  const touchedVisites = new Set(rows.map((r) => r.visiteId))

  // On repart des visites/photos NON concernées par cet import.
  const visites = base.visites.filter((v) => !touchedVisites.has(v.id))
  const photos = base.photos.filter((p) => !touchedVisites.has(p.visiteId))

  const importeLe = new Date().toISOString()
  const seenVisite = new Set()
  rows.forEach((r, ordre) => {
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
      chemin: `photos/${r.visiteId}/${r.photoId}.jpg`,
      dessin: cheminDessin(r),
      zoneRect: r.zoneRect ?? null,
      ordre
    })
  })

  return {
    // points / legendes / reglages : JAMAIS touchés par un import.
    lib: { ...base, version: 2, visites, photos },
    resume: { visites: seenVisite.size, photos: rows.length }
  }
}

export function importZip(zipPath, libraryDir) {
  const zip = new AdmZip(zipPath)
  const dataEntry = zip.getEntry('data.xlsx')
  if (!dataEntry) throw new Error('data.xlsx introuvable dans le ZIP')
  const rows = parseDataXlsx(dataEntry.getData())

  // Supprimer photos et dessins des visites ré-importées (remplacement).
  for (const visiteId of new Set(rows.map((r) => r.visiteId))) {
    rmSync(join(photosDir(libraryDir), visiteId), { recursive: true, force: true })
    rmSync(join(dessinsDir(libraryDir), visiteId), { recursive: true, force: true })
  }

  // Copier chaque photo présente dans le ZIP vers photos/<visiteId>/<photoId>.jpg.
  for (const r of rows) {
    const entry = zip.getEntry(r.cheminPhoto)
    if (!entry) continue // photo absente du ZIP : ignorée
    const dest = join(photosDir(libraryDir), r.visiteId, `${r.photoId}.jpg`)
    mkdirSync(join(photosDir(libraryDir), r.visiteId), { recursive: true })
    writeFileSync(dest, entry.getData())
  }

  // Dessins : copiés une fois par visite ; absent du ZIP -> pas de dessin.
  const dessinsCopies = new Set()
  for (const r of rows) {
    const rel = cheminDessin(r)
    if (!rel || dessinsCopies.has(rel)) continue
    const entry = zip.getEntry(r.fichierDessin)
    if (!entry) {
      r.fichierDessin = ''
      continue
    }
    mkdirSync(join(dessinsDir(libraryDir), r.visiteId), { recursive: true })
    writeFileSync(join(libraryDir, rel), entry.getData())
    dessinsCopies.add(rel)
  }
  const { lib, resume } = upsertLibrary(loadLibrary(libraryDir), rows)
  saveLibrary(libraryDir, lib)
  return resume
}
