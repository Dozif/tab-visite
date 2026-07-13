# Visite MKBAM (motrice) — points de corrosion M1/M2

Date : 2026-07-13
Statut : design validé (en attente relecture spec)

## Contexte

L'app tablette Flutter `tab_visite/` gère des visites de corrosion. Le type
**MKBDR** (remorques R1→R8) est déjà peuplé de points de corrosion. Le type
**MKBAM** (motrices) existe dans la navigation mais les 4 vues motrice ont
**0 point**. On peuple ici les motrices, sur le même modèle que les remorques.

Sources fournies :
- `Motrice 2N.docx` : 2 photos de référence (aucun texte).
  - Photo ① : point de corrosion sur le **flanc / bas de caisse**.
  - Photo ② : point de corrosion sur le **pavillon** (profil/toiture).
- `Motrice 2N.xlsx` : noms corrigés des 4 vues motrice.
- `motrice 2N.png` : planche des 4 vues motrice (2162×904), source pour
  l'image manquante.

## Modèle existant (rappel)

- Un **plan** (`assets/seed/zones.json`) = `{ nom, image, zones[] }` avec
  `categorie` déduite du nom (`Motrice…` → `motrice`).
- `numeroVehicule` est extrait du nom par regex `[MR]\d+` → `M1`/`M2`.
- Navigation MKBAM : Accueil → carrés **M1 / M2** → les vues (côtés) → points.
- Un **point de corrosion** = une zone
  `{ nom, x, y, largeur, hauteur, imageReference }` (coords normalisées 0–1).
- Nomenclature remorque : `R1 D1`, `R1 G1`… (D = Droit-Pair, G = Gauche-Impair).

## Décisions

1. **2 points de corrosion** par vue motrice (le « gabarit » motrice) :
   - Point 1 → photo ① → `assets/reference/motrice_point1.png` (flanc bas de caisse).
   - Point 2 → photo ② → `assets/reference/motrice_point2.png` (pavillon).
2. **Réunis sur M1 et M2** : les 2 mêmes points sur les 4 vues.
3. **Positions par défaut** approximatives, **ajustables au doigt** dans
   l'éditeur de zones de l'app.
4. **Correction du doublon d'image** : `Motrice (Gauche-Impair) M2` pointe
   aujourd'hui à tort sur `image2.png` (= M1 Droit-Pair). On lui donne une
   image dédiée découpée depuis la vue 1 de `motrice 2N.png`.

## Structure cible (seed `zones.json`)

Les 4 vues motrice (noms conformes au xlsx corrigé) :

| Nom du plan | Image | numeroVehicule | Zones |
|---|---|---|---|
| Motrice (Droit-Pair) M1 | image2.png | M1 | M1 D1, M1 D2 |
| Motrice M1 Côté Gauche | image18.png | M1 | M1 G1, M1 G2 |
| Motrice (Droit-Pair) M2 | image9.png | M2 | M2 D1, M2 D2 |
| Motrice (Gauche-Impair) M2 | **image19.png** (nouvelle) | M2 | M2 G1, M2 G2 |

→ **8 zones** au total, toutes pointant vers les 2 mêmes photos de référence :
- `*1` (D1/G1) → `assets/reference/motrice_point1.png`
- `*2` (D2/G2) → `assets/reference/motrice_point2.png`

## Positions par défaut des zones

Coordonnées normalisées (x,y = coin haut-gauche de l'encadré ; largeur/hauteur
identiques aux zones remorques : 0.03 × 0.07). Ajustables ensuite dans l'app.

| Zone | x | y | Repère |
|---|---|---|---|
| point 1 (flanc, vues Droit-Pair) | 0.35 | 0.72 | bas de caisse |
| point 2 (pavillon, vues Droit-Pair) | 0.45 | 0.08 | toiture |
| point 1 (flanc, vues Gauche-Impair) | 0.60 | 0.72 | bas de caisse |
| point 2 (pavillon, vues Gauche-Impair) | 0.50 | 0.08 | toiture |

(Le nez de motrice change de sens selon Droit/Gauche → x du flanc décalé pour
rester côté caisse ; peaufinage in-app de toute façon.)

## Assets à produire

1. `tab_visite/assets/reference/motrice_point1.png` ← image1 du docx (flanc).
2. `tab_visite/assets/reference/motrice_point2.png` ← image2 du docx (pavillon).
3. `tab_visite/assets/plans/image19.png` ← découpe de la vue 1
   (« Motrice (Gauche-Impair) M2 ») de `motrice 2N.png`, bande supérieure,
   en retirant au mieux le libellé rouge et en gardant le dessin.

`pubspec.yaml` déclare déjà les **dossiers** `assets/plans/` et
`assets/reference/` → aucun ajout pubspec nécessaire.

## Hors périmètre / risques

- **Bug d'affichage connu** (mémoire) : « photo de référence non affichée » et
  « encadrés rouges haute/basse absents » côté visualisation. Ce spec ne traite
  que les **données** motrice ; si le bug d'affichage persiste, les photos
  motrice ne s'afficheront pas non plus → à vérifier/traiter séparément.
- Positions exactes : volontairement approximatives (décision : ajustement in-app).
- Image `image19.png` : si un dessin propre et dédié de M2 Gauche-Impair est
  fourni plus tard, il remplacera la découpe.

## Critères de succès

- Le carré **M2** ouvre 2 vues distinctes (Droit-Pair et Gauche-Impair), sans
  doublon d'image.
- Chaque vue motrice (M1 et M2, 2 côtés) affiche **2 points** cliquables
  renvoyant aux photos ①/②.
- Aucune régression sur les remorques (R1→R8 inchangées).
