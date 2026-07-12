# Points de corrosion des remorques R1→R8 — Design

Date : 2026-07-12
Statut : validé (design) — implémentation par étapes (gabarit R2 d'abord)

## Objectif

Peupler les points de corrosion des **16 plans de remorques** (R1→R8, deux côtés
chacun : Droit-Pair / Gauche-Impair) dans le seed `assets/seed/zones.json`, à partir
de la disposition de référence dessinée par l'utilisateur dans `R2.xlsx` / `R2.png`.

Aujourd'hui seul **R1 Droit-Pair** contient des zones (8 points numérotés 1→8) ;
tous les autres plans de remorques sont vides.

## Rappel du pipeline (pour situer le travail)

- La donnée réelle de l'app est **`assets/seed/zones.json`** (chargé une fois en SQLite
  au premier lancement). Les fichiers Excel `R*.xlsx` à la racine du dépôt ne sont
  **pas lus par l'app** : ce sont des supports visuels de saisie.
- Une **zone** (= un point de corrosion) est stockée avec : `nom`, `x`, `y`, `largeur`,
  `hauteur` (coordonnées **normalisées 0→1** relatives à l'image du plan) et
  `imageReference` (asset de la photo de référence, optionnel).
- Le rendu (`zone_overlay.dart`) affiche le `nom` sur le marqueur et code la couleur
  selon la présence de photos.

## Ce qu'on place sur chaque plan

Deux catégories de zones par plan :

### A. Points structurels 1→8 (bas de caisse / bogie)
- Les **mêmes 8 points** existent des **deux côtés** (mêmes numéros 1→8).
- Photo de référence : **point N → `Image N`** (Image 1 → point 1, … Image 8 → point 8).
  Ces photos (`Image 1.png` … `Image 8.png`, aujourd'hui à la racine du dépôt) seront
  intégrées dans `assets/reference/` et référencées par `imageReference`.
- **R1 Droit-Pair conserve** ses 8 points actuels (positions + photos de référence
  inchangées) ; ils sont simplement **renommés** selon la nomenclature ci-dessous.

### B. Zones-panneaux (lettres)
- Repères de panneaux, répartis par côté :
  - Côté **Droit-Pair** : `L, M, N, O, P, Q, R, S, T, U, V, W, Y`
  - Côté **Gauche-Impair** : `A, B, C, D, E, F, G, H, I, J, K, X`
- Position : la croix placée sous chaque case-lettre dans `R2.png`.
- **Pas de photo de référence** pour l'instant.

## Nomenclature des noms de zone (unicité)

**`nom = R{rame} {D|G}{identifiant}`**

- `D` = Droit-Pair, `G` = Gauche-Impair.
- `identifiant` = un **chiffre** (point structurel 1→8) ou une **lettre** (panneau).

| Type | Droit-Pair | Gauche-Impair |
|------|------------|----------------|
| Points structurels | `R1 D1` … `R1 D8` | `R1 G1` … `R1 G8` |
| Panneaux (lettres) | `R1 DL`, `R1 DM` … `R1 DY` | `R1 GA`, `R1 GB` … `R1 GX` |

Ce nom est **unique** par (rame, côté, point). Comme les photos prises par
l'utilisateur sont enregistrées à partir du nom de la zone, cette unicité **évite tout
mélange** entre rames et entre côtés.

> Note sur « côté droit = pair / côté gauche = impair » : il s'agit des **libellés de
> côté** déjà utilisés dans le projet (« Droit-**Pair** » / « Gauche-**Impair** »), pas
> d'une renumérotation paire/impaire des points. Aucune renumérotation n'est faite.

## Méthode de placement des positions

Les positions sont saisies **à la main d'après `R2.png`** (les deux côtés), puis
**répliquées** sur les autres remorques (« c'est à peu près pareil sur toutes les
remorques »).

## Découpage en étapes

- **Étape 1 — Gabarit R2 (les 2 côtés)**
  Placer dans `zones.json`, pour `Remorque (Droit-Pair) R2` et
  `Remorque (Gauche-Impair) R2` : les 8 points structurels + les zones-lettres du côté,
  avec la nomenclature `R2 D…` / `R2 G…` et les `imageReference` `Image 1→8` pour les
  points. Générer une **image de contrôle** (zones dessinées sur le plan réel de l'app :
  `image3.png` pour R2 Droit, `image16.png` pour R2 Gauche) et la soumettre à validation.

- **Étape 2 — Validation / ajustement du gabarit**
  L'utilisateur valide ou corrige les positions sur l'image de contrôle. On fige la
  disposition de référence.

- **Étape 3 — Réplication R1 + R3→R8**
  Copier la disposition validée (mêmes coordonnées normalisées) sur les 7 autres
  remorques, deux côtés, en adaptant le préfixe de rame (`R1 …`, `R3 …`, …).
  **R1 Droit-Pair** : conserver ses 8 points existants (repositionnés à l'identique de
  leurs valeurs actuelles), renommés `R1 D1`…`R1 D8`, et **ajouter** les zones-lettres
  du côté droit.

- **Étape 4 — Intégration des photos de référence + build**
  Copier `Image 1.png`…`Image 8.png` dans `assets/reference/` (déclarées dans
  `pubspec.yaml` si nécessaire), câbler `imageReference`, puis build APK (GitHub Actions)
  et/ou hot-reload local pour vérification.

## Périmètre

Les **8 remorques R1→R8**, **R4 incluse**.

## Points ouverts / à confirmer plus tard

- **Positions exactes** : validées visuellement à l'étape 2 (le placement manuel est
  approximatif par nature).
- **Correspondance images de fond** : vérifier que `image3.png` / `image16.png` (plans de
  l'app pour R2) cadrent comme les fonds de `R2.png` avant de réutiliser les mêmes
  coordonnées ; sinon recaler.
- **Photos de référence des lettres** : aucune pour l'instant ; à fournir ultérieurement
  si besoin.
- **`largeur` / `hauteur`** des nouvelles zones : reprendre les valeurs des points R1
  existants (`0.03 × 0.07`) comme taille par défaut, ajustable.
