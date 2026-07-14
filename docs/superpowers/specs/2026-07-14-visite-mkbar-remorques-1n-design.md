# Visite MKBAR (remorques 1N) — points de corrosion + panneaux lettres

Date : 2026-07-14
Statut : implémenté et validé (points + mapping photos + lettres confirmés par Franck).

## Contexte

Le type de visite **MKBAR** (remorques d'une série autre que 2N) existait dans la
navigation et le filtre (`categorie = 'remorque' AND serie <> '2N'`) mais était
**vide**. On peuple ici les **16 vues de remorques 1N** (R1→R8 × Droit-Pair /
Gauche-Impair), sur le modèle des remorques 2N (MKBDR) et des motrices (MKBAM).

Sources fournies par Franck :
- `Remorque 1N.xlsx` — 16 vues, 12 dessins de fond intégrés (R3 réutilise le fond
  de R2 ; R7 celui de R6), marqueurs de corrosion numérotés **types 1–4**.
- `MKBAR 1N.docx` — 5 photos de référence (badges 1/1/2/3/1).
- `remorque 1N.png` — export de contrôle.

## Décisions (validées)

1. Zones = **points numérotés + panneaux lettres**.
2. Positions des points **extraites exactement** de l'Excel (drawing1.xml).
3. Types 1–4 = **partagés** : le type N → même photo de référence partout.
4. Mapping photo → type : **type 1** → `remorque1n_point1.png` (docx image1,
   perforation toit/nez) ; **type 2** → `remorque1n_point2.png` (docx image3,
   points de fixation cadre-caisse) ; **type 3** → `remorque1n_point3.png` (docx
   image4) ; **type 4** → pas de photo dédiée.

## Réalisation

- **12 fonds** extraits du xlsx → `assets/plans/image23.png … image34.png`
  (contiennent déjà le dessin + les lettres, sans le titre rouge).
- **142 points** : positions absolues calculées depuis les ancres du drawing
  (largeurs colonnes / hauteurs lignes de `sheet1.xml`), normalisées relativement
  au fond de chaque vue, centrées (`x = centre − largeur/2`). Validées sur images
  de contrôle : 0 point hors bornes, alignement confirmé.
- **113 panneaux lettres** : positions relevées visuellement sur les 12 fonds
  (règle de graduation), sans `imageReference`.
- **3 photos de référence** copiées du docx → `assets/reference/remorque1n_point{1,2,3}.png`.
- **16 plans** ajoutés à `assets/seed/zones.json` avec `categorie: "remorque"`,
  `serie: "1N"` explicites (255 zones au total).

### Nomenclature

- Points : `R{n} {D|G}{type}.{i}` (ex. `R1 D2.1`, `R1 D2.2`) — `imageReference`
  selon le type. `.i` = instance (plusieurs points d'un même type par vue).
- Lettres : `R{n} {D|G}{lettre}` (ex. `R1 DI`) — pas de photo.
- `D` = Droit-Pair, `G` = Gauche-Impair. Chaque remorque numérote ses lettres en
  continu sur ses deux côtés (ex. R1 : G = A–H, D = I–P).

## Câblage — aucune modification de code

- `plan_repository.forTypeVisite(MKBAR, …)` filtre déjà `serie <> '2N'` → capte les
  16 remorques 1N. Navigation remorque (carrés R1→R8, 2 côtés) commune à MKBDR.
- `seed_service` lit `categorie`/`serie` du JSON ; `planId` = UUID aléatoire →
  **aucune collision** avec les remorques 2N de même nom (photos liées à `zone.id`).
- `pubspec.yaml` déclare les dossiers `assets/plans/` et `assets/reference/` → les
  nouveaux PNG sont inclus sans ajout.

## Vérification

- `flutter test` : **17 tests verts** (aucune régression ; les tests utilisent du
  JSON inline, indépendants du seed réel).
- Validation JSON : unicité des noms par plan, coords ∈ bornes → OK.
- Images de contrôle (points + lettres superposés) validées visuellement.

## Reste à faire / risques

- **Test tablette** (build APK GitHub Actions ou hot-reload local) : vérifier la
  navigation MKBAR → R1→R8 → côtés → points/lettres, et l'ouverture des photos.
- **Bugs d'affichage connus** (photo de référence non affichée, encadrés
  haute/basse) : hors périmètre ; s'ils persistent ils toucheront aussi MKBAR.
- Léger décalage (~0.02) de quelques lettres, ajustable au doigt dans l'app.
- Photos type 1 : 3 candidates (badge 1) ; retenu docx image1 (perforation nette).
