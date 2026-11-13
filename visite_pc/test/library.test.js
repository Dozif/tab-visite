import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdtempSync, rmSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { writeFileSync } from 'node:fs'
import { loadLibrary, saveLibrary, photosDir, migrateLibrary } from '../src/main/library.js'

let dir
beforeEach(() => { dir = mkdtempSync(join(tmpdir(), 'vpc-')) })
afterEach(() => { rmSync(dir, { recursive: true, force: true }) })

describe('library', () => {
  it('loadLibrary renvoie une structure vide si absent', () => {
    expect(loadLibrary(dir)).toEqual({
      version: 3, visites: [], photos: [], points: [], legendes: {}, reglages: {}
    })
  })

  it('saveLibrary puis loadLibrary : round-trip', () => {
    const lib = {
      version: 3, visites: [{ id: 'v1' }], photos: [{ id: 'p1' }],
      points: [{ visiteId: 'v1', plan: 'P', zone: 'Z', gravite: 'critique', tempsChaud: null,
        tempsPeinture: 2, commentaire: '', inclusion: 'auto', marque: null }],
      legendes: { p1: 'vue' }, reglages: { redacteur: 'Franck' }
    }
    saveLibrary(dir, lib)
    expect(existsSync(join(dir, 'library.json'))).toBe(true)
    expect(loadLibrary(dir)).toEqual(lib)
  })

  it('migre une bibliothèque v1 existante en v2 sans rien perdre', () => {
    writeFileSync(join(dir, 'library.json'),
      JSON.stringify({ version: 1, visites: [{ id: 'v1' }], photos: [{ id: 'p1' }] }))
    expect(loadLibrary(dir)).toEqual({
      version: 3, visites: [{ id: 'v1' }], photos: [{ id: 'p1' }],
      points: [], legendes: {}, reglages: {}
    })
  })

  it('migrateLibrary est idempotente', () => {
    const v2 = migrateLibrary({ version: 1, visites: [], photos: [] })
    expect(migrateLibrary(structuredClone(v2))).toEqual(v2)
  })

  it('photosDir', () => {
    expect(photosDir(dir)).toBe(join(dir, 'photos'))
  })

  it("migration : l'ancien temps unique devient le temps de peinture", () => {
    const l = migrateLibrary({ version: 2, visites: [], photos: [], legendes: {}, reglages: {},
      points: [{ visiteId: 'v', plan: 'P', zone: 'Z', gravite: 'mineure', tempsH: 1.5, commentaire: '', inclusion: 'auto' }] })
    expect(l.points[0]).toEqual({ visiteId: 'v', plan: 'P', zone: 'Z', gravite: 'mineure',
      tempsChaud: null, tempsPeinture: 1.5, commentaire: '', inclusion: 'auto', marque: null })
    expect(l.version).toBe(3)
  })
})
