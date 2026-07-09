# Tab Visite — Application tablette de visite sur plan interactif

**Date :** 2026-07-09
**Statut :** Conception validée
**Plateforme cible :** Android 10+ (tablette), 100 % hors-ligne
**Technologie :** Flutter (Dart)

---

## 1. Contexte et objectif

« Tab Visite » est une application Android pour tablette destinée aux **tournées de
visite/inspection de trains**. L'agent affiche le plan technique d'une voiture (vue de
côté), sur lequel figurent des **zones de contrôle repérées par des lettres** (M, N, O,
P… Y). Pour chaque zone, l'agent prend une ou plusieurs **photos** qui sont enregistrées
localement et associées à la zone.

Le fichier source fourni (`2N.xlsx`) contient **18 images** empilées verticalement :
chacune correspond à une vue/voiture du train et constitue **un plan**.

L'application fonctionne **entièrement hors connexion** ; toutes les données restent sur
la tablette.

## 2. Décisions de conception validées

| Sujet | Décision |
|-------|----------|
| Technologie | Flutter (Dart), Android 10+ |
| Production de l'APK | Build automatique via **GitHub Actions** (aucun outil installé localement) |
| Source des plans | **Images PNG/JPG**. Les 18 images de `2N.xlsx` sont extraites et livrées comme plans prêts. Import d'images supplémentaires depuis l'app. Pas de lecture live du `.xlsx`. |
| Photos par zone | **Plusieurs** (galerie par zone) |
| Définition des zones | **Hybride** : zones du plan 2N pré-positionnées + éditeur intégré pour ajuster/ajouter |
| Stockage | **SQLite** (sqflite) pour les métadonnées + **fichiers** dans le dossier privé de l'app pour les images |
| Périmètre v1 | Cœur + **recherche de zone** + **export des photos** + **rapport PDF** |

## 3. Architecture

Trois couches :

- **Données**
  - SQLite (`sqflite`) : tables `plans`, `zones`, `photos`.
  - Fichiers : images de plans (`plans/`) et photos (`photos/`) dans
    `getApplicationDocumentsDirectory()` → persistance garantie après fermeture et
    réouverture.
- **Logique**
  - Repositories : `PlanRepository`, `ZoneRepository`, `PhotoRepository`.
  - Services : `PlanImportService`, `PhotoCaptureService`, `ExportService`, `PdfService`,
    `SeedService` (chargement initial des plans/zones livrés).
- **UI** : écrans décrits en §5, avec gestion d'état légère (Provider ou Riverpod — à
  trancher au moment du plan d'implémentation, sans impact sur la spec).

## 4. Modèle de données

### Table `plans`
| Champ | Type | Notes |
|-------|------|-------|
| id | TEXT (uuid) | PK |
| nom | TEXT | ex. « 2N — Voiture 1 » |
| chemin_image | TEXT | chemin relatif au dossier de l'app |
| ordre | INTEGER | ordre d'affichage |
| date_creation | INTEGER | epoch ms |

### Table `zones`
| Champ | Type | Notes |
|-------|------|-------|
| id | TEXT (uuid) | PK |
| plan_id | TEXT | FK → plans.id (ON DELETE CASCADE) |
| nom | TEXT | ex. « M » |
| x | REAL | 0–1, coin haut-gauche normalisé / largeur image |
| y | REAL | 0–1, normalisé / hauteur image |
| largeur | REAL | 0–1 |
| hauteur | REAL | 0–1 |
| date_creation | INTEGER | epoch ms |

Les **coordonnées normalisées (0–1)** garantissent que les zones restent alignées sur le
plan quel que soit le zoom, le déplacement ou la résolution d'affichage.

### Table `photos`
| Champ | Type | Notes |
|-------|------|-------|
| id | TEXT (uuid) | PK |
| zone_id | TEXT | FK → zones.id (ON DELETE CASCADE) |
| chemin_fichier | TEXT | chemin relatif |
| date_prise | INTEGER | epoch ms (date + heure de la prise) |
| date_creation | INTEGER | epoch ms |

La date et l'heure demandées pour chaque zone sont dérivées de `date_prise`.

## 5. Écrans

1. **Accueil — liste des plans**
   - Liste/grille : vignette du plan, nom, nombre de zones et de photos.
   - Boutons : *Ajouter un plan* (importer une image → crée un plan vide), *Recherche
     globale* de zone (par nom, tous plans confondus).
   - Tap sur un plan → Vue plan.

