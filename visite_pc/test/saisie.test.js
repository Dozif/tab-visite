import { describe, it, expect } from 'vitest'
import { parseTemps } from '../src/renderer/src/components/PointEditor.jsx'
import { marqueRonde, TAILLES } from '../src/renderer/src/components/LocaliserModal.jsx'

describe('parseTemps', () => {
  it('accepte virgule ou point, arrondit à la demi-heure', () => {
    expect(parseTemps('1,5')).toBe(1.5)
    expect(parseTemps('2')).toBe(2)
    expect(parseTemps(' 1.2 ')).toBe(1)
    expect(parseTemps('1,8')).toBe(2)
    expect(parseTemps('0')).toBe(0)
  })
  it('vide -> null ; invalide ou négatif -> undefined', () => {
    expect(parseTemps('')).toBe(null)
    expect(parseTemps('  ')).toBe(null)
    expect(parseTemps('abc')).toBe(undefined)
    expect(parseTemps('-1')).toBe(undefined)
  })
})

describe('marqueRonde', () => {
  it('rond visuellement circulaire : ry corrigé du ratio largeur/hauteur', () => {
    const m = marqueRonde('dessins/v/a.png', 0.25, 0.5, 'moyen', 2000, 800)
    expect(m).toEqual({ dessin: 'dessins/v/a.png', cx: 0.25, cy: 0.5, rx: TAILLES.moyen, ry: 0.0625 })
  })
  it('tailles croissantes', () => {
    expect(TAILLES.petit).toBeLessThan(TAILLES.moyen)
    expect(TAILLES.moyen).toBeLessThan(TAILLES.grand)
  })
})
