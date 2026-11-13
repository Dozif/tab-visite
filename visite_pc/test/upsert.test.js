import { describe, it, expect } from 'vitest'
import { upsertLibrary } from '../src/main/import.js'

const EMPTY = { version: 2, visites: [], photos: [], points: [], legendes: {}, reglages: {} }

function row(visiteId, photoId, extra = {}) {
  return {
    visiteId, photoId, rame: 3, type: 'MKBDR', niveau: '2N',
    dateVisite: '14/07/2026', plan: 'Remorque R3', zone: 'R3 D1',
    datePrise: '14/07/2026 10:22', traitee: false,
    cheminPhoto: `photos/Remorque R3/R3 D1/0_${photoId}.jpg`, ...extra
  }
}

describe('upsertLibrary', () => {
  it('ajoute une visite et ses photos', () => {
    const { lib, resume } = upsertLibrary(EMPTY, [row('v1', 'p1'), row('v1', 'p2')])
    expect(lib.visites).toHaveLength(1)
    expect(lib.visites[0]).toMatchObject({ id: 'v1', rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '14/07/2026' })
    expect(lib.photos).toHaveLength(2)
    expect(lib.photos[0].chemin).toBe('photos/v1/p1.jpg')
    expect(resume).toEqual({ visites: 1, photos: 2 })
  })

  it('re-import de la meme visite : remplace, pas de doublon', () => {
    const first = upsertLibrary(EMPTY, [row('v1', 'p1'), row('v1', 'p2')]).lib
    const { lib } = upsertLibrary(first, [row('v1', 'p3')])
    expect(lib.visites).toHaveLength(1)
    expect(lib.photos).toHaveLength(1)
    expect(lib.photos[0].id).toBe('p3')
  })

  it('une seconde visite distincte coexiste', () => {
    const first = upsertLibrary(EMPTY, [row('v1', 'p1')]).lib
    const { lib } = upsertLibrary(first, [row('v2', 'p9', { rame: 4 })])
    expect(lib.visites.map((v) => v.id).sort()).toEqual(['v1', 'v2'])
    expect(lib.photos).toHaveLength(2)
  })

  it('réimport : conserve points, légendes et réglages', () => {
    const base = upsertLibrary(EMPTY, [row('v1', 'p1')]).lib
    base.points = [{ visiteId: 'v1', plan: 'Remorque R3', zone: 'R3 D1', gravite: 'critique', tempsH: 2, commentaire: 'x', inclusion: 'auto' }]
    base.legendes = { p1: 'vue de près' }
    base.reglages = { redacteur: 'Franck' }
    const { lib } = upsertLibrary(base, [row('v1', 'p1'), row('v1', 'p2')])
    expect(lib.points).toEqual(base.points)
    expect(lib.legendes).toEqual({ p1: 'vue de près' })
    expect(lib.reglages).toEqual({ redacteur: 'Franck' })
    expect(lib.version).toBe(2)
  })

  it("photos : dessin, zoneRect et ordre d'import", () => {
    const { lib } = upsertLibrary(EMPTY, [
      row('v1', 'p1', { fichierDessin: 'dessins/pl1.png', zoneRect: { x: 0.1, y: 0.2, l: 0.03, h: 0.07 } }),
      row('v1', 'p2', { fichierDessin: '', zoneRect: null })
    ])
    expect(lib.photos[0]).toMatchObject({ dessin: 'dessins/v1/pl1.png', zoneRect: { x: 0.1, y: 0.2, l: 0.03, h: 0.07 }, ordre: 0 })
    expect(lib.photos[1]).toMatchObject({ dessin: null, zoneRect: null, ordre: 1 })
  })
})
