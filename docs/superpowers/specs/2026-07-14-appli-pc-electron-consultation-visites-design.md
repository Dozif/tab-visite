# Design — Appli PC (Electron) de consultation/archivage des visites

**Date :** 2026-07-14
**Statut :** validé (design), à implémenter
**Phase :** phase 2 du besoin « exporter les visites vers le PC » (la phase 1 = export tablette, faite : commit `3e2a8cf`).

## Contexte

L'app tablette Flutter (`tab_visite/`) produit des **ZIP d'export** de visites de corrosion :
`data.xlsx` (récap, 1 ligne/photo) + `photos/…`. Franck veut une **application PC dédiée**
pour **importer ces exports, tout garder en mémoire et consulter** l'ensemble des visites,
afin de retravailler et suivre l'état des rames sur le PC.

Décisions cadrées (brainstorming) :
- **Rôle** : consulter / archiver uniquement. **Hors périmètre** : annotation, modification
  des données, génération de rapports/PDF (extensions possibles plus tard).
- **Archive** : **bibliothèque locale persistante** qui s'accumule (chaque import s'ajoute,
  tout reste consultable au lancement suivant).
- **Navigation** : **par rame d'abord** (choisir une rame → voir ses visites/photos dans le
  temps).
- **Ré-import** : **mettre à jour** la visite (dédoublonnage), pas de doublon.
- **Techno** : **Electron + React** (choix de Franck), lancée en **mode dev** pour l'instant
  (packaging `.exe` remis à plus tard).

## Périmètre & emplacement

Nouveau projet dans un dossier **`visite_pc/`** du dépôt actuel (monorepo, à côté de
`tab_visite/`). 100 % hors-ligne. Stack : **Electron + React + Vite**, JavaScript.

## Architecture

