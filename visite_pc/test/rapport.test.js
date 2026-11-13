import { describe, it, expect } from 'vitest'
import {
  setPoint, findPoint, estInclus, pointsDeVisite, resumeVisite,
  visitesParDefaut, numeroRapport, buildRapport, formatHeures
} from '../src/shared/rapport.js'

// Bibliothèque d'exemple : rame 123, deux visites le 13/11, une le 02/10.
function lib() {
  const photo = (id, visiteId, plan, zone, ordre, extra = {}) => ({
    id, visiteId, plan, zone, ordre, datePrise: '13/11/2026 10:00', traitee: false,
    chemin: `photos/${visiteId}/${id}.jpg`, dessin: null, zoneRect: null, ...extra
  })
  return {
    version: 2,
    visites: [
      { id: 'vR', rame: 123, type: 'MKBDR', niveau: '2N', dateVisite: '13/11/2026' },
      { id: 'vM', rame: 123, type: 'MKBAM', niveau: '2N', dateVisite: '13/11/2026' },
      { id: 'vOld', rame: 123, type: 'MKBDR', niveau: '2N', dateVisite: '02/10/2026' },
      { id: 'vAutre', rame: 7, type: 'MKBDR', niveau: '2N', dateVisite: '20/11/2026' }
    ],
    photos: [
      photo('r1', 'vR', 'Remorque R1', 'R1 D1', 0, { dessin: 'dessins/vR/a.png', zoneRect: { x: 0.1, y: 0.2, l: 0.03, h: 0.07 } }),
      photo('r2', 'vR', 'Remorque R1', 'R1 D1', 1),
      photo('r3', 'vR', 'Remorque R1', 'R1 DT', 2),
      photo('r4', 'vR', 'Remorque R2', 'R2 G4', 3),
      photo('m1', 'vM', 'Motrice M1', 'M1 D2', 0),
      photo('o1', 'vOld', 'Remorque R1', 'R1 D1', 0)
    ],
    points: [], legendes: { r2: 'vue de près' }, reglages: {}
  }
}

