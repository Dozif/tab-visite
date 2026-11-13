# Rapport de corrosion (appli PC) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Saisir gravité/temps/commentaire par point dans l'appli PC et générer un rapport PDF par rame, fidèle à la maquette validée.

**Architecture:** Côté tablette, l'export ajoute les dessins et la position des points. Côté PC, `library.json` passe en v2 (`points`, `legendes`, `reglages`, préservés à l'import) ; un module pur `src/shared/rapport.js` calcule le modèle du rapport ; `src/main/rapportHtml.js` le rend en HTML (gabarit = maquette) ; le main l'imprime en PDF via `webContents.printToPDF`.

**Tech Stack:** Flutter/Dart (export tablette), Electron 33 + electron-vite + React 18 + vitest (PC).

**Spec:** `docs/superpowers/specs/2026-11-13-rapport-corrosion-pc-design.md` (+ maquette `docs/superpowers/specs/2026-11-13-rapport-maquette/`).

## Global Constraints

- Gravités : `critique` `#c62828`, `moyenne` `#e67e00`, `mineure` `#2e7d32` ; non évaluée = gris `#7a8594`. Bleu `#1f3a5f`.
- Temps ≥ 0 par pas de 0,5 h ; affichage `1,5 h` (virgule, 1 décimale).
- Inclusion : `oui` → inclus ; `non` → exclu ; `auto` → inclus si gravité ET temps renseignés.
- Numéro : `RC-<rame>-<AAAAMMJJ édition>`, puis `-2`, `-3`… le même jour pour la même rame.
- Ordre des points : gravité (critique, moyenne, mineure, non évaluée), puis type de visite (MKBAM, MKBDR, MKBAR), puis ordre d'apparition dans l'export, puis nom de zone.
- Rétrocompatibilité : un ZIP sans colonnes de dessin s'importe ; fiche sans « Localisation ».
- Un réimport ne touche jamais `points`, `legendes`, `reglages`.
- A4 portrait, marges 14/14/18/14 mm, pied de page « Rapport <n°> · Rame <n> » / « Page X / Y ».

## Review Focus

1. Réimport d'une visite déjà annotée → les saisies restent (test T2).
2. Ancien ZIP (11 colonnes) → import OK, rapport sans localisation (tests T2, T4).
3. Commentaire avec `<`, `&`, guillemets, retours à la ligne → échappé, retours conservés (test T4).
4. Point inclus sans temps / sans gravité → « — » / « Non évaluée », hors total (test T3).
5. Aucune visite cochée ou 0 point inclus → génération impossible avec message (test T3 + UI T5).

---

### Task 1: Export tablette — dessins et position des points

**Files:** Modify `tab_visite/lib/data/repositories/photo_repository.dart` (2 requêtes), `tab_visite/lib/services/export_service.dart`; Test `tab_visite/test/export_service_test.dart`.

**Interfaces — Produces:** ZIP contient `dessins/<planId><ext>` (ext de `chemin_image`, défaut `.png`) une fois par dessin ; `data.xlsx` a 16 colonnes : les 11 actuelles + `Fichier dessin`, `Zone X`, `Zone Y`, `Zone largeur`, `Zone hauteur` (nombres en texte avec point décimal).

- [ ] Test : dans `exportVisiteToZip`, attendre 16 colonnes, une entrée `dessins/p1.png` (créer le fichier `plans/p.png` dans le store), et la ligne photo avec `dessins/p1.png`, `0.0`/`0.1` pour la zone. Idem pour `exportAllVisitesToZip` (un seul dessin même si 2 photos du même plan).
- [ ] Lancer `flutter test test/export_service_test.dart` → échec.
- [ ] Ajouter `pl.id AS plan_id, pl.chemin_image, z.x, z.y, z.largeur, z.hauteur` aux deux requêtes ; ajouter les entêtes ; `_addDessin(archive, planId, cheminImage, déjàAjoutés)` ; dessin manquant → colonne vide.
- [ ] Tests verts (fichier + suite complète) → commit `feat(tab_visite): export des dessins et positions des points`.