Deux process, communication par **IPC** (le renderer n'accède jamais au disque directement) :

- **Process principal (Node)** — responsabilités :
  - Dialogue d'ouverture de fichier (sélection du ZIP).
  - **Décompression** du ZIP (dép `adm-zip` ou `yauzl`).
  - **Lecture du `data.xlsx`** via **SheetJS (`xlsx`)**.
  - Gestion de la **bibliothèque locale** : dossier `app.getPath('userData')` (≈
    `%APPDATA%/visite-pc/`) contenant `library.json` (index) + `photos/` (images copiées).
  - Upsert des visites, copie des photos, exposition des chemins d'images au renderer.
  - Canaux IPC : `import:zip` (→ résumé de l'import), `library:list` (→ rames + visites),
    `library:visite` (→ photos d'une visite), `photo:url` (→ chemin absolu/`file://` d'une photo).

- **Renderer (React + Vite)** — toute l'UI (voir § UI). Appelle le principal via
  `contextBridge`/`ipcRenderer` exposé par un **preload** sécurisé (`contextIsolation: true`,
  `nodeIntegration: false`).

Chaque unité a une responsabilité claire : `main/import.js` (extraction + parse + upsert),
`main/library.js` (lecture/écriture de `library.json` + dossier photos), `main/ipc.js`
(câblage des canaux), `renderer/` (composants React par écran).

## Stockage local — approche retenue

**Index JSON + dossier photos** (approche A). `library.json` contient les métadonnées
(légères) ; les images sont des fichiers dans `photos/`. Zéro dépendance native, suffisant
pour un archivage de visites. *(Alternative écartée pour l'instant : SQLite/`better-sqlite3`
— module natif à recompiler pour Electron, utile seulement à très gros volume.)*

### Modèle `library.json`
```json
{
  "version": 1,
  "visites": [
    { "id": "<uuid>", "rame": 3, "type": "MKBDR", "niveau": "2N",
      "dateVisite": "2026-07-14", "importeLe": "<iso>" }
  ],
  "photos": [
    { "id": "<uuid>", "visiteId": "<uuid>", "plan": "Remorque R3",
      "zone": "R3 D1", "datePrise": "14/07/2026 10:22", "traitee": false,
      "chemin": "photos/<visiteId>/<id>.jpg" }
  ]
}
```
Clé d'identité de la photo = `id` (UUID de la tablette, présent dans `data.xlsx`) ; clé de la
visite = **Visite ID** (voir ci-dessous).

## Ajustement de l'export tablette (prérequis au dédoublonnage)

Le `data.xlsx` actuel n'expose pas d'identifiant de visite ni de photo stable. On **ajoute
deux colonnes** au récap produit par `ExportService` (Flutter, `tab_visite/`) :
- **`Visite ID`** = `visite.id` (UUID déjà en base).
- **`Photo ID`** = `photo.id` (UUID déjà en base).

Ces UUID permettent l'upsert fiable côté PC (mise à jour d'une visite, pas de doublon de
photo). Changement localisé : `_entetes` + les deux `data.add([...])` de
`exportVisiteToZip`/`exportAllVisitesToZip`, plus les requêtes `joinedForVisite`/
`joinedAllByVisite` (déjà `SELECT ph.id …` ; ajouter `vi.id`). Tests export mis à jour.
Commité et déployé côté tablette avant/pendant la phase 2.

## Flux d'import

1. L'utilisateur clique **« Importer un export »** → sélectionne un ZIP.
2. Process principal : extraction en zone temporaire → parse `data.xlsx` (SheetJS) en lignes.
3. **Upsert** : regrouper les lignes par `Visite ID`. Pour chaque visite :
   - si `Visite ID` déjà dans `library.json` → **supprimer ses anciennes photos** (fichiers +
     entrées) puis ré-insérer (remplacement) ;
   - sinon → l'ajouter.
   - Copier chaque image du ZIP (`Chemin photo`) vers `photos/<visiteId>/<photoId>.jpg`.
4. Sauver `library.json`, renvoyer un résumé (`n visites, m photos importées`).
5. Le renderer rafraîchit la liste.

Un ZIP **global** (plusieurs visites) est traité pareil (les lignes portent chacune leur
`Visite ID`). Les images manquantes/illisibles sont ignorées avec un décompte signalé (pas
de silence).

## UI (rame d'abord)

> **Précision de vocabulaire** : une **« rame » = le numéro de train** (`numeroRame`,
> colonne `Rame` du récap). Les **R1…R8 / M1 / M2 sont les véhicules** de cette rame (portés
> par le nom de plan, ex. « Remorque R3 », « Motrice 1N M1 »), niveau intermédiaire sous la
> rame. La navigation « par rame d'abord » = par **numéro de rame**.

- **Écran Rames** : cartes des **numéros de rame** présents dans la bibliothèque, avec nb de
  visites et date de la dernière. Bouton **« Importer un export »** en tête, toujours visible.
- **Écran Rame** : ses visites triées par date (type, niveau, date, nb photos), et accès aux
  photos regroupées par **véhicule (plan) → zone**.
- **Écran Photos / visionneuse** : grille des vignettes d'une zone/plan ; clic → **visionneuse
  plein écran** avec zoom et navigation précédent/suivant. **Filtres simples** (type, niveau,
  date, traitée/non).

## Tests

- **Parseur d'import** : à partir d'un `data.xlsx` d'exemple (généré à la main dans le test),
  vérifier le nombre de lignes et le mapping des colonnes.
- **Upsert/dédoublonnage** : importer deux fois la même visite (même `Visite ID`, photos
  différentes) → une seule visite, photos remplacées (pas de doublon). Importer une seconde
  visite distincte → deux visites.
- Framework : **Vitest** (léger, s'intègre à Vite) sur la logique du process principal
  (`import.js`, `library.js`), sans lancer Electron.

## Hors périmètre (à ce stade)

Annotation/édition des visites, marquage « traité » depuis le PC, génération de rapports
PDF/Excel, packaging `.exe` (electron-builder), synchronisation réseau, multi-poste.
Le format d'export (ZIP + `data.xlsx` + colonnes UUID) reste le **contrat** ; ces extensions
viendront comme phases ultérieures sans le casser.
