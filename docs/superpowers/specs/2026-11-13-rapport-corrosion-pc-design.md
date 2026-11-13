# Rapport de corrosion dans l'appli PC — conception

Date : 2026-11-13 — Statut : validé sur maquette par Franck (maquette PDF 4 pages,
« ça me convient, on peut partir là-dessus »).

## Intention

Une fois les photos d'une visite importées dans l'appli PC (`visite_pc/`), Franck
veut **chiffrer chaque point de corrosion** (gravité, temps estimé, commentaire)
puis **générer un rapport PDF professionnel**.

Le rapport a deux lecteurs :
- **l'atelier**, qui fait les réparations : il doit savoir *où* intervenir
  (rame, voiture, point précis) et *quoi* faire (photos + constat) ;
- **le service de programmation**, qui décide *quand* arrêter la rame et *pour
  combien de temps* : il veut une vue d'ensemble (nombre de points, heures
  totales, répartition par gravité).

C'est **Franck qui estime** le temps de réparation et la gravité.

## Objectifs

1. Saisir, par **point** (zone) d'une visite : gravité, temps estimé, commentaire,
   et la case « Dans le rapport ». Optionnellement une légende par photo.
2. Générer un rapport **par rame**, en choisissant les visites à inclure
   (par défaut : celles de la même date que la plus récente ; une seule visite
   cochée = rapport séparé).
3. Produire un PDF fidèle à la maquette validée (voir « Mise en page »).
4. Ne jamais perdre la saisie lors d'une réimportation de la même visite.

## Non-objectifs

- Pas de saisie gravité/temps sur la tablette (tout se fait sur PC).
- Pas de format Word, pas de logo, pas de case visa/signature (en-tête sobre,
  validé : « pas de format habituel »).
- Pas de renvoi des commentaires vers la tablette.
- Pas d'envoi par mail intégré : Franck enregistre le PDF et l'envoie lui-même.

## Anti-objectifs (échec même si « ça marche »)

- Une réimportation qui efface gravité/temps/commentaires.
- Un rapport qui mélange des visites de dates différentes sans que Franck
  l'ait choisi.
- Une photo ou une fiche de point coupée entre deux pages.

## Contraintes / existant

- Appli PC : Electron + electron-vite + React 18, tests vitest. Bibliothèque
  locale `library.json` (`{version:1, visites[], photos[]}`) + `photos/<visiteId>/<photoId>.jpg`
  (`src/main/library.js`, `src/main/import.js`).
- L'import **remplace** entièrement une visite réimportée (`upsertLibrary`) :
  d'où le stockage des saisies **à part** des photos.
- Données disponibles par photo (colonnes `data.xlsx` de l'export tablette,
  `tab_visite/lib/services/export_service.dart`) : Rame, Type, Niveau, Date visite,
  Plan (nom du dessin, ex. « Remorque (Droit-Pair) R1 »), Zone (ex. « R1 D1 »),
  Date prise, Traitée, Chemin photo, Visite ID, Photo ID (UUID stables).
- Un « point » = couple **(Visite ID, Plan, Zone)**. Les noms de zone sont uniques
  au sein d'un dessin.
- L'export tablette **ne contient pas** aujourd'hui les dessins ni la position des
  points : nécessaire pour la localisation (voir Partie B).
- Livrable PC = installeur `dist/visite-pc-*-setup.exe` (electron-builder, config
  `electron-builder.yml` non encore commitée — à commiter).

## Approches considérées (choix de fabrication du PDF)

- **A. Mise en page HTML/CSS + `webContents.printToPDF` d'Electron** — CHOISIE par
  Franck. Rendu soigné facilement, aucune nouvelle dépendance, en-tête/pied de page
  natifs (« Page X / Y »), aperçu possible. Sauts de page gérés en CSS
  (`break-inside: avoid`). La maquette a été produite avec ce même moteur
  (Chromium `page.pdf`), donc le rendu est déjà validé.
- B. PDF dessiné élément par élément (pdfkit/pdf-lib) : contrôle au millimètre
  mais beaucoup plus de code ; écartée.
- C. Document Word : modifiable mais rendu variable et moins « fini » ; écartée.

## Décisions de Franck

