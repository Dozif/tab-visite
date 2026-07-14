import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdtempSync, rmSync, existsSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { loadLibrary, saveLibrary, photosDir } from '../src/main/library.js'

let dir
beforeEach(() => { dir = mkdtempSync(join(tmpdir(), 'vpc-')) })
afterEach(() => { rmSync(dir, { recursive: true, force: true }) })

describe('library', () => {
  it('loadLibrary renvoie une structure vide si absent', () => {
    expect(loadLibrary(dir)).toEqual({ version: 1, visites: [], photos: [] })
  })

  it('saveLibrary puis loadLibrary : round-trip', () => {
    const lib = { version: 1, visites: [{ id: 'v1' }], photos: [{ id: 'p1' }] }
    saveLibrary(dir, lib)
    expect(existsSync(join(dir, 'library.json'))).toBe(true)
    expect(loadLibrary(dir)).toEqual(lib)
  })

  it('photosDir', () => {
    expect(photosDir(dir)).toBe(join(dir, 'photos'))
  })
})
