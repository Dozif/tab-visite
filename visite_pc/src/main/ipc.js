import { ipcMain, dialog } from 'electron'
import { pathToFileURL } from 'node:url'
import { join } from 'node:path'
import { importZip } from './import.js'
import { loadLibrary, photosDir } from './library.js'

export function registerIpc(libraryDir) {
  ipcMain.handle('import:dialog', async () => {
    const res = await dialog.showOpenDialog({
      title: 'Importer un export de visite',
      filters: [{ name: 'Export ZIP', extensions: ['zip'] }],
      properties: ['openFile']
    })
    if (res.canceled || res.filePaths.length === 0) return null
    return importZip(res.filePaths[0], libraryDir)
  })

  ipcMain.handle('library:get', () => loadLibrary(libraryDir))

  ipcMain.handle('photo:url', (_e, cheminRelatif) =>
    pathToFileURL(join(libraryDir, cheminRelatif)).href)
}
