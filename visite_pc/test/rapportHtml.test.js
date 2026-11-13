import { describe, it, expect } from 'vitest'
import { renderRapportHtml, footerTemplate, escapeHtml } from '../src/main/rapportHtml.js'

function rapport(extra = {}) {
  return {
    numero: 'RC-123-20261114', rame: 123, niveaux: '2N', datesVisite: '13/11/2026',
    redacteur: 'Franck', editeLe: '14/11/2026',
    visites: [
      { type: 'MKBAM', perimetre: 'Motrices', niveau: '2N', dateVisite: '13/11/2026', nbPoints: 1, heures: 4 },
      { type: 'MKBDR', perimetre: 'Remorques', niveau: '2N', dateVisite: '13/11/2026', nbPoints: 2, heures: 8 }
    ],
    synthese: {
      nbPoints: 3, heures: 12,
      parGravite: { critique: { n: 1, h: 4 }, moyenne: { n: 1, h: 6 }, mineure: { n: 1, h: 2 } }
    },
    points: [
      { n: 1, zone: 'M1 D2', plan: 'Motrice M1', typeVisite: 'MKBAM', gravite: 'critique', tempsH: 4,
        commentaire: '<b>&"x"</b>\nligne2', dessin: 'dessins/v/a.png', zoneRect: { x: 0.1, y: 0.2, l: 0.04, h: 0.1 },
        photos: [{ chemin: 'photos/v/p1.jpg', datePrise: '13/11/2026 09:42', legende: 'vue <rapprochée>' }] },
      { n: 2, zone: 'R1 D1', plan: 'Remorque R1', typeVisite: 'MKBDR', gravite: 'moyenne', tempsH: 6,
        commentaire: 'Reprise tôle', dessin: null, zoneRect: null,
        photos: [{ chemin: 'photos/v/p2.jpg', datePrise: '13/11/2026 10:05', legende: '' }] },
      { n: 3, zone: 'R2 G4', plan: 'Remorque R2', typeVisite: 'MKBDR', gravite: 'mineure', tempsH: 2,
        commentaire: '', dessin: null, zoneRect: null, photos: [] }
    ],
    ...extra
  }
}

const url = (c) => `file:///lib/${c}`
const compter = (s, motif) => s.split(motif).length - 1

describe('renderRapportHtml', () => {
  it('en-tête, synthèse et total', () => {
    const h = renderRapportHtml(rapport(), url)
    expect(h).toContain('RC-123-20261114')
    expect(h).toContain('Rapport de visite corrosion')
    expect(h).toContain('12,0 h')
    expect(h).toContain('Rédigé par')
    expect(h).toContain('Franck')
    expect(h).toContain('Motrices')
    expect(h).not.toContain('MAQUETTE')
  })

  it('une fiche par point, badges de gravité', () => {
    const h = renderRapportHtml(rapport(), url)
    expect(compter(h, 'class="point"')).toBe(3)
    expect(h).toContain('class="badge crit"')
    expect(h).toContain('class="badge moy"')
    expect(h).toContain('class="badge min"')
  })

  it('échappe le texte et conserve les retours à la ligne', () => {
    const h = renderRapportHtml(rapport(), url)
    expect(h).toContain('&lt;b&gt;&amp;&quot;x&quot;&lt;/b&gt;<br>ligne2')
    expect(h).toContain('vue &lt;rapprochée&gt;')
    expect(h).not.toContain('<b>&"x"</b>')
  })

  it('localisation seulement si le dessin est connu, ellipse placée sur le point', () => {
    const h = renderRapportHtml(rapport(), url)
    expect(compter(h, 'class="loc"')).toBe(1)
    expect(h).toContain('src="file:///lib/dessins/v/a.png"')
    // centre (0.12, 0.25), rayons (0.02+0.012, 0.05+0.024)
    expect(h).toMatch(/<ellipse cx="0\.12" cy="0\.25" rx="0\.032" ry="0\.074"/)
  })

  it('photos en file:// et point sans photo toléré', () => {
    const h = renderRapportHtml(rapport(), url)
    expect(h).toContain('src="file:///lib/photos/v/p1.jpg"')
    expect(h).toContain('13/11/2026 09:42')
  })

  it('point sans temps ni gravité : « — » et « Non évaluée »', () => {
    const r = rapport()
    r.points[2] = { ...r.points[2], gravite: null, tempsH: null }
    const h = renderRapportHtml(r, url)
    expect(h).toContain('Non évaluée')
    expect(h).toContain('—')
  })

  it('extrait de constat limité dans le récapitulatif', () => {
    const r = rapport()
    r.points[1].commentaire = 'a'.repeat(200)
    const h = renderRapportHtml(r, url)
    expect(h).toContain('a'.repeat(60) + '…')
  })
})

describe('footerTemplate / escapeHtml', () => {
  it('pied de page avec numéro, rame et pagination', () => {
    const f = footerTemplate(rapport())
    expect(f).toContain('Rapport RC-123-20261114 · Rame 123')
    expect(f).toContain('class="pageNumber"')
    expect(f).toContain('class="totalPages"')
  })

  it('escapeHtml', () => {
    expect(escapeHtml(`<a href='x'>&</a>`)).toBe('&lt;a href=&#39;x&#39;&gt;&amp;&lt;/a&gt;')
    expect(escapeHtml(null)).toBe('')
  })
})