### Task 2: PC — bibliothèque v2 et import des dessins

**Files:** Modify `visite_pc/src/main/library.js`, `visite_pc/src/main/import.js`; Test `visite_pc/test/library.test.js`, `test/upsert.test.js`, `test/importZip.test.js`, `test/parse.test.js`.

**Interfaces — Produces:**
- `migrateLibrary(lib) -> lib` (v1→v2 : `version:2, points:[], legendes:{}, reglages:{}`) ; `loadLibrary` l'applique.
- `parseDataXlsx` ajoute `fichierDessin` (string, '' si absent) et `zoneRect` (`{x,y,l,h}` ou `null`).
- Photos de la bibliothèque : `dessin` (`dessins/<visiteId>/<basename>` ou `null`), `zoneRect`, `ordre` (index de la ligne dans l'import).
- `upsertLibrary` conserve `points`, `legendes`, `reglages` tels quels.

- [ ] Tests : migration v1 → v2 ; upsert d'une lib avec `points`/`legendes`/`reglages` les conserve après réimport de la même visite ; parse d'une ligne à 16 colonnes ; `importZip` avec dessin → fichier copié dans `dessins/v1/p1.png` et photo `dessin`/`zoneRect` renseignés ; ancien ZIP → `dessin: null`.
- [ ] `npx vitest run` → échecs attendus.
- [ ] Implémenter ; `rmSync` du dossier `dessins/<visiteId>` au réimport.
- [ ] Tests verts → commit `feat(pc): bibliothèque v2 et import des dessins`.

### Task 3: PC — modèle du rapport (module pur)

**Files:** Create `visite_pc/src/shared/rapport.js`; Test `visite_pc/test/rapport.test.js`.

**Interfaces — Produces:**
- `GRAVITES = ['critique','moyenne','mineure']` ; `PERIMETRE = {MKBAM:'Motrices', MKBDR:'Remorques', MKBAR:'Remorques (autre série)'}`.
- `findPoint(lib, visiteId, plan, zone) -> point|null` ; `setPoint(lib, {visiteId, plan, zone, ...patch}) -> lib` (crée avec défauts `gravite:null, tempsH:null, commentaire:'', inclusion:'auto'`).
- `estInclus(point) -> bool`.
- `pointsDeVisite(lib, visiteId) -> [{plan, zone, photos[], point}]` (ordre = `ordre` des photos).
- `resumeVisite(lib, visiteId) -> {nbPoints, heures}` (points inclus).
- `visitesParDefaut(lib, rame) -> visiteIds[]` (même `dateVisite` que la plus récente).
- `numeroRapport(reglages, rame, date: Date) -> {numero, reglages}`.
- `buildRapport(lib, {rame, visiteIds, redacteur, dateEdition: Date, numero}) -> {numero, rame, niveaux, datesVisite, redacteur, editeLe, visites:[{type, perimetre, niveau, dateVisite, nbPoints, heures}], synthese:{nbPoints, heures, parGravite:{critique:{n,h},…}}, points:[{n, zone, plan, typeVisite, gravite, tempsH, commentaire, photos:[{chemin, datePrise, legende}], dessin, zoneRect}]}` ; lève `Error('Aucun point à inclure')` si 0 point.
- `formatHeures(h) -> '1,5 h'` (null → '—').

- [ ] Tests : inclusion (3 modes) ; tri (critique avant moyenne ; MKBAM avant MKBDR à gravité égale) ; numérotation 1..n ; totaux qui ignorent les points sans temps ; numéro `RC-123-20261114` puis `RC-123-20261114-2` ; défaut des visites = même date que la plus récente ; erreur si 0 point ; `formatHeures(1.5) === '1,5 h'`, `formatHeures(12) === '12,0 h'`.
- [ ] Échec → implémenter → vert → commit `feat(pc): modèle du rapport de corrosion`.

### Task 4: PC — rendu HTML et génération PDF

**Files:** Create `visite_pc/src/main/rapportHtml.js`, `visite_pc/src/main/rapportPdf.js`; Modify `visite_pc/src/main/ipc.js`, `visite_pc/src/preload/index.js`; Test `visite_pc/test/rapportHtml.test.js`.

**Interfaces:**
- Consumes : `buildRapport`, `numeroRapport`, `formatHeures`, `PERIMETRE` (T3).
- Produces : `renderRapportHtml(rapport, fileUrl: (chemin)=>string) -> string` ; `footerTemplate(rapport) -> string` ; `genererPdf(html, footer, outPath)` et `ouvrirApercu(html)` (BrowserWindow, fichier HTML temporaire dans `<libraryDir>/tmp/`) ; IPC `point:set`, `legende:set`, `reglages:set`, `rapport:apercu`, `rapport:pdf` ; preload `setPoint`, `setLegende`, `setReglages`, `rapportApercu({rame, visiteIds, redacteur})`, `rapportPdf({…}) -> {chemin}|null`.

- [ ] Tests : HTML contient le n°, « 12,0 h », un badge par gravité, autant de `class="point"` que de points ; commentaire `<b>&"x"</b>\nligne2` échappé avec `<br>` ; pas de bloc localisation si `dessin` null ; ellipse SVG positionnée depuis `zoneRect` sinon ; aucune occurrence de « MAQUETTE ».
- [ ] Implémenter en reprenant le CSS de la maquette (sans filigrane). Localisation : `<div class="loc">` avec `<img>` + `<svg viewBox="0 0 1 1" preserveAspectRatio="none">` ellipse rouge autour du rect (marge 0.012 en x, 0.024 en y), conteneur au ratio de l'image (attente du chargement via `aspect-ratio` calculé en JS inline sur `onload`).
- [ ] PDF : `printToPDF({ pageSize:'A4', printBackground:true, preferCSSPageSize:true, displayHeaderFooter:true, headerTemplate:'<span></span>', footerTemplate })` ; `rapport:pdf` = boîte « Enregistrer sous » (nom `Rapport corrosion - Rame <n> - <AAAA-MM-JJ>.pdf`), écrit, `shell.openPath`, mémorise `redacteur` et le compteur de numéro.
- [ ] Tests verts → commit `feat(pc): rendu HTML et génération PDF du rapport`.

### Task 5: PC — écrans de saisie et de rapport

**Files:** Create `visite_pc/src/renderer/src/components/PointEditor.jsx`, `visite_pc/src/renderer/src/screens/RapportScreen.jsx`; Modify `PhotosScreen.jsx`, `RameScreen.jsx`, `App.jsx`, `styles.css`.

**Interfaces — Consumes:** preload T4, `pointsDeVisite`, `resumeVisite`, `estInclus`, `visitesParDefaut`, `formatHeures` (T3).

- [ ] `PhotosScreen` : chaque zone affiche `PointEditor` (gravité 3 boutons bascule, temps `input type=number step=0.5 min=0`, commentaire `textarea` enregistré en debounce 500 ms et au blur, case « Dans le rapport » reflétant `estInclus`), légende sous chaque photo ; compteur « N points dans le rapport — X h ». Chaque appel IPC renvoie la lib → `onLib(lib)` remonte à `App`.
- [ ] `RameScreen` : bouton « Créer un rapport » → `RapportScreen` (cases visites + points/heures, « Rédigé par », total, boutons « Aperçu » / « Enregistrer le PDF… » désactivés avec message si 0 point).
- [ ] `npm run build` OK ; contrôle manuel en lançant l'appli.
- [ ] Commit `feat(pc): saisie des points et écran de rapport`.

### Task 6: Vérification de bout en bout et installeur

- [ ] Données de test : ZIP au nouveau format (2 visites même rame/date, photos réelles d'exemple), import dans une bibliothèque temporaire, saisie via IPC, PDF généré par l'appli (Electron) → contrôle visuel des pages.
- [ ] `npm run dist:win` → installeur à jour.
- [ ] Relecture indépendante de la branche, corrections, PR.
