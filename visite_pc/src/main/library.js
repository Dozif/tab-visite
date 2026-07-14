import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const EMPTY = { version: 1, visites: [], photos: [] }

export function libraryFile(libraryDir) {
  return join(libraryDir, 'library.json')
}

export function photosDir(libraryDir) {
  return join(libraryDir, 'photos')
}

export function loadLibrary(libraryDir) {
  const f = libraryFile(libraryDir)
  if (!existsSync(f)) return structuredClone(EMPTY)
  return JSON.parse(readFileSync(f, 'utf-8'))
}

export function saveLibrary(libraryDir, lib) {
  mkdirSync(libraryDir, { recursive: true })
  writeFileSync(libraryFile(libraryDir), JSON.stringify(lib, null, 2), 'utf-8')
}
