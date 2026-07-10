# Suivi des visites de corrosion — Design

Date : 2026-07-10
Statut : validé (design) — implémentation par étapes

## Objectif

Transformer l'app (qui démarre directement sur les 20 plans, photos non séparées)
en un **système de suivi des visites de corrosion** : chaque rame a son propre dossier
de photos, on garde l'historique de toutes les visites, et on suit le traitement de
la corrosion point par point.

## Concepts métier

- **Rame** : identifiée par un **numéro** (entier). Persistante dans le temps.
- **Visite** : un dossier = une rame + un **type** + une **date**. Une même rame peut
  avoir **plusieurs visites** à des dates différentes (historique cumulé).
- **Type de visite** et plans affichés :
  | Type | Plans |
  |------|-------|
  | **MKBAM** | les 4 **motrices** (série 2N) |
  | **MKBDR** | les 16 **remorques** (série 2N) |
  | **MKBAR** | remorques d'une **autre série** — plans fournis plus tard (vide au départ) |
- **Point de corrosion** = une **photo**. Chaque photo porte un statut **traité / non traité**.

## Modèle de données (SQLite — migration v1 → v2)

Existant : `plans` → `zones` → `photos` (photo rattachée à `zone_id`).

Ajouts :
- Nouvelle table **`visites`** : `id` (TEXT PK), `numero_rame` (INTEGER), `type_visite`
  (TEXT : MKBAM/MKBDR/MKBAR), `date_visite` (INTEGER), `date_creation` (INTEGER).
- Table **`plans`** : ajouter `categorie` (TEXT : motrice/remorque) et `serie` (TEXT : ex "2N").
  Renseignés dans le seed `zones.json`.
- Table **`photos`** : ajouter `visite_id` (TEXT, FK → visites, ON DELETE CASCADE) et
  `traitee` (INTEGER 0/1, défaut 0).
- Les **plans et zones restent partagés** (référentiel commun à toutes les rames) ;
  seules les **photos** sont isolées par visite.

Filtrage des plans par type : MKBAM → `categorie = motrice` ; MKBDR → `categorie = remorque
AND serie = '2N'` ; MKBAR → `categorie = remorque AND serie = '<autre>'`.

## Parcours à l'écran

1. **Page d'accueil** (nouveau, écran de démarrage) : image de TGV (placeholder pour
   l'instant), titre « Visite corrosion », bouton **« Nouvelle visite »**, et **liste des
   visites existantes** (n° rame + type + date) triées par date, regroupables par rame,
   pour rouvrir/consulter.
2. **Nouvelle visite** : choix du **type** (MKBAM/MKBDR/MKBAR) + saisie du **numéro de rame**
   (clavier numérique) → création de la visite → entrée dans la visite.
3. **Liste des plans filtrés** selon le type (écran `PlansScreen` existant, filtré + rattaché
   à la visite active).
4. **Plan → zones → photos** (écrans existants), mais les photos sont **créées et lues dans le
   contexte de la visite active**, et chaque photo peut être basculée **traité / non traité**.
5. **Rouvrir une visite** depuis l'accueil → consulter/compléter ses photos.

La **visite active** est passée aux écrans lors de la navigation (l'app utilise déjà `provider`
pour `AppContext`).

## Découpage en étapes (implémentation incrémentale)

- **Étape 1 — Fondations données + page d'accueil**
  Migration DB v2 (table `visites`, colonnes `photos.visite_id`/`traitee`,
  `plans.categorie`/`serie`) + seed enrichi (catégorie/série sur les 20 plans) +
  modèle/repo `Visite` + page d'accueil (image TGV placeholder, « Visite corrosion »,
  « Nouvelle visite », liste des visites) + création de visite (type + n° rame).
- **Étape 2 — Plans filtrés + isolation des photos par visite**
  `PlansScreen` filtré selon le type ; photos créées/lues avec `visite_id`.
- **Étape 3 — Statut « traité »**
  UI pour basculer traité/non traité sur chaque photo ; indicateur visible.
- **Étape 4 — Historique par rame**
  Regroupement/consultation des visites d'une même rame.
- **Plus tard** : plans MKBAR (autre série), image d'accueil définitive, intégration au
  rapport PDF (n° rame, type, date, points traités/non traités).

## Points ouverts / à fournir

- **Image d'accueil** : placeholder TGV pour l'instant ; image définitive fournie plus tard.
- **Plans MKBAR** : dessins des remorques de l'autre série à fournir.
- Compatibilité : l'APK déjà installé a une base v1 → la migration v2 doit préserver
  d'éventuelles données (ou re-seed si base vide).
