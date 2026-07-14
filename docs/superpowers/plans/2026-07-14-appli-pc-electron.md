# Appli PC Electron — Consultation/archivage des visites — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire une appli PC (Electron + React) qui importe les ZIP d'export de la tablette et permet de consulter/archiver toutes les visites de corrosion, navigation par rame.

**Architecture:** Electron 2 process. Le **process principal (Node)** extrait le ZIP, lit `data.xlsx` (SheetJS), et maintient une **bibliothèque locale persistante** (`library.json` + dossier `photos/`) ; il expose des canaux **IPC**. Le **renderer (React + Vite)** affiche l'UI (rames → visites → photos) en appelant ces canaux via un preload sécurisé. La logique pure (lecture/écriture bibliothèque, parsing, dédoublonnage, mise en forme UI) vit dans des modules Node testés isolément.

**Tech Stack:** Electron, electron-vite, Vite, React 18, SheetJS (`xlsx`), `adm-zip`, Vitest. JavaScript (ESM).

## Global Constraints

- Nouveau projet dans **`visite_pc/`** (monorepo, à côté de `tab_visite/`). 100 % hors-ligne.
- Renderer **sans accès disque direct** : `contextIsolation: true`, `nodeIntegration: false`, tout passe par le preload/IPC.
- Modules de logique (`src/main/library.js`, `src/main/import.js`, `src/renderer/src/model.js`) **n'importent jamais `electron`** → testables sous Vitest en environnement Node. Ils reçoivent le dossier bibliothèque en **paramètre** (`libraryDir`).
- Dédoublonnage par **`Visite ID`** (UUID) ; identité photo par **`Photo ID`** (UUID). Ces UUID viennent de l'export tablette (Task 1).
- Format du paquet (contrat, déjà en place) : ZIP contenant `data.xlsx` (feuille `Photos`, 1 ligne/photo) + `photos/…`. Colonnes : `Rame | Type | Niveau | Date visite | Plan | Zone | Date prise | Traitée | Chemin photo | Visite ID | Photo ID`.
- Périmètre : **consulter/archiver uniquement**. Hors périmètre : annotation, marquage traité depuis le PC, rapports PDF, packaging `.exe`.
- Commits fréquents, un par tâche.

---

### Task 1: Export tablette — ajouter les colonnes `Visite ID` et `Photo ID`

Prérequis au dédoublonnage côté PC. Changement Flutter dans `tab_visite/`.

**Files:**
- Modify: `tab_visite/lib/services/export_service.dart` (constante `_entetes`, lignes des deux exports, requête via repo)
- Modify: `tab_visite/lib/data/repositories/photo_repository.dart` (`joinedAllByVisite` : ajouter `vi.id`)
- Test: `tab_visite/test/export_service_test.dart`

**Interfaces:**
- Produces: `data.xlsx` avec **11 colonnes**, les 2 dernières = `Visite ID`, `Photo ID`.

- [ ] **Step 1: Écrire le test qui échoue** — dans `tab_visite/test/export_service_test.dart`, à la fin du test `exportVisiteToZip : photos + data.xlsx`, juste avant `await db.close();`, ajouter l'assertion sur le nombre de colonnes :

```dart
    // 11 colonnes attendues (9 + Visite ID + Photo ID).
    expect(book.tables['Photos']!.rows.first.length, 11);
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run (préambule PowerShell de la mémoire) : `flutter test test/export_service_test.dart`
Expected: FAIL (`Expected: 11 Actual: 9`).

- [ ] **Step 3: Ajouter `vi.id` à la requête globale** — dans `tab_visite/lib/data/repositories/photo_repository.dart`, méthode `joinedAllByVisite`, ajouter `vi.id AS visite_id,` dans le `SELECT` :

```dart
      SELECT ph.id, ph.date_prise, ph.traitee, ph.chemin_fichier,
             z.nom AS zone_nom, pl.nom AS plan_nom, pl.ordre AS plan_ordre,
             vi.id AS visite_id, vi.numero_rame, vi.type_visite, vi.niveau, vi.date_visite
```

- [ ] **Step 4: Ajouter les 2 colonnes à l'export** — dans `tab_visite/lib/services/export_service.dart` :

Constante `_entetes` :
```dart
  static const _entetes = [
    'Rame', 'Type', 'Niveau', 'Date visite',
    'Plan', 'Zone', 'Date prise', 'Traitée', 'Chemin photo',
    'Visite ID', 'Photo ID',
  ];
```

Dans `exportVisiteToZip`, la liste `data.add([...])` — ajouter les 2 valeurs en fin :
```dart
      data.add([
        '${v.numeroRame}', v.typeVisite, v.niveau, formatDate(v.dateVisite),
        r['plan_nom'] as String, r['zone_nom'] as String,
        formatDateHeure(datePrise), _ouiNon(r['traitee']), chemin,
        v.id, r['id'] as String,
      ]);