- Rapport pour l'atelier **et** la programmation.
- Gravité + temps **par point**, estimés par Franck.
- Seuls les points avec gravité **et** temps vont dans le rapport, **plus** une case
  pour ajouter/retirer un point manuellement.
- Rapport **par rame** avec choix des visites (rapport séparé possible si visites
  à des dates différentes).
- En-tête sobre, pas de format imposé.
- Maquette validée telle quelle (y compris la **localisation** sur le dessin).

## Partie A — Saisie dans l'appli PC

### Données (library.json, version 2)

Ajouter, sans toucher à `visites`/`photos` :

```json
{
  "version": 2,
  "visites": [...], "photos": [...],
  "points": [
    { "visiteId": "…", "plan": "Remorque (Droit-Pair) R1", "zone": "R1 D1",
      "gravite": "critique" | "moyenne" | "mineure" | null,
      "tempsH": 1.5 | null,
      "commentaire": "…",
      "inclusion": "auto" | "oui" | "non" }
  ],
  "legendes": { "<photoId>": "vue rapprochée angle haut droit" },
  "reglages": { "redacteur": "Franck", "dernierNumero": { "RC-123-20261114": 1 } }
}
```

- Migration v1 → v2 au chargement : ajoute `points: []`, `legendes: {}`,
  `reglages: {}`.
- `upsertLibrary` ne touche **jamais** `points`, `legendes`, `reglages`.
  Un point dont la zone n'a plus de photo après réimport est conservé (orphelin),
  simplement non affiché.
- **Inclusion effective** : `oui` → inclus ; `non` → exclu ; `auto` → inclus si
  `gravite != null && tempsH != null`. Cocher/décocher la case passe en `oui`/`non` ;
  un point jamais touché reste `auto`.
- Un point inclus sans temps apparaît dans le rapport avec « — » et ne compte pas
  dans le total ; sans gravité, badge gris « Non évaluée ».
- Temps : nombre ≥ 0 par pas de 0,5 h, affiché avec virgule (`1,5 h`).

### Écran (dans l'écran photos d'une visite existant, `PhotosScreen.jsx`)

Pour chaque zone (bloc existant `zone-bloc`) :

```
┌ R1 D1 ────────────────────────────────── [x] Dans le rapport ┐
│ [photo] [photo]   (légende optionnelle sous chaque photo)    │
│ Gravité : (Mineure) (Moyenne) (Critique)   Temps : [ 1,5 ] h │
│ Commentaire : [ zone de texte multi-lignes               ]   │
└──────────────────────────────────────────────────────────────┘
```

- Enregistrement automatique à chaque modification (pas de bouton Enregistrer),
  via IPC vers le processus principal qui écrit `library.json`.
- En haut de l'écran : compteur « N points dans le rapport — X,X h ».
- Le filtre existant « Traitée » reste.

## Partie B — Localisation : ajout à l'export tablette

