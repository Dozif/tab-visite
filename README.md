# Tab Visite

Application Android pour tablette, **hors-ligne**, permettant de prendre des photos directement sur les plans interactifs d'un train 2N lors des visites/inspections.

## 1. Présentation

Tab Visite affiche les plans d'une rame de train 2N (18 plans pré-chargés) en plein écran sur tablette. Chaque plan comporte des **zones repérées** (sièges, équipements, compartiments...). Pour chaque zone, l'utilisateur peut :

- prendre une ou plusieurs photos directement depuis l'application (appareil photo intégré),
- consulter une **galerie photo** par zone,
- **rechercher** une zone par son nom,
- **exporter** toutes les photos d'un plan (ou de l'ensemble) dans une archive `.zip`,
- générer un **rapport PDF** reprenant le plan et ses photos.

Tout fonctionne **sans connexion internet** : les plans, les zones et les photos sont stockés localement sur la tablette (base SQLite + fichiers), et les données restent disponibles après fermeture de l'application.

## 2. Obtenir l'APK via GitHub (sans rien installer sur son ordinateur)

Aucune installation de Flutter ou d'outil de développement n'est nécessaire : GitHub construit l'APK automatiquement (GitHub Actions). Il suffit d'un compte GitHub.

### a. Créer un compte GitHub et un dépôt

1. Si besoin, créez un compte gratuit sur [github.com](https://github.com).
2. Créez un nouveau dépôt (bouton **New repository**), par exemple nommé `tab-visite`. Vous pouvez le laisser privé ou public.

### b. Pousser ce dossier sur GitHub

Depuis ce dossier de projet (celui qui contient ce fichier `README.md`), dans un terminal :

```bash
git remote add origin <URL-de-votre-dépôt-GitHub>
git push -u origin feat/tab-visite-app
```

Remplacez `<URL-de-votre-dépôt-GitHub>` par l'URL donnée par GitHub lors de la création du dépôt (par ex. `https://github.com/<votre-compte>/tab-visite.git`).

Le workflow de construction de l'APK (fichier `.github/workflows/build-apk.yml`) se déclenche automatiquement sur les branches **`main`** et **`feat/tab-visite-app`**. Vous pouvez donc soit :

- pousser directement la branche `feat/tab-visite-app` comme ci-dessus, soit
- fusionner cette branche sur `main` puis pousser `main`.

Dans les deux cas, chaque nouveau push relance automatiquement la construction de l'APK.

### c. Récupérer l'APK

1. Sur la page GitHub de votre dépôt, ouvrez l'onglet **Actions**.
2. Attendez la fin du job **Build APK** (une coche verte apparaît une fois terminé ; cela prend quelques minutes).
3. Cliquez sur l'exécution terminée, puis dans la section **Artifacts** en bas de page, téléchargez **`tab-visite-apk`**.
4. Ce téléchargement est une archive `.zip` qui contient le fichier `app-release.apk`. Décompressez-la pour récupérer l'APK.

> Remarque : les étapes `flutter analyze` et `flutter test` du workflow sont configurées en mode « rapport seul » (non bloquantes) : elles n'empêchent jamais la production de l'APK. Seule l'étape de compilation (`flutter build apk --release`) peut faire échouer la construction, et uniquement en cas de véritable erreur de compilation.

## 3. Installer l'APK sur la tablette

1. Copiez le fichier `app-release.apk` sur la tablette (câble USB, email, clé USB, cloud, etc.).
2. Sur la tablette, avant d'installer un APK en dehors du Play Store, il faut autoriser la source : allez dans **Paramètres → Sécurité** (ou **Applications**) et activez **Sources inconnues** / **Installer des applications inconnues** pour l'application utilisée pour ouvrir le fichier (ex. le gestionnaire de fichiers ou l'application mail).
3. Ouvrez le fichier `app-release.apk` depuis la tablette (gestionnaire de fichiers).
4. Appuyez sur **Installer**, puis **Ouvrir** une fois l'installation terminée.

L'application fonctionne sur **Android 10 et versions ultérieures**.

## 4. Premier lancement

Au premier démarrage, les **18 plans du train 2N** sont chargés automatiquement dans l'application (aucune configuration nécessaire).

- Le plan **« Voiture (M–Y) »** possède déjà ses zones **M à Y** pré-positionnées et prêtes à l'emploi.
- Les **autres plans sont vierges** : vous pouvez y ajouter des zones vous-même via le mode édition (voir ci-dessous).

## 5. Utilisation

- Le plan s'affiche en **plein écran**. Zoomez avec **deux doigts** et déplacez le plan avec un doigt.
- **Tap sur une zone rouge** (sans photo) : ouvre l'appareil photo de la tablette ; la photo prise est automatiquement enregistrée et associée à la zone, qui devient alors **verte**.
- **Tap sur une zone verte** (avec photo(s)) : ouvre la **galerie** de la zone, avec les options **Ajouter** (une nouvelle photo), **Voir** (les photos existantes) et **Supprimer**.
- **Bouton crayon** : active le **mode édition**, qui permet de déplacer, redimensionner, renommer, ajouter ou supprimer des zones sur le plan affiché.
- **Icône loupe** : ouvre la **recherche** pour retrouver rapidement une zone par son nom.
- **Icône zip** : lance l'**export** des photos (du plan courant ou de l'ensemble) dans une archive `.zip`.
- **Icône PDF** : génère un **rapport PDF** reprenant le plan et les photos de ses zones.
- **Appui long** sur un plan (dans la liste des plans) : propose la **suppression** du plan.

## 6. Stockage des données

Toutes les données (liste des plans, zones, informations de chaque photo — nom de zone, date, heure, chemin du fichier) sont stockées **localement** sur la tablette dans une base **SQLite**, et les photos sont enregistrées comme fichiers sur le stockage de l'appareil. Ces données sont **persistantes** : elles restent disponibles après fermeture ou redémarrage de l'application, et **aucune connexion internet n'est requise** pour utiliser l'application.

## 7. Développement (optionnel, pour qui a Flutter installé)

Le code source de l'application se trouve dans le dossier `tab_visite/`. Pour lancer l'application en mode développement :

```bash
cd tab_visite
flutter pub get
flutter run
```
