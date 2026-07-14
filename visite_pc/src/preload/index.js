import { contextBridge, ipcRenderer } from 'electron'

contextBridge.exposeInMainWorld('api', {
  importDialog: () => ipcRenderer.invoke('import:dialog'),
  getLibrary: () => ipcRenderer.invoke('library:get'),
  photoUrl: (cheminRelatif) => ipcRenderer.invoke('photo:url', cheminRelatif)
})