Dans `export_service.dart` (export d'une visite **et** export global) :
- ajouter au ZIP l'image de chaque dessin utilisé : `dessins/<plan sûr>.png`
  (octets via `PhotoStore.readBytes(plan.cheminImage)`) ;
- ajouter à `data.xlsx` les colonnes **après** les existantes :
  `Fichier dessin`, `Zone X`, `Zone Y`, `Zone largeur`, `Zone hauteur`
  (coordonnées normalisées 0–1 de la zone, comme en base, points décimaux).

Côté PC, l'import copie les dessins dans `dessins/<visiteId>/<plan sûr>.png` et
stocke sur chaque photo `dessin` + `zoneRect`. **Rétrocompatible** : un ZIP
ancien (sans ces colonnes) s'importe comme avant ; le rapport affiche alors la
fiche **sans** bloc « Localisation ».

La localisation dans le rapport = le dessin entier, hauteur ~24 mm, avec une
**ellipse rouge** autour du rectangle de la zone (marge comme la maquette),
dessinée en SVG superposé (pas de retouche d'image).

## Partie C — Génération du rapport

### Écran « Rapport » (depuis l'écran d'une rame, bouton « Créer un rapport »)

```
Rapport — Rame 123
 [x] MKBAM  2N  13/11/2026   8 points   11,0 h
 [x] MKBDR  2N  13/11/2026   5 points    6,5 h
 [ ] MKBDR  2N  02/10/2026   3 points    4,0 h
 Rédigé par : [ Franck ]           Total : 13 points  17,5 h
 [ Aperçu ]  [ Enregistrer le PDF… ]
```

- Coche par défaut : les visites dont `dateVisite` = la plus récente de la rame.
- « Rédigé par » prérempli avec `reglages.redacteur`, mémorisé à la génération.
- Aperçu : fenêtre Electron affichant le rapport HTML.
- Enregistrer : boîte « Enregistrer sous » (nom par défaut
  `Rapport corrosion - Rame 123 - 2026-11-14.pdf`), puis ouverture du PDF.
- Bouton désactivé si 0 point inclus (message explicatif).

### Contenu et mise en page (= maquette validée)

Référence visuelle : `docs/superpowers/specs/2026-11-13-rapport-maquette/` (`rapport.html`
+ images + PDF rendu), à reprendre comme gabarit de départ, sans le filigrane « MAQUETTE ». A4 portrait, marges
14/14/18/14 mm, police système sans-serif, palette bleu marine `#1f3a5f`,
gravités : critique `#c62828`, moyenne `#e67e00`, mineure `#2e7d32`.

1. **En-tête** : « Rapport de visite corrosion » / « Constats et travaux à
   prévoir » ; à droite « Rame » + numéro en gros + niveau(x).
2. **Bandeau infos** : N° de rapport, Date(s) de visite, Rédigé par, Édité le.
3. **Visites incluses** : Type, Périmètre (MKBAM → Motrices, MKBDR → Remorques,
   MKBAR → Remorques (autre série)), Niveau, Date, Points, Temps.
4. **Synthèse** : Points à traiter, Temps total estimé, Répartition par gravité
   (badges « n critiques · x h » etc.).
5. **Récapitulatif** : N°, Point, Voiture/dessin, Gravité, Temps, Constat
   (extrait ~60 caractères + « … »), ligne Total.
6. **Détail des points** (nouvelle page) : une fiche par point, `break-inside: avoid`,
   ~2 fiches par page : barre de titre (n°, point, dessin · visite, badge gravité,
   temps), Localisation, Photos (grille 2 colonnes, hauteur 47 mm, `object-fit: cover`,
   date/heure + légende), « Constat et travaux à prévoir » bordé de la couleur.
7. Ligne finale « Rédigé par X, le JJ/MM/AAAA ».
8. **Pied de page** (template printToPDF) : « Rapport <n°> · Rame <n> » à gauche,
   « Page X / Y » à droite.

**Ordre des points** (récap et détail, même numérotation) : gravité décroissante
(critique, moyenne, mineure, non évaluée), puis motrices avant remorques (ordre
des visites MKBAM, MKBDR, MKBAR), puis ordre d'apparition dans l'export (qui
suit l'ordre des dessins sur la tablette), puis nom de zone.

**Numéro de rapport** : `RC-<rame>-<AAAAMMJJ du jour d'édition>`, suffixe `-2`,
`-3`… si plusieurs rapports sont édités le même jour pour la même rame (compteur
dans `reglages.dernierNumero`).

**Photos** : toutes les photos du point incluses (pas de sélection en V1).

## Laissé au builder

- Découpage en composants React / styles de l'écran de saisie.
- Mécanique exacte de rendu (HTML généré côté main en chaîne vs page React dédiée
  chargée dans une `BrowserWindow` cachée), tant que le rendu suit la maquette.
- Gestion des images dans le PDF (`file://` vers la bibliothèque).
- Fréquence d'écriture de `library.json` (débounce raisonnable).

## Vérification attendue

- Tests vitest : migration v1→v2, `upsertLibrary` préserve `points`/`legendes`,
  inclusion effective, totaux/tri/numérotation, import ZIP ancien et nouveau.
- Test Dart côté tablette : export contient `dessins/…` et les nouvelles colonnes.
- Rendu : générer un PDF sur données d'exemple et contrôler visuellement
  (2 fiches/page, rien de coupé, pied de page).
- Test de bout en bout par Franck : export tablette perso → import PC → saisie
  → PDF.
