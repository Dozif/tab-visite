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
})
