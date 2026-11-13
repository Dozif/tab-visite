import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'

// v2+ : ajoute les saisies du rapport, stockées À PART des photos pour qu'un
// réimport de visite (qui remplace ses photos) ne les efface jamais.
//   points   : [{ visiteId, plan, zone, gravite, tempsChaud, tempsPeinture, commentaire, inclusion, marque }]
//   legendes : { <photoId>: texte }
//   photosExclues : [<photoId>] photos décochées « Dans le rapport »
//   reglages : { redacteur, dernierNumero: { <prefixe>: n } }
const EMPTY = { version: 3, visites: [], photos: [], points: [], legendes: {}, photosExclues: [], reglages: {} }

export function libraryFile(libraryDir) {
  return join(libraryDir, 'library.json')
}

export function photosDir(libraryDir) {
  return join(libraryDir, 'photos')
}

export function dessinsDir(libraryDir) {
  return join(libraryDir, 'dessins')
}

// v3 : le temps unique d'un point (tempsH) est détaillé en chaudronnerie +
// peinture ; l'ancien temps devient le temps de peinture. Ajoute la marque
// manuelle (rond placé à la main sur le dessin).
function migrerPoint(p) {
  if (!('tempsH' in p) && 'tempsPeinture' in p) return p
  const { tempsH, ...reste } = p
  return {
    ...reste,
    tempsChaud: reste.tempsChaud ?? null,
    tempsPeinture: reste.tempsPeinture ?? tempsH ?? null,
    marque: reste.marque ?? null
  }
}

/** Met une bibliothèque (v1, v2 ou v3) au format v3, sans rien perdre. */
export function migrateLibrary(lib) {
  return {
    ...lib,
    version: 3,
    visites: lib.visites ?? [],
    photos: lib.photos ?? [],
    points: (lib.points ?? []).map(migrerPoint),
    legendes: lib.legendes ?? {},
    photosExclues: lib.photosExclues ?? [],
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
