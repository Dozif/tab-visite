import { ipcMain, dialog, app, shell } from 'electron'
import { pathToFileURL } from 'node:url'
import { join } from 'node:path'
import { writeFileSync } from 'node:fs'
import { importZip } from './import.js'
import { loadLibrary, saveLibrary } from './library.js'
import { setPoint, numeroRapport, buildRapport } from '../shared/rapport.js'
import { renderRapportHtml, footerTemplate } from './rapportHtml.js'
import { genererPdf, ouvrirApercu } from './rapportPdf.js'

const deux = (n) => String(n).padStart(2, '0')
const dateIso = (d) => `${d.getFullYear()}-${deux(d.getMonth() + 1)}-${deux(d.getDate())}`

export function registerIpc(libraryDir) {
  const fileUrl = (cheminRelatif) => pathToFileURL(join(libraryDir, cheminRelatif)).href

  // Charge, applique une modification, enregistre, renvoie la bibliothèque.
  function modifier(fn) {
    const lib = fn(loadLibrary(libraryDir))
    saveLibrary(libraryDir, lib)
    return lib
  }

  // Rapport (numéro calculé à partir des réglages, non enregistré ici).
  function preparer({ rame, visiteIds, redacteur }) {
    const lib = loadLibrary(libraryDir)
    const date = new Date()
    const { numero, reglages } = numeroRapport(lib.reglages, rame, date)
    const rapport = buildRapport(lib, { rame, visiteIds, redacteur, dateEdition: date, numero })
    return { rapport, reglages, date }
  }

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

  ipcMain.handle('photo:url', (_e, cheminRelatif) => fileUrl(cheminRelatif))

  // Saisie d'un point : { visiteId, plan, zone, gravite?, tempsH?, commentaire?, inclusion? }
  ipcMain.handle('point:set', (_e, patch) => modifier((lib) => setPoint(lib, patch)))

  ipcMain.handle('legende:set', (_e, { photoId, texte }) => modifier((lib) => {
    const legendes = { ...lib.legendes }
    if (texte) legendes[photoId] = texte
    else delete legendes[photoId]
    return { ...lib, legendes }
  }))

  ipcMain.handle('rapport:apercu', async (_e, opts) => {
    const { rapport } = preparer(opts)
    await ouvrirApercu(libraryDir, renderRapportHtml(rapport, fileUrl),
      `Aperçu — Rapport ${rapport.numero}`)
    return { numero: rapport.numero }
  })

  ipcMain.handle('rapport:pdf', async (_e, opts) => {
    const { rapport, reglages, date } = preparer(opts)
    const res = await dialog.showSaveDialog({
      title: 'Enregistrer le rapport',
      defaultPath: join(app.getPath('documents'),
        `Rapport corrosion - Rame ${rapport.rame} - ${dateIso(date)}.pdf`),
      filters: [{ name: 'PDF', extensions: ['pdf'] }]
    })
    if (res.canceled || !res.filePath) return null
    const pdf = await genererPdf(libraryDir, renderRapportHtml(rapport, fileUrl), footerTemplate(rapport))
    writeFileSync(res.filePath, pdf)
    // Numéro consommé et rédacteur mémorisé seulement une fois le PDF écrit.
    modifier((lib) => ({ ...lib, reglages: { ...reglages, redacteur: opts.redacteur ?? '' } }))
    shell.openPath(res.filePath)
    return { chemin: res.filePath, numero: rapport.numero }
  })
}
