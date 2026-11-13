// Impression du rapport HTML en PDF (et aperçu) avec le moteur d'Electron.
import { BrowserWindow } from 'electron'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

// Le HTML est écrit dans un fichier de la bibliothèque pour que les images
// (file://) se chargent depuis une page elle-même en file://.
function ecrireHtml(libraryDir, html, nom) {
  const dir = join(libraryDir, 'tmp')
  mkdirSync(dir, { recursive: true })
  const fichier = join(dir, nom)
  writeFileSync(fichier, html, 'utf-8')
  return fichier
}

const ATTENDRE_IMAGES = `Promise.all([...document.images].map((i) =>
  i.complete ? null : new Promise((r) => { i.onload = r; i.onerror = r })))`

/** Renvoie les octets du PDF. */
export async function genererPdf(libraryDir, html, footer) {
  const fichier = ecrireHtml(libraryDir, html, 'rapport.html')
  const win = new BrowserWindow({ show: false, webPreferences: { sandbox: true } })
  try {
    await win.loadFile(fichier)
    await win.webContents.executeJavaScript(ATTENDRE_IMAGES)
    return await win.webContents.printToPDF({
      pageSize: 'A4',
      printBackground: true,
      preferCSSPageSize: true,
      displayHeaderFooter: true,
      headerTemplate: '<span></span>',
      footerTemplate: footer
    })
  } finally {
    win.destroy()
  }
}

/** Ouvre une fenêtre d'aperçu du rapport (rendu écran du même HTML). */
export async function ouvrirApercu(libraryDir, html, titre) {
  const fichier = ecrireHtml(libraryDir, html, 'apercu.html')
  const win = new BrowserWindow({
    width: 900, height: 1000, title: titre, autoHideMenuBar: true,
    webPreferences: { sandbox: true }
  })
  await win.loadFile(fichier)
  return win
}
