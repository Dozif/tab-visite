import { contextBridge, ipcRenderer } from 'electron'

contextBridge.exposeInMainWorld('api', {
  importDialog: () => ipcRenderer.invoke('import:dialog'),
  getLibrary: () => ipcRenderer.invoke('library:get'),
  photoUrl: (cheminRelatif) => ipcRenderer.invoke('photo:url', cheminRelatif),
  // Saisies du rapport : renvoient la bibliothèque à jour.
  setPoint: (patch) => ipcRenderer.invoke('point:set', patch),
  setLegende: (photoId, texte) => ipcRenderer.invoke('legende:set', { photoId, texte }),
  // { rame, visiteIds, redacteur }
  rapportApercu: (opts) => ipcRenderer.invoke('rapport:apercu', opts),
  rapportPdf: (opts) => ipcRenderer.invoke('rapport:pdf', opts)
})