```

Dans `exportAllVisitesToZip`, la liste `data.add([...])` — ajouter les 2 valeurs en fin :
```dart
      data.add([
        '$rame', type, niveau, formatDate(r['date_visite'] as int),
        r['plan_nom'] as String, r['zone_nom'] as String,
        formatDateHeure(datePrise), _ouiNon(r['traitee']), chemin,
        r['visite_id'] as String, r['id'] as String,
      ]);
```

- [ ] **Step 5: Lancer toute la suite Flutter**

Run: `flutter test`
Expected: PASS (tous verts). Ne PAS lancer pendant un `flutter run` (verrou projet).

- [ ] **Step 6: Commit**

```bash
git add tab_visite/lib/services/export_service.dart tab_visite/lib/data/repositories/photo_repository.dart tab_visite/test/export_service_test.dart
git commit -m "feat(export): colonnes Visite ID + Photo ID dans data.xlsx (dedoublonnage PC)"
```

---

### Task 2: Scaffold `visite_pc` (Electron + React + Vite + Vitest)

**Files:**
- Create: `visite_pc/package.json`
- Create: `visite_pc/electron.vite.config.js`
- Create: `visite_pc/vitest.config.js`
- Create: `visite_pc/.gitignore`
- Create: `visite_pc/src/main/index.js`
- Create: `visite_pc/src/preload/index.js`
- Create: `visite_pc/src/renderer/index.html`
- Create: `visite_pc/src/renderer/src/main.jsx`
- Create: `visite_pc/src/renderer/src/App.jsx`
- Test: `visite_pc/test/smoke.test.js`

**Interfaces:**
- Produces: projet lançable via `npm run dev` (fenêtre Electron « Visites — PC ») et testable via `npm test` (Vitest).

- [ ] **Step 1: `visite_pc/package.json`**

```json
{
  "name": "visite-pc",
  "version": "0.1.0",
  "description": "Consultation/archivage des visites de corrosion (import des exports tablette).",
  "main": "./out/main/index.js",
  "scripts": {
    "dev": "electron-vite dev",
    "build": "electron-vite build",
    "test": "vitest run"
  },
  "dependencies": {
    "adm-zip": "^0.5.16",
    "xlsx": "^0.18.5"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "electron": "^33.2.0",
    "electron-vite": "^2.3.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "vite": "^5.4.11",
    "vitest": "^2.1.8"
  }
}
```

- [ ] **Step 2: `visite_pc/.gitignore`**

```
node_modules/
out/
dist/
.vite/
```

- [ ] **Step 3: `visite_pc/electron.vite.config.js`**

```js
import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  main: { plugins: [externalizeDepsPlugin()] },
  preload: { plugins: [externalizeDepsPlugin()] },
  renderer: { plugins: [react()] }
})
```

- [ ] **Step 4: `visite_pc/vitest.config.js`**

```js
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: { environment: 'node', include: ['test/**/*.test.js'] }
})
```

- [ ] **Step 5: `visite_pc/src/main/index.js`** (fenêtre minimale)

```js
import { app, BrowserWindow } from 'electron'
import { join } from 'node:path'

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
  createWindow()
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
```

- [ ] **Step 6: `visite_pc/src/preload/index.js`** (placeholder, complété Task 8)

```js
import { contextBridge } from 'electron'

contextBridge.exposeInMainWorld('api', {})
```

- [ ] **Step 7: `visite_pc/src/renderer/index.html`**

```html
<!doctype html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Visites — PC</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
```

- [ ] **Step 8: `visite_pc/src/renderer/src/main.jsx`**

```jsx
import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'

createRoot(document.getElementById('root')).render(<App />)
```

- [ ] **Step 9: `visite_pc/src/renderer/src/App.jsx`** (placeholder)

```jsx
import React from 'react'

export default function App() {
  return <h1 style={{ fontFamily: 'sans-serif', padding: 24 }}>Visites — PC</h1>
}
```

- [ ] **Step 10: `visite_pc/test/smoke.test.js`**

```js
import { describe, it, expect } from 'vitest'

describe('scaffold', () => {
  it('vitest tourne', () => {
    expect(1 + 1).toBe(2)
  })
})
```

- [ ] **Step 11: Installer et vérifier**

Run: `cd visite_pc && npm install && npm test`
Expected: Vitest PASS (1 test). Puis `npm run dev` doit ouvrir une fenêtre « Visites — PC » affichant le titre (vérification manuelle ; fermer la fenêtre ensuite).

- [ ] **Step 12: Commit**

```bash
git add visite_pc/
git commit -m "feat(pc): scaffold Electron + React + Vite + Vitest"
```

---

### Task 3: `library.js` — charger/sauver la bibliothèque

**Files:**
- Create: `visite_pc/src/main/library.js`
- Test: `visite_pc/test/library.test.js`

**Interfaces:**
- Produces:
  - `loadLibrary(libraryDir)` → `{ version: 1, visites: [], photos: [] }` (structure vide si le fichier n'existe pas).
  - `saveLibrary(libraryDir, lib)` → écrit `libraryDir/library.json`, crée le dossier si besoin.
  - `photosDir(libraryDir)` → chemin `libraryDir/photos`.

- [ ] **Step 1: Écrire les tests qui échouent** — `visite_pc/test/library.test.js`

```js
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
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd visite_pc && npx vitest run test/library.test.js`
Expected: FAIL (`loadLibrary` non défini).

- [ ] **Step 3: Implémenter `visite_pc/src/main/library.js`**

```js
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
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd visite_pc && npx vitest run test/library.test.js`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add visite_pc/src/main/library.js visite_pc/test/library.test.js
git commit -m "feat(pc): library.js load/save/photosDir"
```

