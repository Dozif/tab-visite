import { describe, it, expect } from 'vitest'
import { rames, visitesForRame, photosForVisite } from '../src/renderer/src/model.js'

const lib = {
  version: 1,
  visites: [
    { id: 'v1', rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '10/07/2026' },
    { id: 'v2', rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '14/07/2026' },
    { id: 'v3', rame: 5, type: 'MKBAM', niveau: '1N', dateVisite: '12/07/2026' }
  ],
  photos: [
    { id: 'p1', visiteId: 'v2', plan: 'Remorque R3', zone: 'R3 D1', traitee: false, chemin: 'photos/v2/p1.jpg' },
    { id: 'p2', visiteId: 'v2', plan: 'Remorque R3', zone: 'R3 D1', traitee: true, chemin: 'photos/v2/p2.jpg' },
    { id: 'p3', visiteId: 'v2', plan: 'Remorque R3', zone: 'R3 D2', traitee: false, chemin: 'photos/v2/p3.jpg' }
  ]
}

describe('model', () => {
  it('rames : agrège, trie, derniere date', () => {
    expect(rames(lib)).toEqual([
      { rame: 3, nbVisites: 2, derniereDate: '14/07/2026' },
      { rame: 5, nbVisites: 1, derniereDate: '12/07/2026' }
    ])
  })

  it('visitesForRame : tri date décroissante + nbPhotos', () => {
    const vs = visitesForRame(lib, 3)
    expect(vs.map((v) => v.id)).toEqual(['v2', 'v1'])
    expect(vs[0].nbPhotos).toBe(3)
    expect(vs[1].nbPhotos).toBe(0)
  })

  it('photosForVisite : regroupe par plan puis zone', () => {
    const groups = photosForVisite(lib, 'v2')
    expect(groups).toHaveLength(1)
    expect(groups[0].plan).toBe('Remorque R3')
    expect(groups[0].zones.map((z) => z.zone)).toEqual(['R3 D1', 'R3 D2'])
    expect(groups[0].zones[0].photos).toHaveLength(2)
  })

  it('photosForVisite : filtre traitee', () => {
    const groups = photosForVisite(lib, 'v2', { traitee: true })
    const total = groups.flatMap((g) => g.zones).flatMap((z) => z.photos)
    expect(total).toHaveLength(1)
    expect(total[0].id).toBe('p2')
  })
})
