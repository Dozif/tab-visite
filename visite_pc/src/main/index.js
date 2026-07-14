import { app, BrowserWindow } from 'electron'
import { join } from 'node:path'
import { registerIpc } from './ipc.js'

// NB: electron-vite compile le main en CJS → __dirname est disponible
// (ne pas utiliser import.meta.dirname ici).
function createWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    title: 'Visites — PC',
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  })
  if (process.env.ELECTRON_RENDERER_URL) {
    win.loadURL(process.env.ELECTRON_RENDERER_URL)
  } else {
    win.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

app.whenReady().then(() => {
  registerIpc(join(app.getPath('userData'), 'library'))
  createWindow()
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
