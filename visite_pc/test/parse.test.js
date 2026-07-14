import { describe, it, expect } from 'vitest'
import * as XLSX from 'xlsx'
import { parseDataXlsx } from '../src/main/import.js'

function makeXlsx(rows) {
  const header = ['Rame', 'Type', 'Niveau', 'Date visite', 'Plan', 'Zone',
    'Date prise', 'Traitée', 'Chemin photo', 'Visite ID', 'Photo ID']
  const ws = XLSX.utils.aoa_to_sheet([header, ...rows])
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Photos')
  return XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' })
}

describe('parseDataXlsx', () => {
  it('mappe les colonnes en objets', () => {
    const buf = makeXlsx([
      [3, 'MKBDR', '2N', '14/07/2026', 'Remorque R3', 'R3 D1',
        '14/07/2026 10:22', 'oui', 'photos/Remorque R3/R3 D1/0_p1.jpg', 'v1', 'p1']
    ])
    const rows = parseDataXlsx(buf)
    expect(rows).toHaveLength(1)
    expect(rows[0]).toEqual({
      rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '14/07/2026',
      plan: 'Remorque R3', zone: 'R3 D1', datePrise: '14/07/2026 10:22',
      traitee: true, cheminPhoto: 'photos/Remorque R3/R3 D1/0_p1.jpg',
      visiteId: 'v1', photoId: 'p1'
    })
  })
})