---

### Task 4: `parseDataXlsx` — lire le récap Excel en lignes

**Files:**
- Create: `visite_pc/src/main/import.js`
- Test: `visite_pc/test/parse.test.js`

**Interfaces:**
- Consumes: format `data.xlsx` (Task 1 / contrat).
- Produces: `parseDataXlsx(buffer)` → `Array<{ visiteId, photoId, rame, type, niveau, dateVisite, plan, zone, datePrise, traitee, cheminPhoto }>`. `rame` est un nombre, `traitee` un booléen.

- [ ] **Step 1: Écrire le test qui échoue** — `visite_pc/test/parse.test.js`

```js
import { describe, it, expect } from 'vitest'
import * as XLSX from 'xlsx'
import { parseDataXlsx } from '../src/main/import.js'

function makeXlsx(rows) {
  const header = ['Rame', 'Type', 'Niveau', 'Date visite', 'Plan', 'Zone',
    'Date prise', 'Traitée', 'Chemin photo', 'Visite ID', 'Photo ID']
  const ws = XLSX.utils.aoa_to_sheet([header, ...rows])
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Photos')
  return XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' })
}

describe('parseDataXlsx', () => {
  it('mappe les colonnes en objets', () => {
    const buf = makeXlsx([
      [3, 'MKBDR', '2N', '14/07/2026', 'Remorque R3', 'R3 D1',
        '14/07/2026 10:22', 'oui', 'photos/Remorque R3/R3 D1/0_p1.jpg', 'v1', 'p1']
    ])
    const rows = parseDataXlsx(buf)
    expect(rows).toHaveLength(1)
    expect(rows[0]).toEqual({
      rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '14/07/2026',
      plan: 'Remorque R3', zone: 'R3 D1', datePrise: '14/07/2026 10:22',
      traitee: true, cheminPhoto: 'photos/Remorque R3/R3 D1/0_p1.jpg',
      visiteId: 'v1', photoId: 'p1'
    })
  })
})
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd visite_pc && npx vitest run test/parse.test.js`
Expected: FAIL (`parseDataXlsx` non défini).

- [ ] **Step 3: Implémenter `parseDataXlsx` dans `visite_pc/src/main/import.js`**

```js
import * as XLSX from 'xlsx'

export function parseDataXlsx(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' })
  const ws = wb.Sheets['Photos'] ?? wb.Sheets[wb.SheetNames[0]]
  const raw = XLSX.utils.sheet_to_json(ws, { defval: '' })
  return raw.map((r) => ({
    rame: Number(r['Rame']),
    type: String(r['Type']),
    niveau: String(r['Niveau']),
    dateVisite: String(r['Date visite']),
    plan: String(r['Plan']),
    zone: String(r['Zone']),
    datePrise: String(r['Date prise']),
    traitee: String(r['Traitée']).toLowerCase() === 'oui',
    cheminPhoto: String(r['Chemin photo']),
    visiteId: String(r['Visite ID']),
    photoId: String(r['Photo ID'])
  }))
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd visite_pc && npx vitest run test/parse.test.js`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add visite_pc/src/main/import.js visite_pc/test/parse.test.js
git commit -m "feat(pc): parseDataXlsx (data.xlsx -> lignes)"
```

---

### Task 5: `upsertLibrary` — dédoublonnage par visite

Logique pure de fusion des lignes parsées dans la bibliothèque (métadonnées seules ; la copie des fichiers est en Task 6).

**Files:**
- Modify: `visite_pc/src/main/import.js` (ajouter `upsertLibrary`)
- Test: `visite_pc/test/upsert.test.js`

**Interfaces:**
- Consumes: `parseDataXlsx` (Task 4), lignes `{ visiteId, photoId, rame, type, niveau, dateVisite, plan, zone, datePrise, traitee, cheminPhoto }`.
- Produces: `upsertLibrary(lib, rows)` → **nouvelle** `lib` (immutable) où, pour chaque `visiteId` présent dans `rows`, l'ancienne visite et ses photos sont **remplacées**. Le chemin stocké dans chaque photo devient `photos/<visiteId>/<photoId>.jpg`. Retourne `{ lib, resume: { visites, photos } }`.

- [ ] **Step 1: Écrire les tests qui échouent** — `visite_pc/test/upsert.test.js`

```js
import { describe, it, expect } from 'vitest'
import { upsertLibrary } from '../src/main/import.js'

