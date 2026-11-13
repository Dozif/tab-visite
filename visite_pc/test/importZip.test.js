import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdtempSync, rmSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import AdmZip from 'adm-zip'
import * as XLSX from 'xlsx'
import { importZip } from '../src/main/import.js'
import { loadLibrary } from '../src/main/library.js'

let dir
beforeEach(() => { dir = mkdtempSync(join(tmpdir(), 'vpc-')) })
afterEach(() => { rmSync(dir, { recursive: true, force: true }) })

function buildZip(rows, photoNames) {
  const header = ['Rame', 'Type', 'Niveau', 'Date visite', 'Plan', 'Zone',
    'Date prise', 'Traitée', 'Chemin photo', 'Visite ID', 'Photo ID']
  const ws = XLSX.utils.aoa_to_sheet([header, ...rows])
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Photos')
  const xlsxBuf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' })
  const zip = new AdmZip()
  zip.addFile('data.xlsx', xlsxBuf)
  for (const name of photoNames) zip.addFile(name, Buffer.from([1, 2, 3]))
  const zipPath = join(dir, `export_${photoNames.length}.zip`)
  zip.writeZip(zipPath)
  return zipPath
}

describe('importZip', () => {
  it('importe photos + metadata dans la bibliotheque', () => {
    const chemin = 'photos/Remorque R3/R3 D1/0_p1.jpg'
    const zipPath = buildZip(
      [[3, 'MKBDR', '2N', '14/07/2026', 'Remorque R3', 'R3 D1',
        '14/07/2026 10:22', 'non', chemin, 'v1', 'p1']],
      [chemin]
    )
    const libDir = join(dir, 'lib')
    const resume = importZip(zipPath, libDir)
    expect(resume).toEqual({ visites: 1, photos: 1 })

    const lib = loadLibrary(libDir)
    expect(lib.visites).toHaveLength(1)
    expect(lib.photos).toHaveLength(1)
    expect(existsSync(join(libDir, 'photos', 'v1', 'p1.jpg'))).toBe(true)
  })

  it('re-import remplace les photos de la visite', () => {
    const libDir = join(dir, 'lib')
    const c1 = 'photos/Remorque R3/R3 D1/0_p1.jpg'
    importZip(buildZip([[3, 'MKBDR', '2N', '14/07/2026', 'Remorque R3', 'R3 D1',
      '14/07/2026 10:22', 'non', c1, 'v1', 'p1']], [c1]), libDir)
    const c2 = 'photos/Remorque R3/R3 D1/0_p2.jpg'
    importZip(buildZip([[3, 'MKBDR', '2N', '14/07/2026', 'Remorque R3', 'R3 D1',
      '14/07/2026 10:30', 'non', c2, 'v1', 'p2']], [c2]), libDir)

    const lib = loadLibrary(libDir)
    expect(lib.photos.map((p) => p.id)).toEqual(['p2'])
    expect(existsSync(join(libDir, 'photos', 'v1', 'p2.jpg'))).toBe(true)
    expect(existsSync(join(libDir, 'photos', 'v1', 'p1.jpg'))).toBe(false)
  })

  function zip16(dessinDansZip) {
    const header = ['Rame', 'Type', 'Niveau', 'Date visite', 'Plan', 'Zone',
      'Date prise', 'Traitée', 'Chemin photo', 'Visite ID', 'Photo ID',
      'Fichier dessin', 'Zone X', 'Zone Y', 'Zone largeur', 'Zone hauteur']
    const chemin = 'photos/R/D1/0_p1.jpg'
    const ws = XLSX.utils.aoa_to_sheet([header,
      ['3', 'MKBDR', '2N', '14/07/2026', 'Remorque R3', 'R3 D1', '14/07/2026 10:22',
        'non', chemin, 'v1', 'p1', 'dessins/pl1.png', '0.25', '0.5', '0.03', '0.07']])
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, 'Photos')
    const zip = new AdmZip()
    zip.addFile('data.xlsx', XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }))
    zip.addFile(chemin, Buffer.from([1]))
    if (dessinDansZip) zip.addFile('dessins/pl1.png', Buffer.from([9, 9]))
    const zipPath = join(dir, `z16_${dessinDansZip}.zip`)
    zip.writeZip(zipPath)
    return zipPath
  }

  it('copie les dessins et les rattache aux photos', () => {
    const libDir = join(dir, 'lib')
    importZip(zip16(true), libDir)
    expect(existsSync(join(libDir, 'dessins', 'v1', 'pl1.png'))).toBe(true)
    const lib = loadLibrary(libDir)
    expect(lib.photos[0].dessin).toBe('dessins/v1/pl1.png')
    expect(lib.photos[0].zoneRect).toEqual({ x: 0.25, y: 0.5, l: 0.03, h: 0.07 })
  })

  it('dessin annoncé mais absent du ZIP : photo sans dessin', () => {
    const libDir = join(dir, 'lib')
    importZip(zip16(false), libDir)
    expect(loadLibrary(libDir).photos[0].dessin).toBe(null)
  })
})
