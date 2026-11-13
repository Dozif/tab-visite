import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'

// v2 : ajoute les saisies du rapport, stockées À PART des photos pour qu'un
// réimport de visite (qui remplace ses photos) ne les efface jamais.
//   points   : [{ visiteId, plan, zone, gravite, tempsH, commentaire, inclusion }]
//   legendes : { <photoId>: texte }
//   reglages : { redacteur, dernierNumero: { <prefixe>: n } }
const EMPTY = { version: 2, visites: [], photos: [], points: [], legendes: {}, reglages: {} }

export function libraryFile(libraryDir) {
  return join(libraryDir, 'library.json')
}

export function photosDir(libraryDir) {
  return join(libraryDir, 'photos')
}

export function dessinsDir(libraryDir) {
  return join(libraryDir, 'dessins')
}

/** Met une bibliothèque (v1 ou v2) au format v2, sans rien perdre. */
export function migrateLibrary(lib) {
  return {
    ...lib,
    version: 2,
    visites: lib.visites ?? [],
    photos: lib.photos ?? [],
    points: lib.points ?? [],
    legendes: lib.legendes ?? {},
    reglages: lib.reglages ?? {}
  }
}

export function loadLibrary(libraryDir) {
  const f = libraryFile(libraryDir)
  if (!existsSync(f)) return structuredClone(EMPTY)
  return migrateLibrary(JSON.parse(readFileSync(f, 'utf-8')))
}

export function saveLibrary(libraryDir, lib) {
  mkdirSync(libraryDir, { recursive: true })
  writeFileSync(libraryFile(libraryDir), JSON.stringify(lib, null, 2), 'utf-8')
}