const EMPTY = { version: 1, visites: [], photos: [] }

function row(visiteId, photoId, extra = {}) {
  return {
    visiteId, photoId, rame: 3, type: 'MKBDR', niveau: '2N',
    dateVisite: '14/07/2026', plan: 'Remorque R3', zone: 'R3 D1',
    datePrise: '14/07/2026 10:22', traitee: false,
    cheminPhoto: `photos/Remorque R3/R3 D1/0_${photoId}.jpg`, ...extra
  }
}

describe('upsertLibrary', () => {
  it('ajoute une visite et ses photos', () => {
    const { lib, resume } = upsertLibrary(EMPTY, [row('v1', 'p1'), row('v1', 'p2')])
    expect(lib.visites).toHaveLength(1)
    expect(lib.visites[0]).toMatchObject({ id: 'v1', rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '14/07/2026' })
    expect(lib.photos).toHaveLength(2)
    expect(lib.photos[0].chemin).toBe('photos/v1/p1.jpg')
    expect(resume).toEqual({ visites: 1, photos: 2 })
  })

  it('re-import de la meme visite : remplace, pas de doublon', () => {
    const first = upsertLibrary(EMPTY, [row('v1', 'p1'), row('v1', 'p2')]).lib
    const { lib } = upsertLibrary(first, [row('v1', 'p3')])
    expect(lib.visites).toHaveLength(1)
    expect(lib.photos).toHaveLength(1)
    expect(lib.photos[0].id).toBe('p3')
  })

  it('une seconde visite distincte coexiste', () => {
    const first = upsertLibrary(EMPTY, [row('v1', 'p1')]).lib
    const { lib } = upsertLibrary(first, [row('v2', 'p9', { rame: 4 })])
    expect(lib.visites.map((v) => v.id).sort()).toEqual(['v1', 'v2'])
    expect(lib.photos).toHaveLength(2)
  })
})
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd visite_pc && npx vitest run test/upsert.test.js`
Expected: FAIL (`upsertLibrary` non défini).

- [ ] **Step 3: Implémenter `upsertLibrary` dans `visite_pc/src/main/import.js`** (ajouter en fin de fichier)

```js
export function upsertLibrary(lib, rows) {
  const touchedVisites = new Set(rows.map((r) => r.visiteId))

  // On repart des visites/photos NON concernées par cet import.
  const visites = lib.visites.filter((v) => !touchedVisites.has(v.id))
  const photos = lib.photos.filter((p) => !touchedVisites.has(p.visiteId))

  const importeLe = new Date().toISOString()
  const seenVisite = new Set()
  for (const r of rows) {
    if (!seenVisite.has(r.visiteId)) {
      seenVisite.add(r.visiteId)
      visites.push({
        id: r.visiteId, rame: r.rame, type: r.type,
        niveau: r.niveau, dateVisite: r.dateVisite, importeLe
      })
    }
    photos.push({
      id: r.photoId, visiteId: r.visiteId, plan: r.plan, zone: r.zone,
      datePrise: r.datePrise, traitee: r.traitee,
      chemin: `photos/${r.visiteId}/${r.photoId}.jpg`
    })
  }

  return {
    lib: { version: 1, visites, photos },
    resume: { visites: seenVisite.size, photos: rows.length }
  }
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd visite_pc && npx vitest run test/upsert.test.js`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add visite_pc/src/main/import.js visite_pc/test/upsert.test.js
git commit -m "feat(pc): upsertLibrary (dedoublonnage par visite)"
```

---

### Task 6: `importZip` — extraction + copie photos + persistance (intégration)

**Files:**
- Modify: `visite_pc/src/main/import.js` (ajouter `importZip`)
- Test: `visite_pc/test/importZip.test.js`

**Interfaces:**
- Consumes: `parseDataXlsx`, `upsertLibrary` (import.js), `loadLibrary`, `saveLibrary`, `photosDir` (library.js), `adm-zip`.
- Produces: `importZip(zipPath, libraryDir)` → copie chaque photo du ZIP vers `libraryDir/photos/<visiteId>/<photoId>.jpg`, met à jour `library.json`, renvoie `{ visites, photos }`. Les photos concernées par un ré-import sont d'abord supprimées du dossier.

- [ ] **Step 1: Écrire le test qui échoue** — `visite_pc/test/importZip.test.js`

```js
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
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd visite_pc && npx vitest run test/importZip.test.js`
Expected: FAIL (`importZip` non défini).

- [ ] **Step 3: Implémenter `importZip` dans `visite_pc/src/main/import.js`** (ajouter en fin ; ajouter les imports en tête)

En tête du fichier (à côté de l'import XLSX existant) :
```js
import AdmZip from 'adm-zip'
import { mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { loadLibrary, saveLibrary, photosDir } from './library.js'
```

En fin de fichier :
```js
export function importZip(zipPath, libraryDir) {
  const zip = new AdmZip(zipPath)
  const dataEntry = zip.getEntry('data.xlsx')
  if (!dataEntry) throw new Error('data.xlsx introuvable dans le ZIP')
  const rows = parseDataXlsx(dataEntry.getData())

  // Supprimer les dossiers photos des visites ré-importées (remplacement).
  for (const visiteId of new Set(rows.map((r) => r.visiteId))) {
    rmSync(join(photosDir(libraryDir), visiteId), { recursive: true, force: true })
  }

  // Copier chaque photo présente dans le ZIP vers photos/<visiteId>/<photoId>.jpg.
  for (const r of rows) {
    const entry = zip.getEntry(r.cheminPhoto)
    if (!entry) continue // photo absente du ZIP : ignorée
    const dest = join(photosDir(libraryDir), r.visiteId, `${r.photoId}.jpg`)
    mkdirSync(join(photosDir(libraryDir), r.visiteId), { recursive: true })
    writeFileSync(dest, entry.getData())
  }

  const { lib, resume } = upsertLibrary(loadLibrary(libraryDir), rows)
  saveLibrary(libraryDir, lib)
  return resume
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd visite_pc && npx vitest run test/importZip.test.js`
Expected: PASS (2 tests).

- [ ] **Step 5: Lancer toute la suite**

Run: `cd visite_pc && npm test`
Expected: PASS (tous les fichiers de test).

- [ ] **Step 6: Commit**

```bash
git add visite_pc/src/main/import.js visite_pc/test/importZip.test.js
git commit -m "feat(pc): importZip (extraction + copie photos + persistance)"
```

---

### Task 7: `model.js` — mise en forme pour l'UI (rame d'abord)

Logique pure de regroupement (renderer), testée sous Vitest.

**Files:**
- Create: `visite_pc/src/renderer/src/model.js`
- Test: `visite_pc/test/model.test.js`

**Interfaces:**
- Consumes: une `lib` `{ visites, photos }` (forme de `library.json`).
- Produces:
  - `rames(lib)` → `Array<{ rame, nbVisites, derniereDate }>` triée par `rame` croissant. `derniereDate` = plus grande `dateVisite` (chaîne `dd/MM/yyyy`, comparée via date réelle).
  - `visitesForRame(lib, rame)` → visites de cette rame triées par date décroissante, chacune enrichie de `nbPhotos`.
  - `photosForVisite(lib, visiteId, filtre)` → `Array<{ plan, zones: Array<{ zone, photos: [...] }> }>` regroupées par plan puis zone ; `filtre` optionnel `{ traitee: true|false }` filtre les photos.

- [ ] **Step 1: Écrire les tests qui échouent** — `visite_pc/test/model.test.js`

```js
import { describe, it, expect } from 'vitest'
import { rames, visitesForRame, photosForVisite } from '../src/renderer/src/model.js'

const lib = {
  version: 1,
  visites: [
    { id: 'v1', rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '10/07/2026' },
    { id: 'v2', rame: 3, type: 'MKBDR', niveau: '2N', dateVisite: '14/07/2026' },
    { id: 'v3', rame: 5, type: 'MKBAM', niveau: '1N', dateVisite: '12/07/2026' }
  ],
  photos: [
    { id: 'p1', visiteId: 'v2', plan: 'Remorque R3', zone: 'R3 D1', traitee: false, chemin: 'photos/v2/p1.jpg' },
    { id: 'p2', visiteId: 'v2', plan: 'Remorque R3', zone: 'R3 D1', traitee: true, chemin: 'photos/v2/p2.jpg' },
    { id: 'p3', visiteId: 'v2', plan: 'Remorque R3', zone: 'R3 D2', traitee: false, chemin: 'photos/v2/p3.jpg' }
  ]
}

describe('model', () => {
  it('rames : agrège, trie, derniere date', () => {
    expect(rames(lib)).toEqual([
      { rame: 3, nbVisites: 2, derniereDate: '14/07/2026' },
      { rame: 5, nbVisites: 1, derniereDate: '12/07/2026' }
    ])
  })

  it('visitesForRame : tri date décroissante + nbPhotos', () => {
    const vs = visitesForRame(lib, 3)
    expect(vs.map((v) => v.id)).toEqual(['v2', 'v1'])
    expect(vs[0].nbPhotos).toBe(3)
    expect(vs[1].nbPhotos).toBe(0)
  })

  it('photosForVisite : regroupe par plan puis zone', () => {
    const groups = photosForVisite(lib, 'v2')
    expect(groups).toHaveLength(1)
    expect(groups[0].plan).toBe('Remorque R3')
    expect(groups[0].zones.map((z) => z.zone)).toEqual(['R3 D1', 'R3 D2'])
    expect(groups[0].zones[0].photos).toHaveLength(2)
  })

  it('photosForVisite : filtre traitee', () => {
    const groups = photosForVisite(lib, 'v2', { traitee: true })
    const total = groups.flatMap((g) => g.zones).flatMap((z) => z.photos)
    expect(total).toHaveLength(1)
    expect(total[0].id).toBe('p2')
  })
})
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `cd visite_pc && npx vitest run test/model.test.js`
Expected: FAIL (`rames` non défini).

- [ ] **Step 3: Implémenter `visite_pc/src/renderer/src/model.js`**

```js
// Convertit 'dd/MM/yyyy' en Date (pour comparer/trier).
function parseFr(d) {
  const [j, m, a] = String(d).split('/').map(Number)
  return new Date(a, (m || 1) - 1, j || 1)
}

export function rames(lib) {
  const parRame = new Map()
  for (const v of lib.visites) {
    const e = parRame.get(v.rame) ?? { rame: v.rame, nbVisites: 0, derniereDate: v.dateVisite }
    e.nbVisites += 1
    if (parseFr(v.dateVisite) > parseFr(e.derniereDate)) e.derniereDate = v.dateVisite
    parRame.set(v.rame, e)
  }
  return [...parRame.values()].sort((a, b) => a.rame - b.rame)
}

export function visitesForRame(lib, rame) {
  const nbPhotos = (visiteId) => lib.photos.filter((p) => p.visiteId === visiteId).length
  return lib.visites
    .filter((v) => v.rame === rame)
    .map((v) => ({ ...v, nbPhotos: nbPhotos(v.id) }))
    .sort((a, b) => parseFr(b.dateVisite) - parseFr(a.dateVisite))
}

export function photosForVisite(lib, visiteId, filtre = {}) {
  let photos = lib.photos.filter((p) => p.visiteId === visiteId)
  if (filtre.traitee !== undefined) photos = photos.filter((p) => p.traitee === filtre.traitee)

  const parPlan = new Map()
  for (const p of photos) {
    if (!parPlan.has(p.plan)) parPlan.set(p.plan, new Map())
    const zones = parPlan.get(p.plan)
    if (!zones.has(p.zone)) zones.set(p.zone, [])
    zones.get(p.zone).push(p)
  }
  return [...parPlan.entries()].map(([plan, zones]) => ({
    plan,
    zones: [...zones.entries()].map(([zone, ps]) => ({ zone, photos: ps }))
  }))
}
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `cd visite_pc && npx vitest run test/model.test.js`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add visite_pc/src/renderer/src/model.js visite_pc/test/model.test.js
git commit -m "feat(pc): model.js (rames/visitesForRame/photosForVisite)"
```

---

### Task 8: IPC + preload — brancher le principal au renderer

Câblage Electron (non testé sous Vitest ; vérification manuelle en lançant l'app).

**Files:**
- Create: `visite_pc/src/main/ipc.js`
- Modify: `visite_pc/src/main/index.js` (appeler `registerIpc`, importer le dossier bibliothèque)
- Modify: `visite_pc/src/preload/index.js` (exposer l'API)

**Interfaces:**
- Consumes: `importZip`, `loadLibrary` (import.js/library.js), `photosDir`.
- Produces (exposé au renderer via `window.api`) :
  - `importDialog()` → ouvre un sélecteur de ZIP, importe, renvoie `{ visites, photos } | null` (null si annulé).
  - `getLibrary()` → `lib` courante.
  - `photoUrl(cheminRelatif)` → chaîne `file://…` absolue vers l'image dans la bibliothèque.

- [ ] **Step 1: Créer `visite_pc/src/main/ipc.js`**

```js
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
```

- [ ] **Step 2: Modifier `visite_pc/src/main/index.js`** — importer et enregistrer l'IPC avec le dossier bibliothèque (`userData`). Ajouter en tête :

```js
import { app, BrowserWindow } from 'electron'
import { join } from 'node:path'
import { registerIpc } from './ipc.js'
```

Et dans `app.whenReady().then(...)`, avant `createWindow()` :

```js
app.whenReady().then(() => {
  registerIpc(join(app.getPath('userData'), 'library'))
  createWindow()
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})
```

- [ ] **Step 3: Modifier `visite_pc/src/preload/index.js`** — exposer l'API :

```js
import { contextBridge, ipcRenderer } from 'electron'

contextBridge.exposeInMainWorld('api', {
  importDialog: () => ipcRenderer.invoke('import:dialog'),
  getLibrary: () => ipcRenderer.invoke('library:get'),
  photoUrl: (cheminRelatif) => ipcRenderer.invoke('photo:url', cheminRelatif)
})
```

- [ ] **Step 4: Vérification manuelle**

Run: `cd visite_pc && npm run dev`
Expected: la fenêtre s'ouvre sans erreur console (DevTools). L'API sera exercée en Task 9. Fermer la fenêtre.

- [ ] **Step 5: Commit**

```bash
git add visite_pc/src/main/ipc.js visite_pc/src/main/index.js visite_pc/src/preload/index.js
git commit -m "feat(pc): IPC import/library/photoUrl + preload"
```

---

### Task 9: UI React — Rames → Rame → Photos + visionneuse + filtres

Assemble le modèle (Task 7) et l'API (Task 8). Vérification manuelle en lançant l'app avec un vrai export.

**Files:**
- Modify: `visite_pc/src/renderer/src/App.jsx` (navigation + import + état bibliothèque)
- Create: `visite_pc/src/renderer/src/screens/RamesScreen.jsx`
- Create: `visite_pc/src/renderer/src/screens/RameScreen.jsx`
- Create: `visite_pc/src/renderer/src/screens/PhotosScreen.jsx`
- Create: `visite_pc/src/renderer/src/components/Lightbox.jsx`
- Create: `visite_pc/src/renderer/src/styles.css`

**Interfaces:**
- Consumes: `window.api` (Task 8), `rames`/`visitesForRame`/`photosForVisite` (Task 7).

- [ ] **Step 1: `visite_pc/src/renderer/src/App.jsx`** — état bibliothèque + navigation à 3 vues

```jsx
import React, { useEffect, useState } from 'react'
import RamesScreen from './screens/RamesScreen.jsx'
import RameScreen from './screens/RameScreen.jsx'
import './styles.css'

export default function App() {
  const [lib, setLib] = useState({ version: 1, visites: [], photos: [] })
  const [rame, setRame] = useState(null)
  const [message, setMessage] = useState('')

  async function refresh() {
    setLib(await window.api.getLibrary())
  }
  useEffect(() => { refresh() }, [])

  async function importer() {
    const res = await window.api.importDialog()
    if (res) {
      setMessage(`Import : ${res.visites} visite(s), ${res.photos} photo(s).`)
      await refresh()
    }
  }

  return (
    <div className="app">
      <header className="topbar">
        <strong>Visites — PC</strong>
        <button onClick={importer}>Importer un export</button>
        {message && <span className="message">{message}</span>}
      </header>
      {rame === null
        ? <RamesScreen lib={lib} onOpen={setRame} />
        : <RameScreen lib={lib} rame={rame} onBack={() => setRame(null)} />}
    </div>
  )
}
```

- [ ] **Step 2: `visite_pc/src/renderer/src/screens/RamesScreen.jsx`**

```jsx
import React from 'react'
import { rames } from '../model.js'

export default function RamesScreen({ lib, onOpen }) {
  const items = rames(lib)
  if (items.length === 0) {
    return <p className="vide">Aucune visite. Cliquez « Importer un export ».</p>
  }
  return (
    <div className="grille-rames">
      {items.map((r) => (
        <button key={r.rame} className="carte-rame" onClick={() => onOpen(r.rame)}>
          <div className="rame-num">Rame {r.rame}</div>
          <div className="rame-info">{r.nbVisites} visite(s)</div>
          <div className="rame-info">dernière : {r.derniereDate}</div>
        </button>
      ))}
    </div>
  )
}
```

- [ ] **Step 3: `visite_pc/src/renderer/src/screens/RameScreen.jsx`**

```jsx
import React, { useState } from 'react'
import { visitesForRame } from '../model.js'
import PhotosScreen from './PhotosScreen.jsx'

export default function RameScreen({ lib, rame, onBack }) {
  const [visiteId, setVisiteId] = useState(null)
  const visites = visitesForRame(lib, rame)

  if (visiteId) {
    return <PhotosScreen lib={lib} visiteId={visiteId} onBack={() => setVisiteId(null)} />
  }
  return (
    <div className="ecran">
      <button className="retour" onClick={onBack}>← Rames</button>
      <h2>Rame {rame}</h2>
      <ul className="liste-visites">
        {visites.map((v) => (
          <li key={v.id}>
            <button onClick={() => setVisiteId(v.id)}>
              {v.type} • {v.niveau} • {v.dateVisite} — {v.nbPhotos} photo(s)
            </button>
          </li>
        ))}
      </ul>
    </div>
  )
}
```

- [ ] **Step 4: `visite_pc/src/renderer/src/screens/PhotosScreen.jsx`**

```jsx
import React, { useState } from 'react'
import { photosForVisite } from '../model.js'
import Lightbox from '../components/Lightbox.jsx'

export default function PhotosScreen({ lib, visiteId, onBack }) {
  const [filtre, setFiltre] = useState('tous') // 'tous' | 'traitee' | 'non'
  const [apercu, setApercu] = useState(null)

  const f = filtre === 'tous' ? {} : { traitee: filtre === 'traitee' }
  const groups = photosForVisite(lib, visiteId, f)

  return (
    <div className="ecran">
      <button className="retour" onClick={onBack}>← Visites</button>
      <div className="filtres">
        <label>Traitée :</label>
        <select value={filtre} onChange={(e) => setFiltre(e.target.value)}>
          <option value="tous">Toutes</option>
          <option value="traitee">Traitées</option>
          <option value="non">Non traitées</option>
        </select>
      </div>
      {groups.map((g) => (
        <section key={g.plan}>
          <h3>{g.plan}</h3>
          {g.zones.map((z) => (
            <div key={z.zone} className="zone-bloc">
              <div className="zone-nom">{z.zone}</div>
              <div className="grille-photos">
                {z.photos.map((p) => (
                  <Vignette key={p.id} photo={p} onClick={() => setApercu(p)} />
                ))}
              </div>
            </div>
          ))}
        </section>
      ))}
      {apercu && <Lightbox photo={apercu} onClose={() => setApercu(null)} />}
    </div>
  )
}

function Vignette({ photo, onClick }) {
  const [url, setUrl] = useState(null)
  React.useEffect(() => { window.api.photoUrl(photo.chemin).then(setUrl) }, [photo.chemin])
  return (
    <button className="vignette" onClick={onClick} title={photo.datePrise}>
      {url && <img src={url} alt={photo.zone} />}
    </button>
  )
}
```

- [ ] **Step 5: `visite_pc/src/renderer/src/components/Lightbox.jsx`**

```jsx
import React, { useEffect, useState } from 'react'

export default function Lightbox({ photo, onClose }) {
  const [url, setUrl] = useState(null)
  useEffect(() => { window.api.photoUrl(photo.chemin).then(setUrl) }, [photo.chemin])
  useEffect(() => {
    const onKey = (e) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="lightbox" onClick={onClose}>
      {url && <img src={url} alt={photo.zone} onClick={(e) => e.stopPropagation()} />}
      <div className="lightbox-info">{photo.zone} — {photo.datePrise}</div>
    </div>
  )
}
```

- [ ] **Step 6: `visite_pc/src/renderer/src/styles.css`**

```css
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, sans-serif; }
.topbar { display: flex; align-items: center; gap: 12px; padding: 10px 16px; background: #1e293b; color: #fff; }
.topbar button { padding: 6px 12px; cursor: pointer; }
.message { font-size: 13px; opacity: .85; }
.ecran { padding: 16px; }
.retour { margin-bottom: 12px; cursor: pointer; }
.vide { padding: 40px; text-align: center; color: #64748b; }
.grille-rames { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 12px; padding: 16px; }
.carte-rame { padding: 16px; border: 1px solid #cbd5e1; border-radius: 8px; background: #fff; cursor: pointer; text-align: left; }
.rame-num { font-size: 18px; font-weight: bold; }
.rame-info { font-size: 12px; color: #64748b; }
.liste-visites { list-style: none; padding: 0; }
.liste-visites button { width: 100%; text-align: left; padding: 10px; margin-bottom: 6px; cursor: pointer; }
.filtres { margin-bottom: 12px; }
.zone-bloc { margin: 8px 0; }
.zone-nom { font-weight: 600; margin-bottom: 4px; }
.grille-photos { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 8px; }
.vignette { padding: 0; border: 1px solid #cbd5e1; cursor: pointer; background: #f1f5f9; aspect-ratio: 1; }
.vignette img { width: 100%; height: 100%; object-fit: cover; display: block; }
.lightbox { position: fixed; inset: 0; background: rgba(0,0,0,.85); display: flex; align-items: center; justify-content: center; flex-direction: column; }
.lightbox img { max-width: 90vw; max-height: 85vh; object-fit: contain; }
.lightbox-info { color: #fff; margin-top: 8px; }
```

- [ ] **Step 7: Vérification manuelle de bout en bout**

1. `cd visite_pc && npm run dev`.
2. Cliquer **« Importer un export »** et choisir un vrai ZIP produit par la tablette (généré après Task 1 déployée, donc avec les colonnes UUID).
3. Vérifier : une carte de rame apparaît → clic → liste des visites → clic → photos par plan/zone → clic sur une vignette → visionneuse plein écran (Échap pour fermer). Tester le filtre « Traitées / Non traitées ».
4. Ré-importer le même export : pas de doublon de visite.

- [ ] **Step 8: Commit**

```bash
git add visite_pc/src/renderer/
git commit -m "feat(pc): UI React rames -> visites -> photos + visionneuse + filtres"
```

---

## Notes d'exécution

- **Ordre** : Task 1 (export tablette) en premier — sans les colonnes UUID, l'import PC n'a pas d'identifiant fiable. Idéalement redéployer la tablette et régénérer un export avant la vérification manuelle de Task 9.
- **Tests** : Tasks 1, 3–7 sont en TDD (Vitest / flutter test). Tasks 2, 8, 9 (scaffold, IPC, UI Electron) se valident en **lançant l'app** (`npm run dev`) — la logique risquée est isolée dans des modules purs déjà testés.
- **Environnement** : Node.js + npm requis sur le PC (indépendant de l'environnement Flutter). Vérifier `node -v` (≥ 18) avant Task 2.