function annote(l) {
  l = setPoint(l, { visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 D1', gravite: 'critique', tempsH: 3, commentaire: 'Perforation' })
  l = setPoint(l, { visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 DT', gravite: 'moyenne', tempsH: 1.5 })
  l = setPoint(l, { visiteId: 'vR', plan: 'Remorque R2', zone: 'R2 G4', gravite: 'mineure' }) // sans temps : auto -> exclu
  l = setPoint(l, { visiteId: 'vM', plan: 'Motrice M1', zone: 'M1 D2', gravite: 'critique', tempsH: 4 })
  return l
}

describe('points', () => {
  it('setPoint crée avec défauts puis fusionne', () => {
    let l = setPoint(lib(), { visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 D1', gravite: 'moyenne' })
    expect(findPoint(l, 'vR', 'Remorque R1', 'R1 D1')).toEqual({
      visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 D1',
      gravite: 'moyenne', tempsH: null, commentaire: '', inclusion: 'auto'
    })
    l = setPoint(l, { visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 D1', tempsH: 2 })
    expect(findPoint(l, 'vR', 'Remorque R1', 'R1 D1')).toMatchObject({ gravite: 'moyenne', tempsH: 2 })
    expect(l.points).toHaveLength(1)
  })

  it('setPoint ne modifie pas la bibliothèque reçue', () => {
    const l0 = lib()
    setPoint(l0, { visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 D1', gravite: 'moyenne' })
    expect(l0.points).toEqual([])
  })

  it('inclusion : auto / oui / non', () => {
    expect(estInclus(null)).toBe(false)
    expect(estInclus({ gravite: 'critique', tempsH: 1, inclusion: 'auto' })).toBe(true)
    expect(estInclus({ gravite: 'critique', tempsH: null, inclusion: 'auto' })).toBe(false)
    expect(estInclus({ gravite: null, tempsH: 2, inclusion: 'auto' })).toBe(false)
    expect(estInclus({ gravite: 'critique', tempsH: 0, inclusion: 'auto' })).toBe(true)
    expect(estInclus({ gravite: null, tempsH: null, inclusion: 'oui' })).toBe(true)
    expect(estInclus({ gravite: 'critique', tempsH: 1, inclusion: 'non' })).toBe(false)
  })

  it('pointsDeVisite regroupe les photos par point, dans l\'ordre d\'import', () => {
    const pts = pointsDeVisite(annote(lib()), 'vR')
    expect(pts.map((p) => p.zone)).toEqual(['R1 D1', 'R1 DT', 'R2 G4'])
    expect(pts[0].photos.map((p) => p.id)).toEqual(['r1', 'r2'])
    expect(pts[0].point.gravite).toBe('critique')
  })

  it('resumeVisite compte les points inclus et leurs heures', () => {
    expect(resumeVisite(annote(lib()), 'vR')).toEqual({ nbPoints: 2, heures: 4.5 })
    expect(resumeVisite(lib(), 'vR')).toEqual({ nbPoints: 0, heures: 0 })
  })
})

describe('rapport', () => {
  it('visites par défaut : même date que la plus récente de la rame', () => {
    expect(visitesParDefaut(lib(), 123).sort()).toEqual(['vM', 'vR'])
    expect(visitesParDefaut(lib(), 999)).toEqual([])
  })

  it('numéro : RC-<rame>-<AAAAMMJJ> puis -2, -3 le même jour', () => {
    const d = new Date(2026, 10, 14)
    const a = numeroRapport({}, 123, d)
    expect(a.numero).toBe('RC-123-20261114')
    const b = numeroRapport(a.reglages, 123, d)
    expect(b.numero).toBe('RC-123-20261114-2')
    expect(numeroRapport(b.reglages, 123, d).numero).toBe('RC-123-20261114-3')
    expect(numeroRapport(b.reglages, 7, d).numero).toBe('RC-7-20261114')
  })

  it('buildRapport : tri, numérotation, totaux, synthèse', () => {
    const r = buildRapport(annote(lib()), {
      rame: 123, visiteIds: ['vR', 'vM'], redacteur: 'Franck',
      dateEdition: new Date(2026, 10, 14), numero: 'RC-123-20261114'
    })
    // Critiques d'abord ; à gravité égale, motrices (MKBAM) avant remorques.
    expect(r.points.map((p) => [p.n, p.zone])).toEqual([[1, 'M1 D2'], [2, 'R1 D1'], [3, 'R1 DT']])
    expect(r.synthese).toEqual({
      nbPoints: 3, heures: 8.5,
      parGravite: { critique: { n: 2, h: 7 }, moyenne: { n: 1, h: 1.5 }, mineure: { n: 0, h: 0 } },
      nonEvaluee: { n: 0, h: 0 }
    })
    expect(r.visites.map((v) => [v.type, v.perimetre, v.nbPoints, v.heures]))
      .toEqual([['MKBAM', 'Motrices', 1, 4], ['MKBDR', 'Remorques', 2, 4.5]])
    expect(r).toMatchObject({ numero: 'RC-123-20261114', rame: 123, niveaux: '2N',
      datesVisite: '13/11/2026', redacteur: 'Franck', editeLe: '14/11/2026' })
    const d1 = r.points[1]
    expect(d1).toMatchObject({ plan: 'Remorque R1', typeVisite: 'MKBDR', gravite: 'critique',
      tempsH: 3, commentaire: 'Perforation', dessin: 'dessins/vR/a.png',
      zoneRect: { x: 0.1, y: 0.2, l: 0.03, h: 0.07 } })
    expect(d1.photos).toEqual([
      { chemin: 'photos/vR/r1.jpg', datePrise: '13/11/2026 10:00', legende: '' },
      { chemin: 'photos/vR/r2.jpg', datePrise: '13/11/2026 10:00', legende: 'vue de près' }
    ])
  })

  it('point inclus à la main sans temps ni gravité : listé, hors total', () => {
    let l = annote(lib())
    l = setPoint(l, { visiteId: 'vR', plan: 'Remorque R2', zone: 'R2 G4', gravite: null, inclusion: 'oui' })
    const r = buildRapport(l, { rame: 123, visiteIds: ['vR'], redacteur: '', dateEdition: new Date(2026, 10, 14), numero: 'X' })
    expect(r.points.map((p) => p.zone)).toEqual(['R1 D1', 'R1 DT', 'R2 G4'])
    expect(r.points[2]).toMatchObject({ gravite: null, tempsH: null })
    expect(r.synthese.heures).toBe(4.5)
    expect(r.synthese.nbPoints).toBe(3)
    expect(r.synthese.nonEvaluee).toEqual({ n: 1, h: 0 })
  })

  it("anciennes bibliothèques (photos sans « ordre ») : ordre d'import conservé", () => {
    const l = annote(lib())
    l.photos = l.photos.map(({ ordre, ...ph }) => ph)
    // R1 DT importé avant R1 D1 : l'ordre du tableau doit primer sur le nom.
    const i = l.photos.findIndex((ph) => ph.id === 'r3')
    l.photos.unshift(...l.photos.splice(i, 1))
    expect(pointsDeVisite(l, 'vR').map((p) => p.zone)).toEqual(['R1 DT', 'R1 D1', 'R2 G4'])
    // À gravité égale, le rapport suit aussi cet ordre (et non l'ordre alphabétique).
    const l2 = setPoint(l, { visiteId: 'vR', plan: 'Remorque R1', zone: 'R1 DT', gravite: 'critique' })
    const r = buildRapport(l2, { rame: 123, visiteIds: ['vR'], redacteur: '', dateEdition: new Date(2026, 10, 14), numero: 'X' })
    expect(r.points.map((p) => p.zone)).toEqual(['R1 DT', 'R1 D1'])
  })

  it('une visite seule : rapport séparé, sans mélange de dates', () => {
    let l = setPoint(lib(), { visiteId: 'vOld', plan: 'Remorque R1', zone: 'R1 D1', gravite: 'moyenne', tempsH: 2 })
    l = annote(l)
    const r = buildRapport(l, { rame: 123, visiteIds: ['vOld'], redacteur: '', dateEdition: new Date(2026, 10, 14), numero: 'X' })
    expect(r.datesVisite).toBe('02/10/2026')
    expect(r.points).toHaveLength(1)
  })

  it('erreur si aucun point inclus ou aucune visite', () => {
    const opts = { rame: 123, redacteur: '', dateEdition: new Date(2026, 10, 14), numero: 'X' }
    expect(() => buildRapport(lib(), { ...opts, visiteIds: ['vR'] })).toThrow('Aucun point à inclure')
    expect(() => buildRapport(annote(lib()), { ...opts, visiteIds: [] })).toThrow('Aucun point à inclure')
  })

  it('formatHeures', () => {
    expect(formatHeures(1.5)).toBe('1,5 h')
    expect(formatHeures(12)).toBe('12,0 h')
    expect(formatHeures(0)).toBe('0,0 h')
    expect(formatHeures(null)).toBe('—')
  })
})