2. **Vue plan (plein écran)**
   - Image affichée dans un `InteractiveViewer` : **zoom à deux doigts** + **déplacement**.
   - Les zones sont dessinées dans un `Stack` **enfant du même `InteractiveViewer`** (même
     repère que l'image) → elles restent ancrées au plan pendant zoom/déplacement.
   - Code couleur : zone **avec** photo(s) = **verte/pleine**, zone **sans** photo =
     **rouge/contour**. Le nom de la zone est affiché sur le marqueur.
   - Barre d'outils : *Retour*, *Mode édition*, *Recherche* (dans ce plan), *Export*, *PDF*.
   - Tap sur une zone (hors édition) → Écran zone.

3. **Mode édition** (bascule dans la Vue plan)
   - *Ajouter une zone* : glisser pour tracer un rectangle, puis saisir le nom.
   - Sélectionner une zone : la **déplacer**, la **redimensionner** (poignées), la
     **renommer**, la **supprimer**.
   - Sortie du mode édition → sauvegarde en base.

4. **Écran zone** (feuille modale en bas d'écran)
   - Titre : nom de la zone.
   - **Galerie de photos** : vignettes avec date + heure.
   - Boutons : *Ajouter une photo* (ouvre l'appareil photo système, prend la photo,
     l'enregistre et l'associe à la zone).
   - Tap sur une vignette → Visionneuse photo.
   - *Retour*.

5. **Visionneuse photo (plein écran)**
   - Affichage plein écran de la photo, **zoom** possible.
   - Boutons : *Supprimer la photo* (avec confirmation), *Retour*.

6. **Export des photos**
   - Génère une archive **zip** organisée par plan/zone, fichiers nommés avec la date/heure.
   - Partage via la feuille de partage Android (`share_plus`) ou enregistrement dans un
     dossier accessible.

7. **Rapport PDF (par plan)**
   - Page(s) : le **plan en haut**, puis chaque **zone** avec ses **photos**, sa **date** et
     son **heure**.
   - Généré hors-ligne (`pdf` + `printing`), partageable/imprimable.

## 6. Points techniques

- **Appareil photo** : `image_picker` (`pickImage(source: camera)`) — ouvre l'appareil
  photo système de la tablette, récupère l'image, la copie dans `photos/`. Conforme à
  « ouvrir l'appareil photo de la tablette ».
- **Zoom & ancrage** : `InteractiveViewer` (built-in), zones en `Positioned` dans un
  `Stack` dimensionné à l'image ; positions calculées depuis les coordonnées normalisées ×
  taille d'affichage de l'image. L'ancrage au zoom est alors automatique.
- **Détection des taps** : chaque zone = `GestureDetector` dans le `Stack` enfant.
- **Persistance** : SQLite + fichiers dans le dossier privé ; rien n'est perdu à la
  fermeture.
- **PDF / Export** : `pdf`, `printing`, `archive`, `share_plus`.
- **Permissions** : caméra ; stockage géré via *scoped storage* (Android 10+).
- **Seed initial** : les 18 images extraites de `2N.xlsx` sont incluses dans les assets ;
  au premier lancement, `SeedService` crée les plans correspondants et pré-positionne les
  zones connues (lettres visibles sur les dessins). Positions ajustables ensuite via
  l'éditeur.

## 7. Paquets Flutter envisagés

`sqflite`, `path`, `path_provider`, `image_picker`, `pdf`, `printing`, `archive`,
`share_plus`, `uuid`, gestion d'état (`provider` ou `riverpod`).

## 8. Livraison

- Projet Flutter complet dans le dépôt.
- Workflow **GitHub Actions** (`.github/workflows/build-apk.yml`) qui compile un APK
  release à chaque push et le publie en artefact téléchargeable.
- Guide d'installation : création du dépôt GitHub, récupération de l'APK, installation sur
  la tablette (sources inconnues).

## 9. Hors périmètre (v1)

- Lecture directe de fichiers `.xlsx` sur l'appareil.
- Synchronisation réseau / cloud (l'app est hors-ligne par conception).
- Multi-utilisateurs / comptes.
- Annotation dessinée sur les photos.

## 10. Critères de réussite

- L'app affiche les plans du train, plein écran, avec zoom deux doigts et déplacement.
- Les zones restent ancrées au plan pendant le zoom.
- Un tap sur une zone vide ouvre l'appareil photo ; la photo est enregistrée et associée.
- Un tap sur une zone avec photos affiche la galerie (Ajouter / Voir / Supprimer).
- Les photos et données persistent après fermeture/réouverture.
- Recherche de zone, export zip et rapport PDF fonctionnent hors-ligne.
- Un APK installable est produit par GitHub Actions.
