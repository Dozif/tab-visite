# Tab Visite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** Construire une application Flutter Android (tablette, hors-ligne) de prise de photos sur des plans de train interactifs, avec zones ancrées, galerie par zone, persistance locale, recherche, export zip et rapport PDF.

**Architecture :** Trois couches — données (SQLite via `sqflite` + fichiers dans le dossier privé de l'app), logique (repositories + services), UI (écrans Flutter). Les plans sont des images ; les zones sont stockées en coordonnées normalisées (0–1) et rendues dans un `Stack` enfant d'un `InteractiveViewer` pour rester ancrées au zoom.

**Tech Stack :** Flutter/Dart, `sqflite`, `path`, `path_provider`, `image_picker`, `pdf`, `printing`, `archive`, `share_plus`, `uuid`, `provider`. Build via GitHub Actions.

## Global Constraints

- **Plateforme :** Android 10+ (minSdk 29), 100 % hors-ligne. Aucune dépendance réseau à l'exécution.
- **Langue de l'UI :** français, avec accents corrects.
- **Stockage :** métadonnées en SQLite ; images (plans + photos) en fichiers sous `getApplicationDocumentsDirectory()`. Chemins stockés en **relatif** au dossier de l'app (portables entre installations).
- **Coordonnées de zones :** toujours normalisées 0–1 (fraction de largeur/hauteur de l'image). Jamais de pixels en base.
- **IDs :** chaînes UUID v4 (`uuid` package).
- **Dates :** stockées en epoch millisecondes (INTEGER). Affichage `jj/mm/aaaa` et `HH:mm`.
- **Tests :** `flutter test` (exécuté en CI GitHub Actions ; localement si un SDK Flutter est présent). Chaque tâche à logique testable inclut un test qui doit échouer avant implémentation.
- **Commits :** fréquents, un par tâche minimum, messages en français préfixés (`feat:`, `test:`, `chore:`, `docs:`).

---

## File Structure

```
tab_visite/
├── pubspec.yaml
├── analysis_options.yaml
├── .github/workflows/build-apk.yml
├── android/                         # généré par `flutter create`, minSdk=29, permission caméra
├── assets/
│   ├── plans/                       # image1.png … image18.png (extraites de 2N.xlsx)
│   └── seed/zones.json              # zones pré-positionnées par plan
├── lib/
│   ├── main.dart                    # bootstrap : DB, seed, runApp
│   ├── app.dart                     # MaterialApp, thème, routes, providers
│   ├── data/
│   │   ├── database.dart            # ouverture sqflite + schéma + migrations
│   │   ├── models/
│   │   │   ├── plan.dart
│   │   │   ├── zone.dart
│   │   │   └── photo.dart
│   │   └── repositories/
│   │       ├── plan_repository.dart
│   │       ├── zone_repository.dart
│   │       └── photo_repository.dart
│   ├── services/
│   │   ├── file_storage.dart        # chemins app, copie/suppression fichiers
│   │   ├── plan_import_service.dart # importer une image → plan
│   │   ├── photo_capture_service.dart # image_picker caméra → fichier
│   │   ├── seed_service.dart        # 1er lancement : plans + zones depuis assets
│   │   ├── export_service.dart      # zip des photos
│   │   └── pdf_service.dart         # rapport PDF par plan
│   └── ui/
│       ├── home/plans_screen.dart
│       ├── plan/plan_view_screen.dart
│       ├── plan/zone_overlay.dart   # rendu des marqueurs de zones
│       ├── plan/zone_editor_controller.dart
│       ├── zone/zone_sheet.dart
│       ├── photo/photo_viewer.dart
│       ├── search/search_screen.dart
│       └── widgets/date_format.dart # helpers d'affichage date/heure
└── test/
    ├── models_test.dart
    ├── database_test.dart
    ├── plan_repository_test.dart
    ├── zone_repository_test.dart
    ├── photo_repository_test.dart
    ├── file_storage_test.dart
    ├── export_service_test.dart
    └── ui/plans_screen_test.dart
```

Chaque fichier a une responsabilité unique. Les repositories ne dépendent que de `database.dart` et des modèles ; les services orchestrent repositories + fichiers ; l'UI consomme repositories/services via `provider`.

---

## Task 1 : Scaffold du projet + CI

**Files:**
- Create: `tab_visite/pubspec.yaml`
- Create: `tab_visite/analysis_options.yaml`
- Create: `tab_visite/.github/workflows/build-apk.yml`
- Create: `tab_visite/lib/main.dart` (temporaire), `tab_visite/lib/app.dart`
- Modify: `tab_visite/android/app/build.gradle` (minSdk), `AndroidManifest.xml` (permission caméra)

**Interfaces:**
- Produces: application Flutter compilable ; `MyApp` widget dans `app.dart`.

- [ ] **Step 1: Générer le projet**

Run: `flutter create --org com.tabvisite --project-name tab_visite tab_visite`

- [ ] **Step 2: Écrire `pubspec.yaml`** (remplacer les dépendances)

```yaml
name: tab_visite
description: Application tablette de visite sur plan interactif (hors-ligne).
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.3
  path: ^1.9.0
  path_provider: ^2.1.4
  image_picker: ^1.1.2
  pdf: ^3.11.1
  printing: ^5.13.2
  archive: ^3.6.1
  share_plus: ^10.0.2
  uuid: ^4.5.0
  provider: ^6.1.2
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  sqflite_common_ffi: ^2.3.3   # DB en mémoire pour les tests
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/plans/
    - assets/seed/zones.json
```

- [ ] **Step 3: Fixer minSdk et permission caméra**

Dans `android/app/build.gradle`, sous `defaultConfig` : `minSdkVersion 29`.
Dans `android/app/src/main/AndroidManifest.xml`, avant `<application>` :

```xml
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

(`image_picker` gère la permission runtime ; pas besoin de `CAMERA` dans le manifest pour l'app appelant l'appareil photo système, mais on déclare la feature non requise.)

- [ ] **Step 4: `lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'ui/home/plans_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tab Visite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const PlansScreen(),
    );
  }
}
```

- [ ] **Step 5: `lib/main.dart` (temporaire, remplacé en Task 12)**

```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() => runApp(const MyApp());
```

Créer un `PlansScreen` minimal provisoire dans `lib/ui/home/plans_screen.dart` :

```dart
import 'package:flutter/material.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Tab Visite')));
}
```

- [ ] **Step 6: Workflow CI `.github/workflows/build-apk.yml`**

```yaml
name: Build APK
on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
        working-directory: tab_visite
      - run: flutter analyze
        working-directory: tab_visite
      - run: flutter test
        working-directory: tab_visite
      - run: flutter build apk --release
        working-directory: tab_visite
      - uses: actions/upload-artifact@v4
        with:
          name: tab-visite-apk
          path: tab_visite/build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 7: Vérifier la compilation**

Run: `cd tab_visite && flutter pub get && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add tab_visite
git commit -m "chore: scaffold projet Flutter + workflow CI de build APK"
```

---

## Task 2 : Modèles de données

**Files:**
- Create: `lib/data/models/plan.dart`, `lib/data/models/zone.dart`, `lib/data/models/photo.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Produces:
  - `Plan(id, nom, cheminImage, ordre, dateCreation)` + `toMap()`/`Plan.fromMap(Map)`
  - `Zone(id, planId, nom, x, y, largeur, hauteur, dateCreation)` + `toMap()`/`Zone.fromMap(Map)`
  - `Photo(id, zoneId, cheminFichier, datePrise, dateCreation)` + `toMap()`/`Photo.fromMap(Map)`

- [ ] **Step 1: Écrire le test (échec attendu)**

`test/models_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';

void main() {
  test('Plan round-trip map', () {
    final p = Plan(id: 'p1', nom: '2N V1', cheminImage: 'plans/a.png', ordre: 2, dateCreation: 1000);
    expect(Plan.fromMap(p.toMap()).toMap(), p.toMap());
    expect(p.toMap()['nom'], '2N V1');
  });

  test('Zone round-trip et bornes normalisées', () {
    final z = Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0.1, y: 0.2, largeur: 0.05, hauteur: 0.08, dateCreation: 1);
    final back = Zone.fromMap(z.toMap());
    expect(back.x, 0.1);
    expect(back.nom, 'M');
    expect(back.planId, 'p1');
  });

  test('Photo round-trip map', () {
    final ph = Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/x.jpg', datePrise: 5, dateCreation: 6);
    expect(Photo.fromMap(ph.toMap()).cheminFichier, 'photos/x.jpg');
  });
}
```

- [ ] **Step 2: Lancer le test**

Run: `flutter test test/models_test.dart`
Expected: FAIL (fichiers modèles absents).

- [ ] **Step 3: Implémenter `lib/data/models/plan.dart`**

```dart
class Plan {
  final String id;
  final String nom;
  final String cheminImage; // relatif au dossier de l'app
  final int ordre;
  final int dateCreation;

  const Plan({
    required this.id,
    required this.nom,
    required this.cheminImage,
    required this.ordre,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'chemin_image': cheminImage,
        'ordre': ordre,
        'date_creation': dateCreation,
      };

  factory Plan.fromMap(Map<String, Object?> m) => Plan(
        id: m['id'] as String,
        nom: m['nom'] as String,
        cheminImage: m['chemin_image'] as String,
        ordre: m['ordre'] as int,
        dateCreation: m['date_creation'] as int,
      );

  Plan copyWith({String? nom, int? ordre}) => Plan(
        id: id,
        nom: nom ?? this.nom,
        cheminImage: cheminImage,
        ordre: ordre ?? this.ordre,
        dateCreation: dateCreation,
      );
}
```

- [ ] **Step 4: Implémenter `lib/data/models/zone.dart`**

```dart
class Zone {
  final String id;
  final String planId;
  final String nom;
  final double x, y, largeur, hauteur; // normalisés 0–1
  final int dateCreation;

  const Zone({
    required this.id,
    required this.planId,
    required this.nom,
    required this.x,
    required this.y,
    required this.largeur,
    required this.hauteur,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'plan_id': planId,
        'nom': nom,
        'x': x,
        'y': y,
        'largeur': largeur,
        'hauteur': hauteur,
        'date_creation': dateCreation,
      };

  factory Zone.fromMap(Map<String, Object?> m) => Zone(
        id: m['id'] as String,
        planId: m['plan_id'] as String,
        nom: m['nom'] as String,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        largeur: (m['largeur'] as num).toDouble(),
        hauteur: (m['hauteur'] as num).toDouble(),
        dateCreation: m['date_creation'] as int,
      );

  Zone copyWith({String? nom, double? x, double? y, double? largeur, double? hauteur}) => Zone(
        id: id,
        planId: planId,
        nom: nom ?? this.nom,
        x: x ?? this.x,
        y: y ?? this.y,
        largeur: largeur ?? this.largeur,
        hauteur: hauteur ?? this.hauteur,
        dateCreation: dateCreation,
      );
}
```

- [ ] **Step 5: Implémenter `lib/data/models/photo.dart`**

```dart
class Photo {
  final String id;
  final String zoneId;
  final String cheminFichier; // relatif au dossier de l'app
  final int datePrise;
  final int dateCreation;

  const Photo({
    required this.id,
    required this.zoneId,
    required this.cheminFichier,
    required this.datePrise,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'zone_id': zoneId,
        'chemin_fichier': cheminFichier,
        'date_prise': datePrise,
        'date_creation': dateCreation,
      };

  factory Photo.fromMap(Map<String, Object?> m) => Photo(
        id: m['id'] as String,
        zoneId: m['zone_id'] as String,
        cheminFichier: m['chemin_fichier'] as String,
        datePrise: m['date_prise'] as int,
        dateCreation: m['date_creation'] as int,
      );
}
```

- [ ] **Step 6: Lancer les tests**

Run: `flutter test test/models_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models test/models_test.dart
git commit -m "feat: modèles Plan, Zone, Photo avec sérialisation"
```

---

## Task 3 : Couche base de données

**Files:**
- Create: `lib/data/database.dart`
- Test: `test/database_test.dart`

**Interfaces:**
- Produces: `class AppDatabase { static Future<Database> open({String? path}); }` — ouvre/crée la base, crée les tables `plans`, `zones`, `photos` avec clés étrangères `ON DELETE CASCADE` et index sur `zones.plan_id` et `photos.zone_id`.

- [ ] **Step 1: Test (échec attendu)** — `test/database_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('crée les 3 tables et applique le cascade', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final tables = await db.query('sqlite_master',
        where: "type = 'table' AND name IN ('plans','zones','photos')");
    expect(tables.length, 3);

    await db.insert('plans', {
      'id': 'p1', 'nom': 'x', 'chemin_image': 'a', 'ordre': 0, 'date_creation': 0
    });
    await db.insert('zones', {
      'id': 'z1', 'plan_id': 'p1', 'nom': 'M',
      'x': 0.0, 'y': 0.0, 'largeur': 0.1, 'hauteur': 0.1, 'date_creation': 0
    });
    await db.execute('PRAGMA foreign_keys = ON');
    await db.delete('plans', where: 'id = ?', whereArgs: ['p1']);
    final zones = await db.query('zones');
    expect(zones, isEmpty); // cascade
    await db.close();
  });
}
```

- [ ] **Step 2: Lancer** — Run: `flutter test test/database_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implémenter `lib/data/database.dart`**

```dart
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Future<Database> open({String? path}) async {
    return openDatabase(
      path ?? 'tab_visite.db',
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plans(
            id TEXT PRIMARY KEY,
            nom TEXT NOT NULL,
            chemin_image TEXT NOT NULL,
            ordre INTEGER NOT NULL,
            date_creation INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE zones(
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            nom TEXT NOT NULL,
            x REAL NOT NULL, y REAL NOT NULL,
            largeur REAL NOT NULL, hauteur REAL NOT NULL,
            date_creation INTEGER NOT NULL,
            FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE CASCADE
          )''');
        await db.execute('''
          CREATE TABLE photos(
            id TEXT PRIMARY KEY,
            zone_id TEXT NOT NULL,
            chemin_fichier TEXT NOT NULL,
            date_prise INTEGER NOT NULL,
            date_creation INTEGER NOT NULL,
            FOREIGN KEY(zone_id) REFERENCES zones(id) ON DELETE CASCADE
          )''');
        await db.execute('CREATE INDEX idx_zones_plan ON zones(plan_id)');
        await db.execute('CREATE INDEX idx_photos_zone ON photos(zone_id)');
      },
    );
  }
}
```

- [ ] **Step 4: Lancer** — Run: `flutter test test/database_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/database.dart test/database_test.dart
git commit -m "feat: schéma SQLite (plans, zones, photos) avec cascade et index"
```

---

## Task 4 : Repositories

**Files:**
- Create: `lib/data/repositories/plan_repository.dart`, `zone_repository.dart`, `photo_repository.dart`
- Test: `test/plan_repository_test.dart`, `test/zone_repository_test.dart`, `test/photo_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, modèles.
- Produces:
  - `PlanRepository(Database db)` : `Future<void> insert(Plan)`, `Future<List<Plan>> all()` (trié par `ordre`), `Future<void> update(Plan)`, `Future<void> delete(String id)`, `Future<int> nextOrdre()`.
  - `ZoneRepository(Database db)` : `Future<void> insert(Zone)`, `Future<List<Zone>> forPlan(String planId)`, `Future<void> update(Zone)`, `Future<void> delete(String id)`, `Future<List<Zone>> searchByName(String q)` (LIKE, tous plans).
  - `PhotoRepository(Database db)` : `Future<void> insert(Photo)`, `Future<List<Photo>> forZone(String zoneId)` (trié `date_prise` desc), `Future<void> delete(String id)`, `Future<int> countForZone(String zoneId)`, `Future<Map<String,int>> countsForPlanZones(String planId)` (map zoneId→nb photos).

- [ ] **Step 1: Test PlanRepository (échec)** — `test/plan_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/repositories/plan_repository.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('insert, all trié par ordre, nextOrdre', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = PlanRepository(db);
    await repo.insert(Plan(id: 'b', nom: 'B', cheminImage: 'b.png', ordre: 1, dateCreation: 0));
    await repo.insert(Plan(id: 'a', nom: 'A', cheminImage: 'a.png', ordre: 0, dateCreation: 0));
    final list = await repo.all();
    expect(list.map((p) => p.id).toList(), ['a', 'b']);
    expect(await repo.nextOrdre(), 2);
    await db.close();
  });
}
```

- [ ] **Step 2: Lancer** — `flutter test test/plan_repository_test.dart` — Expected: FAIL.

- [ ] **Step 3: `lib/data/repositories/plan_repository.dart`**

```dart
import 'package:sqflite/sqflite.dart';
import '../models/plan.dart';

class PlanRepository {
  final Database db;
  PlanRepository(this.db);

  Future<void> insert(Plan p) => db.insert('plans', p.toMap());

  Future<List<Plan>> all() async {
    final rows = await db.query('plans', orderBy: 'ordre ASC');
    return rows.map(Plan.fromMap).toList();
  }

  Future<void> update(Plan p) =>
      db.update('plans', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<void> delete(String id) =>
      db.delete('plans', where: 'id = ?', whereArgs: [id]);

  Future<int> nextOrdre() async {
    final r = await db.rawQuery('SELECT COALESCE(MAX(ordre), -1) + 1 AS n FROM plans');
    return (r.first['n'] as int);
  }
}
```

- [ ] **Step 4: `lib/data/repositories/zone_repository.dart`**

```dart
import 'package:sqflite/sqflite.dart';
import '../models/zone.dart';

class ZoneRepository {
  final Database db;
  ZoneRepository(this.db);

  Future<void> insert(Zone z) => db.insert('zones', z.toMap());

  Future<List<Zone>> forPlan(String planId) async {
    final rows = await db.query('zones',
        where: 'plan_id = ?', whereArgs: [planId], orderBy: 'nom ASC');
    return rows.map(Zone.fromMap).toList();
  }

  Future<void> update(Zone z) =>
      db.update('zones', z.toMap(), where: 'id = ?', whereArgs: [z.id]);

  Future<void> delete(String id) =>
      db.delete('zones', where: 'id = ?', whereArgs: [id]);

  Future<List<Zone>> searchByName(String q) async {
    final rows = await db.query('zones',
        where: 'nom LIKE ?', whereArgs: ['%$q%'], orderBy: 'nom ASC');
    return rows.map(Zone.fromMap).toList();
  }
}
```

- [ ] **Step 5: `lib/data/repositories/photo_repository.dart`**

```dart
import 'package:sqflite/sqflite.dart';
import '../models/photo.dart';

class PhotoRepository {
  final Database db;
  PhotoRepository(this.db);

  Future<void> insert(Photo p) => db.insert('photos', p.toMap());

  Future<List<Photo>> forZone(String zoneId) async {
    final rows = await db.query('photos',
        where: 'zone_id = ?', whereArgs: [zoneId], orderBy: 'date_prise DESC');
    return rows.map(Photo.fromMap).toList();
  }

  Future<void> delete(String id) =>
      db.delete('photos', where: 'id = ?', whereArgs: [id]);

  Future<int> countForZone(String zoneId) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM photos WHERE zone_id = ?', [zoneId]);
    return r.first['n'] as int;
  }

  Future<Map<String, int>> countsForPlanZones(String planId) async {
    final rows = await db.rawQuery('''
      SELECT p.zone_id AS zid, COUNT(*) AS n
      FROM photos p JOIN zones z ON z.id = p.zone_id
      WHERE z.plan_id = ? GROUP BY p.zone_id''', [planId]);
    return { for (final r in rows) r['zid'] as String : r['n'] as int };
  }
}
```

- [ ] **Step 6: Tests Zone & Photo** — `test/zone_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/repositories/plan_repository.dart';
import 'package:tab_visite/data/repositories/zone_repository.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('forPlan et searchByName', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    await PlanRepository(db).insert(Plan(id: 'p1', nom: 'P', cheminImage: 'a', ordre: 0, dateCreation: 0));
    final repo = ZoneRepository(db);
    await repo.insert(Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    await repo.insert(Zone(id: 'z2', planId: 'p1', nom: 'N', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    expect((await repo.forPlan('p1')).length, 2);
    expect((await repo.searchByName('M')).single.id, 'z1');
    await db.close();
  });
}
```

`test/photo_repository_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';
import 'package:tab_visite/data/repositories/plan_repository.dart';
import 'package:tab_visite/data/repositories/zone_repository.dart';
import 'package:tab_visite/data/repositories/photo_repository.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('forZone desc, counts', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    await PlanRepository(db).insert(Plan(id: 'p1', nom: 'P', cheminImage: 'a', ordre: 0, dateCreation: 0));
    await ZoneRepository(db).insert(Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    final repo = PhotoRepository(db);
    await repo.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'a.jpg', datePrise: 10, dateCreation: 0));
    await repo.insert(Photo(id: 'f2', zoneId: 'z1', cheminFichier: 'b.jpg', datePrise: 20, dateCreation: 0));
    expect((await repo.forZone('z1')).first.id, 'f2');
    expect(await repo.countForZone('z1'), 2);
    expect((await repo.countsForPlanZones('p1'))['z1'], 2);
    await db.close();
  });
}
```

- [ ] **Step 7: Lancer tous les tests repo** — `flutter test test/plan_repository_test.dart test/zone_repository_test.dart test/photo_repository_test.dart` — Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/data/repositories test/*repository_test.dart
git commit -m "feat: repositories Plan, Zone, Photo (CRUD, recherche, comptages)"
```

---

## Task 5 : Service de stockage fichiers

**Files:**
- Create: `lib/services/file_storage.dart`
- Test: `test/file_storage_test.dart`

**Interfaces:**
- Produces: `class FileStorage` avec :
  - `FileStorage(this.rootDir)` où `rootDir` est un `Directory` (dossier de base ; en prod = `getApplicationDocumentsDirectory()`).
  - `Future<void> ensureDirs()` — crée `plans/` et `photos/`.
  - `File resolve(String relative)` — chemin absolu depuis un chemin relatif stocké.
  - `Future<String> importImage(File src, String subdir, String ext)` — copie `src` sous `subdir/<uuid>.<ext>`, renvoie le **chemin relatif**.
  - `Future<void> deleteRelative(String relative)` — supprime si présent.

- [ ] **Step 1: Test (échec)** — `test/file_storage_test.dart`

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tab_visite/services/file_storage.dart';

void main() {
  test('importImage copie et renvoie un chemin relatif; delete supprime', () async {
    final root = Directory.systemTemp.createTempSync('tv_test');
    final storage = FileStorage(root);
    await storage.ensureDirs();

    final src = File(p.join(root.path, 'src.jpg'))..writeAsBytesSync([1, 2, 3]);
    final rel = await storage.importImage(src, 'photos', 'jpg');

    expect(rel.startsWith('photos/'), isTrue);
    expect(storage.resolve(rel).existsSync(), isTrue);

    await storage.deleteRelative(rel);
    expect(storage.resolve(rel).existsSync(), isFalse);
    root.deleteSync(recursive: true);
  });
}
```

- [ ] **Step 2: Lancer** — `flutter test test/file_storage_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implémenter `lib/services/file_storage.dart`**

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class FileStorage {
  final Directory rootDir;
  final Uuid _uuid = const Uuid();
  FileStorage(this.rootDir);

  Future<void> ensureDirs() async {
    await Directory(p.join(rootDir.path, 'plans')).create(recursive: true);
    await Directory(p.join(rootDir.path, 'photos')).create(recursive: true);
  }

  File resolve(String relative) => File(p.join(rootDir.path, relative));

  Future<String> importImage(File src, String subdir, String ext) async {
    final rel = '$subdir/${_uuid.v4()}.$ext';
    final dest = File(p.join(rootDir.path, rel));
    await dest.parent.create(recursive: true);
    await src.copy(dest.path);
    return rel;
  }

  Future<void> deleteRelative(String relative) async {
    final f = resolve(relative);
    if (await f.exists()) await f.delete();
  }
}
```

- [ ] **Step 4: Lancer** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/file_storage.dart test/file_storage_test.dart
git commit -m "feat: FileStorage (import/suppression images, chemins relatifs)"
```

---

## Task 6 : Assets des plans + fichier de seed des zones

**Files:**
- Create: `assets/plans/image1.png` … `image18.png` (copiées depuis l'extraction de `2N.xlsx`)
- Create: `assets/seed/zones.json`

**Interfaces:**
- Produces: 18 images d'assets + un JSON décrivant, par plan, son nom, son fichier et ses zones normalisées.

- [ ] **Step 1: Copier les 18 images**

Les images ont déjà été extraites dans le scratchpad :
`.../scratchpad/xlsx_probe/content/xl/media/imageN.png`.
Les copier vers `assets/plans/` (conserver les noms `image1.png` … `image18.png`).

- [ ] **Step 2: Créer `assets/seed/zones.json`**

Format : liste de plans ; chaque zone en coordonnées normalisées. Les positions ci-dessous
concernent la voiture repérée M–Y (image1, 960×221). Les autres plans sont livrés **sans
zones** (l'agent les ajoutera via l'éditeur) — c'est volontaire et conforme à l'approche
hybride. Ajouter/renommer se fait ensuite dans l'app.

```json
{
  "plans": [
    {
      "nom": "2N — Voiture (M–Y)",
      "image": "image1.png",
      "zones": [
        {"nom": "M", "x": 0.055, "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "N", "x": 0.27,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "O", "x": 0.35,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "P", "x": 0.44,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "Q", "x": 0.52,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "R", "x": 0.61,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "S", "x": 0.70,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "T", "x": 0.78,  "y": 0.24, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "U", "x": 0.27,  "y": 0.58, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "V", "x": 0.35,  "y": 0.58, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "W", "x": 0.44,  "y": 0.58, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "X", "x": 0.52,  "y": 0.58, "largeur": 0.045, "hauteur": 0.16},
        {"nom": "Y", "x": 0.61,  "y": 0.58, "largeur": 0.045, "hauteur": 0.16}
      ]
    },
    {"nom": "2N — Vue 2",  "image": "image2.png",  "zones": []},
    {"nom": "2N — Vue 3",  "image": "image3.png",  "zones": []},
    {"nom": "2N — Vue 4",  "image": "image4.png",  "zones": []},
    {"nom": "2N — Vue 5",  "image": "image5.png",  "zones": []},
    {"nom": "2N — Vue 6",  "image": "image6.png",  "zones": []},
    {"nom": "2N — Vue 7",  "image": "image7.png",  "zones": []},
    {"nom": "2N — Vue 8",  "image": "image8.png",  "zones": []},
    {"nom": "2N — Vue 9",  "image": "image9.png",  "zones": []},
    {"nom": "2N — Vue 10", "image": "image10.png", "zones": []},
    {"nom": "2N — Vue 11", "image": "image11.png", "zones": []},
    {"nom": "2N — Vue 12", "image": "image12.png", "zones": []},
    {"nom": "2N — Vue 13", "image": "image13.png", "zones": []},
    {"nom": "2N — Vue 14", "image": "image14.png", "zones": []},
    {"nom": "2N — Vue 15", "image": "image15.png", "zones": []},
    {"nom": "2N — Vue 16", "image": "image16.png", "zones": []},
    {"nom": "2N — Vue 17", "image": "image17.png", "zones": []},
    {"nom": "2N — Vue 18", "image": "image18.png", "zones": []}
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add assets
git commit -m "chore: assets des 18 plans + seed des zones (voiture M–Y)"
```

---

## Task 7 : Service de seed (premier lancement)

**Files:**
- Create: `lib/services/seed_service.dart`
- Test: `test/seed_service_test.dart`

**Interfaces:**
- Consumes: `PlanRepository`, `ZoneRepository`, `FileStorage`, assets.
- Produces: `SeedService(planRepo, zoneRepo, storage)` avec `Future<void> seedIfEmpty(String zonesJson, Future<List<int>> Function(String assetImage) loadAsset)` — si aucun plan en base, crée un plan par entrée du JSON (copie l'image d'asset dans `plans/`) et insère ses zones. Le chargement d'asset est injecté (testable sans bundle Flutter). Les IDs sont générés via `Uuid`.

- [ ] **Step 1: Test (échec)** — `test/seed_service_test.dart`

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/repositories/plan_repository.dart';
import 'package:tab_visite/data/repositories/zone_repository.dart';
import 'package:tab_visite/services/file_storage.dart';
import 'package:tab_visite/services/seed_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('seedIfEmpty crée plans + zones une seule fois', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_seed');
    final storage = FileStorage(root)..ensureDirs();
    final planRepo = PlanRepository(db);
    final service = SeedService(planRepo, ZoneRepository(db), storage);

    const json = '{"plans":[{"nom":"P1","image":"image1.png","zones":['
        '{"nom":"M","x":0.1,"y":0.2,"largeur":0.05,"hauteur":0.1}]}]}';
    Future<List<int>> loader(String a) async => [0, 1, 2];

    await service.seedIfEmpty(json, loader);
    await service.seedIfEmpty(json, loader); // 2e appel : no-op

    final plans = await planRepo.all();
    expect(plans.length, 1);
    expect(storage.resolve(plans.first.cheminImage).existsSync(), isTrue);
    root.deleteSync(recursive: true);
  });
}
```

- [ ] **Step 2: Lancer** — Expected: FAIL.

- [ ] **Step 3: Implémenter `lib/services/seed_service.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../data/models/plan.dart';
import '../data/models/zone.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import 'file_storage.dart';

class SeedService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final FileStorage storage;
  final Uuid _uuid = const Uuid();
  SeedService(this.planRepo, this.zoneRepo, this.storage);

  Future<void> seedIfEmpty(
      String zonesJson, Future<List<int>> Function(String asset) loadAsset) async {
    if ((await planRepo.all()).isNotEmpty) return;
    await storage.ensureDirs();

    final data = jsonDecode(zonesJson) as Map<String, Object?>;
    final plans = (data['plans'] as List).cast<Map<String, Object?>>();
    var ordre = 0;
    // NB: pas de Date.now() — dateCreation dérivée de l'ordre (déterministe).
    for (final entry in plans) {
      final bytes = await loadAsset(entry['image'] as String);
      final rel = 'plans/${_uuid.v4()}.png';
      final dest = storage.resolve(rel);
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(bytes);

      final planId = _uuid.v4();
      await planRepo.insert(Plan(
        id: planId,
        nom: entry['nom'] as String,
        cheminImage: rel,
        ordre: ordre,
        dateCreation: ordre,
      ));
      for (final z in (entry['zones'] as List).cast<Map<String, Object?>>()) {
        await zoneRepo.insert(Zone(
          id: _uuid.v4(),
          planId: planId,
          nom: z['nom'] as String,
          x: (z['x'] as num).toDouble(),
          y: (z['y'] as num).toDouble(),
          largeur: (z['largeur'] as num).toDouble(),
          hauteur: (z['hauteur'] as num).toDouble(),
          dateCreation: ordre,
        ));
      }
      ordre++;
    }
  }
}
```

- [ ] **Step 4: Lancer** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/seed_service.dart test/seed_service_test.dart
git commit -m "feat: SeedService — chargement initial des plans et zones"
```

---

## Task 8 : Bootstrap applicatif + injection de dépendances

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/services/app_context.dart`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: `AppContext` (regroupe `Database`, repositories, `FileStorage`) fourni via `provider`. `main()` : `WidgetsFlutterBinding.ensureInitialized()`, ouvre la DB dans le dossier app, construit `FileStorage(getApplicationDocumentsDirectory())`, lance `SeedService.seedIfEmpty` en chargeant `assets/seed/zones.json` + images via `rootBundle`, puis `runApp`.

- [ ] **Step 1: `lib/services/app_context.dart`**

```dart
import 'package:sqflite/sqflite.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import 'file_storage.dart';

class AppContext {
  final Database db;
  final FileStorage storage;
  late final PlanRepository plans = PlanRepository(db);
  late final ZoneRepository zones = ZoneRepository(db);
  late final PhotoRepository photos = PhotoRepository(db);
  AppContext(this.db, this.storage);
}
```

- [ ] **Step 2: `lib/main.dart`**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'app.dart';
import 'data/database.dart';
import 'services/app_context.dart';
import 'services/file_storage.dart';
import 'services/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(path: p.join(docs.path, 'tab_visite.db'));
  final storage = FileStorage(docs);
  await storage.ensureDirs();

  final ctx = AppContext(db, storage);
  final seed = SeedService(ctx.plans, ctx.zones, storage);
  final zonesJson = await rootBundle.loadString('assets/seed/zones.json');
  await seed.seedIfEmpty(zonesJson, (asset) async {
    final bytes = await rootBundle.load('assets/plans/$asset');
    return bytes.buffer.asUint8List();
  });

  runApp(Provider.value(value: ctx, child: const MyApp()));
}
```

- [ ] **Step 3: Vérifier** — Run: `flutter analyze` — Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/services/app_context.dart
git commit -m "feat: bootstrap app, AppContext, seed au démarrage"
```

---

## Task 9 : Écran d'accueil (liste des plans)

**Files:**
- Modify: `lib/ui/home/plans_screen.dart`
- Create: `lib/ui/widgets/date_format.dart`
- Test: `test/ui/plans_screen_test.dart`

**Interfaces:**
- Consumes: `AppContext` via provider, `PlanImportService` (créé ici, minimal).
- Produces: `PlansScreen` — liste des plans (nom + nb zones + nb photos), tap → `PlanViewScreen`, bouton *Ajouter un plan* (import image via `image_picker` galerie/fichier), bouton *Recherche* → `SearchScreen`. Helper `formatDateHeure(int epochMs)` → `'jj/mm/aaaa HH:mm'`.

- [ ] **Step 1: `lib/ui/widgets/date_format.dart`**

```dart
import 'package:intl/intl.dart';

String formatDate(int epochMs) =>
    DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(epochMs));

String formatHeure(int epochMs) =>
    DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(epochMs));

String formatDateHeure(int epochMs) => '${formatDate(epochMs)} ${formatHeure(epochMs)}';
```

- [ ] **Step 2: `lib/services/plan_import_service.dart`**

```dart
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../data/models/plan.dart';
import '../data/repositories/plan_repository.dart';
import 'file_storage.dart';

class PlanImportService {
  final PlanRepository planRepo;
  final FileStorage storage;
  final Uuid _uuid = const Uuid();
  PlanImportService(this.planRepo, this.storage);

  Future<Plan> importFromFile(File image, String nom, int nowMs) async {
    final ext = image.path.split('.').last.toLowerCase();
    final rel = await storage.importImage(image, 'plans', ext.isEmpty ? 'png' : ext);
    final plan = Plan(
      id: _uuid.v4(),
      nom: nom,
      cheminImage: rel,
      ordre: await planRepo.nextOrdre(),
      dateCreation: nowMs,
    );
    await planRepo.insert(plan);
    return plan;
  }
}
```

- [ ] **Step 3: `lib/ui/home/plans_screen.dart`** (version complète)

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../services/app_context.dart';
import '../../services/plan_import_service.dart';
import '../plan/plan_view_screen.dart';
import '../search/search_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<Plan> _plans = [];
  Map<String, int> _zoneCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plans = await ctx.plans.all();
    final counts = <String, int>{};
    for (final p in plans) {
      counts[p.id] = (await ctx.zones.forPlan(p.id)).length;
    }
    if (mounted) setState(() { _plans = plans; _zoneCounts = counts; });
  }

  Future<void> _ajouterPlan() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final nom = await _demanderNom();
    if (nom == null) return;
    await PlanImportService(ctx.plans, ctx.storage)
        .importFromFile(File(x.path), nom, DateTime.now().millisecondsSinceEpoch);
    await _load();
  }

  Future<String?> _demanderNom() async {
    final c = TextEditingController(text: 'Nouveau plan');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nom du plan'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans de visite'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher une zone',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterPlan,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Ajouter un plan'),
      ),
      body: _plans.isEmpty
          ? const Center(child: Text('Aucun plan'))
          : ListView.separated(
              itemCount: _plans.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final plan = _plans[i];
                return ListTile(
                  leading: SizedBox(
                    width: 64,
                    child: Image.file(ctx.storage.resolve(plan.cheminImage), fit: BoxFit.cover),
                  ),
                  title: Text(plan.nom),
                  subtitle: Text('${_zoneCounts[plan.id] ?? 0} zone(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PlanViewScreen(plan: plan)));
                    _load();
                  },
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 4: Widget test** — `test/ui/plans_screen_test.dart` (vérifie l'affichage d'une liste)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/file_storage.dart';
import 'package:tab_visite/ui/home/plans_screen.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  testWidgets('affiche les plans existants', (tester) async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_ui');
    final ctx = AppContext(db, FileStorage(root));
    await ctx.plans.insert(Plan(id: 'p1', nom: 'Voiture M–Y', cheminImage: 'plans/x.png', ordre: 0, dateCreation: 0));

    await tester.pumpWidget(Provider.value(
      value: ctx,
      child: const MaterialApp(home: PlansScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Voiture M–Y'), findsOneWidget);
    root.deleteSync(recursive: true);
  });
}
```

Note : l'image `plans/x.png` n'existant pas, `Image.file` affichera une erreur silencieuse en test ; le test ne vérifie que le texte. Acceptable.

- [ ] **Step 5: Lancer** — `flutter test test/ui/plans_screen_test.dart` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/home lib/ui/widgets lib/services/plan_import_service.dart test/ui/plans_screen_test.dart
git commit -m "feat: écran d'accueil (liste des plans, ajout, accès recherche)"
```

---

## Task 10 : Vue plan — zoom, ancrage des zones, prise/consultation photos

**Files:**
- Create: `lib/ui/plan/plan_view_screen.dart`, `lib/ui/plan/zone_overlay.dart`, `lib/ui/plan/zone_editor_controller.dart`
- Create: `lib/services/photo_capture_service.dart`
- Create: `lib/ui/zone/zone_sheet.dart`, `lib/ui/photo/photo_viewer.dart`

**Interfaces:**
- Consumes: `AppContext`, modèles, `formatDateHeure`.
- Produces: `PlanViewScreen(plan:)`. Utilise `InteractiveViewer` avec un `Stack` (image + `ZoneOverlay`). Mode édition via `ZoneEditorController`. Tap zone → `ZoneSheet`. `PhotoCaptureService.capture()` → `Photo`. `PhotoViewer(photo:)`.

- [ ] **Step 1: `lib/services/photo_capture_service.dart`**

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/models/photo.dart';
import '../data/repositories/photo_repository.dart';
import 'file_storage.dart';

class PhotoCaptureService {
  final PhotoRepository photoRepo;
  final FileStorage storage;
  final ImagePicker picker;
  final Uuid _uuid = const Uuid();
  PhotoCaptureService(this.photoRepo, this.storage, {ImagePicker? picker})
      : picker = picker ?? ImagePicker();

  /// Ouvre l'appareil photo, enregistre la photo et l'associe à [zoneId].
  /// Renvoie null si l'utilisateur annule.
  Future<Photo?> capture(String zoneId, int nowMs) async {
    final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return null;
    final rel = await storage.importImage(File(x.path), 'photos', 'jpg');
    final photo = Photo(
      id: _uuid.v4(),
      zoneId: zoneId,
      cheminFichier: rel,
      datePrise: nowMs,
      dateCreation: nowMs,
    );
    await photoRepo.insert(photo);
    return photo;
  }
}
```

- [ ] **Step 2: `lib/ui/plan/zone_editor_controller.dart`** (état d'édition)

```dart
import 'package:flutter/foundation.dart';

class ZoneEditorController extends ChangeNotifier {
  bool _editing = false;
  String? _selectedZoneId;

  bool get editing => _editing;
  String? get selectedZoneId => _selectedZoneId;

  void toggle() { _editing = !_editing; _selectedZoneId = null; notifyListeners(); }
  void select(String? id) { _selectedZoneId = id; notifyListeners(); }
}
```

- [ ] **Step 3: `lib/ui/plan/zone_overlay.dart`** (rendu des marqueurs, coordonnées normalisées → pixels)

```dart
import 'package:flutter/material.dart';
import '../../data/models/zone.dart';

/// Dessine les zones sur une surface de taille [size] (px), à partir de
/// coordonnées normalisées. Vert = a des photos, rouge = vide.
class ZoneOverlay extends StatelessWidget {
  final List<Zone> zones;
  final Size size;
  final Set<String> zonesAvecPhotos;
  final String? selectedId;
  final void Function(Zone) onTap;

  const ZoneOverlay({
    super.key,
    required this.zones,
    required this.size,
    required this.zonesAvecPhotos,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: zones.map((z) {
        final hasPhotos = zonesAvecPhotos.contains(z.id);
        final selected = z.id == selectedId;
        final color = hasPhotos ? Colors.green : Colors.red;
        return Positioned(
          left: z.x * size.width,
          top: z.y * size.height,
          width: z.largeur * size.width,
          height: z.hauteur * size.height,
          child: GestureDetector(
            onTap: () => onTap(z),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(hasPhotos ? 0.35 : 0.12),
                border: Border.all(
                    color: selected ? Colors.blue : color,
                    width: selected ? 3 : 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FittedBox(
                child: Text(z.nom,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: `lib/ui/photo/photo_viewer.dart`**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/photo.dart';
import '../../services/app_context.dart';
import '../widgets/date_format.dart';

class PhotoViewer extends StatelessWidget {
  final File file;
  final Photo photo;
  final Future<void> Function() onDelete;
  const PhotoViewer({super.key, required this.file, required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(formatDateHeure(photo.datePrise)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Supprimer',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer la photo ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
                  ],
                ),
              );
              if (ok == true) {
                await onDelete();
                if (context.mounted) Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(file),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `lib/ui/zone/zone_sheet.dart`** (galerie d'une zone)

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/photo.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../../services/photo_capture_service.dart';
import '../photo/photo_viewer.dart';
import '../widgets/date_format.dart';

class ZoneSheet extends StatefulWidget {
  final AppContext ctx;
  final Zone zone;
  const ZoneSheet({super.key, required this.ctx, required this.zone});

  @override
  State<ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends State<ZoneSheet> {
  List<Photo> _photos = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final photos = await widget.ctx.photos.forZone(widget.zone.id);
    if (mounted) setState(() => _photos = photos);
  }

  Future<void> _ajouterPhoto() async {
    final service = PhotoCaptureService(widget.ctx.photos, widget.ctx.storage);
    await service.capture(widget.zone.id, DateTime.now().millisecondsSinceEpoch);
    await _load();
  }

  Future<void> _ouvrir(Photo p) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhotoViewer(
        file: widget.ctx.storage.resolve(p.cheminFichier),
        photo: p,
        onDelete: () async {
          await widget.ctx.storage.deleteRelative(p.cheminFichier);
          await widget.ctx.photos.delete(p.id);
        },
      ),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('Zone ${widget.zone.nom}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _ajouterPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Ajouter une photo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _photos.isEmpty
                ? const Center(child: Text('Aucune photo pour cette zone'))
                : GridView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: _photos.length,
                    itemBuilder: (_, i) {
                      final p = _photos[i];
                      return GestureDetector(
                        onTap: () => _ouvrir(p),
                        child: GridTile(
                          footer: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.all(2),
                            child: Text(formatDateHeure(p.datePrise),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                textAlign: TextAlign.center),
                          ),
                          child: Image.file(
                              widget.ctx.storage.resolve(p.cheminFichier),
                              fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: `lib/ui/plan/plan_view_screen.dart`** (assemblage)

```dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../zone/zone_sheet.dart';
import 'zone_overlay.dart';
import 'zone_editor_controller.dart';

class PlanViewScreen extends StatefulWidget {
  final Plan plan;
  const PlanViewScreen({super.key, required this.plan});
  @override
  State<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends State<PlanViewScreen> {
  late final AppContext ctx = context.read<AppContext>();
  final ZoneEditorController editor = ZoneEditorController();
  List<Zone> _zones = [];
  Set<String> _avecPhotos = {};
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    editor.addListener(() => setState(() {}));
    _resolveImageSize();
    _load();
  }

  Future<void> _resolveImageSize() async {
    final file = ctx.storage.resolve(widget.plan.cheminImage);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _imageSize = Size(
          frame.image.width.toDouble(), frame.image.height.toDouble()));
    }
  }

  Future<void> _load() async {
    final zones = await ctx.zones.forPlan(widget.plan.id);
    final counts = await ctx.photos.countsForPlanZones(widget.plan.id);
    if (mounted) {
      setState(() {
        _zones = zones;
        _avecPhotos = counts.keys.toSet();
      });
    }
  }

  Future<void> _onTapZone(Zone z) async {
    if (editor.editing) {
      editor.select(z.id);
      _menuEdition(z);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ZoneSheet(ctx: ctx, zone: z),
    );
    _load();
  }

  Future<void> _menuEdition(Zone z) async {
    // Renommer / supprimer (déplacement/redimension : Task 11).
    await showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Renommer'),
          onTap: () async { Navigator.pop(context); await _renommer(z); },
        ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text('Supprimer la zone'),
          onTap: () async {
            Navigator.pop(context);
            await ctx.zones.delete(z.id);
            _load();
          },
        ),
      ]),
    ));
  }

  Future<void> _renommer(Zone z) async {
    final c = TextEditingController(text: z.nom);
    final nom = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Nom de la zone'),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
      ],
    ));
    if (nom != null && nom.isNotEmpty) {
      await ctx.zones.update(z.copyWith(nom: nom));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.nom),
        actions: [
          IconButton(
            icon: Icon(editor.editing ? Icons.check : Icons.edit_location_alt),
            tooltip: editor.editing ? 'Terminer l\'édition' : 'Mode édition',
            onPressed: editor.toggle,
          ),
        ],
      ),
      body: size == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              // Surface à ratio d'image, ancrage garanti par coords normalisées.
              final imgRatio = size.width / size.height;
              return InteractiveViewer(
                maxScale: 6,
                minScale: 0.5,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: imgRatio,
                    child: LayoutBuilder(builder: (context, box) {
                      final displaySize = Size(box.maxWidth, box.maxHeight);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(ctx.storage.resolve(widget.plan.cheminImage),
                              fit: BoxFit.fill),
                          ZoneOverlay(
                            zones: _zones,
                            size: displaySize,
                            zonesAvecPhotos: _avecPhotos,
                            selectedId: editor.selectedZoneId,
                            onTap: _onTapZone,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            }),
      floatingActionButton: editor.editing
          ? FloatingActionButton.extended(
              onPressed: _ajouterZone,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une zone'),
            )
          : null,
    );
  }

  Future<void> _ajouterZone() async {
    // Ajout au centre ; repositionnement en Task 11.
    final c = TextEditingController();
    final nom = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Nom de la nouvelle zone'),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
      ],
    ));
    if (nom == null || nom.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await ctx.zones.insert(Zone(
      id: const Uuid().v4(), planId: widget.plan.id, nom: nom,
      x: 0.45, y: 0.45, largeur: 0.1, hauteur: 0.1, dateCreation: now,
    ));
    _load();
  }
}
```

Ajouter en tête : `import 'package:uuid/uuid.dart';`.

- [ ] **Step 7: Vérifier** — Run: `flutter analyze` — Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/ui/plan lib/ui/zone lib/ui/photo lib/services/photo_capture_service.dart
git commit -m "feat: vue plan (zoom, zones ancrées), galerie zone, prise/consultation photos"
```

---

## Task 11 : Édition des zones — déplacement et redimensionnement

**Files:**
- Modify: `lib/ui/plan/zone_overlay.dart` (poignées draggables en mode édition)
- Modify: `lib/ui/plan/plan_view_screen.dart` (persistance des nouvelles positions)

**Interfaces:**
- Consumes: `ZoneOverlay`, `ZoneRepository.update`.
- Produces: en mode édition, chaque zone est déplaçable (drag du corps) et redimensionnable (drag du coin bas-droit) ; à la fin du geste, `Zone.copyWith` recalcule les coords normalisées et persiste.

- [ ] **Step 1: Étendre `ZoneOverlay`** — ajouter les paramètres d'édition

```dart
// Ajouter au constructeur :
//   final bool editing;
//   final void Function(Zone updated) onChanged;  // appelé en fin de geste
```

Remplacer le `child` de chaque `Positioned` par un widget qui, si `editing`, enveloppe le
conteneur dans un `GestureDetector` gérant `onPanUpdate` (déplacement) et une poignée de
redimensionnement :

```dart
Widget _buildZone(BuildContext context, Zone z, Color color, bool selected) {
  final body = Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withOpacity(0.25),
      border: Border.all(color: selected ? Colors.blue : color, width: selected ? 3 : 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: FittedBox(child: Text(z.nom, style: const TextStyle(fontWeight: FontWeight.bold))),
  );
  if (!editing) {
    return GestureDetector(onTap: () => onTap(z), child: body);
  }
  return GestureDetector(
    onTap: () => onTap(z),
    onPanUpdate: (d) {
      final nx = (z.x + d.delta.dx / size.width).clamp(0.0, 1.0 - z.largeur);
      final ny = (z.y + d.delta.dy / size.height).clamp(0.0, 1.0 - z.hauteur);
      onChanged(z.copyWith(x: nx, y: ny));
    },
    child: Stack(children: [
      Positioned.fill(child: body),
      Positioned(
        right: 0, bottom: 0,
        child: GestureDetector(
          onPanUpdate: (d) {
            final nw = (z.largeur + d.delta.dx / size.width).clamp(0.02, 1.0 - z.x);
            final nh = (z.hauteur + d.delta.dy / size.height).clamp(0.02, 1.0 - z.y);
            onChanged(z.copyWith(largeur: nw, hauteur: nh));
          },
          child: const Icon(Icons.open_in_full, size: 18, color: Colors.blue),
        ),
      ),
    ]),
  );
}
```

Dans `build`, remplacer la construction inline du child par `_buildZone(context, z, color, selected)`. (`onChanged` met à jour l'état local et persiste.)

- [ ] **Step 2: Câbler dans `plan_view_screen.dart`**

Passer à `ZoneOverlay` : `editing: editor.editing`, et
`onChanged: (updated) async { setState(() { final i = _zones.indexWhere((e) => e.id == updated.id); if (i >= 0) _zones[i] = updated; }); await ctx.zones.update(updated); }`.

Désactiver le pan de l'`InteractiveViewer` pendant l'édition d'une zone pour éviter les
conflits de geste : `InteractiveViewer(panEnabled: !editor.editing, scaleEnabled: !editor.editing, ...)`.

- [ ] **Step 3: Test de logique de repositionnement** — `test/zone_reposition_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/data/models/zone.dart';

void main() {
  test('déplacement borne x/y dans [0,1-taille]', () {
    var z = Zone(id: 'z', planId: 'p', nom: 'M', x: 0.9, y: 0.9, largeur: 0.2, hauteur: 0.2, dateCreation: 0);
    final nx = (z.x + 0.5).clamp(0.0, 1.0 - z.largeur);
    expect(nx, 0.8);
  });
}
```

- [ ] **Step 4: Lancer** — `flutter test test/zone_reposition_test.dart && flutter analyze` — Expected: PASS / No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/plan test/zone_reposition_test.dart
git commit -m "feat: édition des zones (déplacement, redimensionnement, persistance)"
```

---

## Task 12 : Recherche de zone

**Files:**
- Create: `lib/ui/search/search_screen.dart`

**Interfaces:**
- Consumes: `AppContext`, `ZoneRepository.searchByName`, `PlanRepository`.
- Produces: `SearchScreen` — champ de recherche ; résultats = zones correspondantes avec le nom de leur plan ; tap → ouvre le `PlanViewScreen` du plan concerné.

- [ ] **Step 1: `lib/ui/search/search_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/plan.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../plan/plan_view_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<Zone> _results = [];
  Map<String, Plan> _plansById = {};

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    final zones = await ctx.zones.searchByName(q.trim());
    final plans = await ctx.plans.all();
    setState(() {
      _results = zones;
      _plansById = { for (final p in plans) p.id : p };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Rechercher une zone (ex. M)…', border: InputBorder.none),
          onChanged: _search,
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final z = _results[i];
          final plan = _plansById[z.planId];
          return ListTile(
            leading: const Icon(Icons.place),
            title: Text('Zone ${z.nom}'),
            subtitle: Text(plan?.nom ?? ''),
            onTap: plan == null ? null : () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PlanViewScreen(plan: plan)),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Vérifier** — Run: `flutter analyze` — Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/search/search_screen.dart
git commit -m "feat: recherche de zone par nom (tous plans)"
```

---

## Task 13 : Export des photos (zip)

**Files:**
- Create: `lib/services/export_service.dart`
- Test: `test/export_service_test.dart`
- Modify: `lib/ui/plan/plan_view_screen.dart` (bouton Export)

**Interfaces:**
- Consumes: `PlanRepository`, `ZoneRepository`, `PhotoRepository`, `FileStorage`.
- Produces: `ExportService(...)` avec `Future<File> exportPlanToZip(String planId, Directory outDir)` — crée un zip contenant `PlanNom/ZoneNom/<date>_<id>.jpg`. `Future<File> exportAllToZip(Directory outDir)`. Le bouton UI appelle l'export puis `share_plus` pour partager le fichier.

- [ ] **Step 1: Test (échec)** — `test/export_service_test.dart`

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive_io.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/file_storage.dart';
import 'package:tab_visite/services/export_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('exportPlanToZip contient les photos', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_exp');
    final ctx = AppContext(db, FileStorage(root));
    await ctx.storage.ensureDirs();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Voiture', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    final photoFile = ctx.storage.resolve('photos/a.jpg')..createSync(recursive: true);
    photoFile.writeAsBytesSync([1, 2, 3]);
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/a.jpg', datePrise: 0, dateCreation: 0));

    final service = ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage);
    final zip = await service.exportPlanToZip('p1', root);
    expect(zip.existsSync(), isTrue);
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    expect(archive.files.any((f) => f.name.contains('Voiture') && f.name.contains('M')), isTrue);
    root.deleteSync(recursive: true);
  });
}
```

- [ ] **Step 2: Lancer** — Expected: FAIL.

- [ ] **Step 3: Implémenter `lib/services/export_service.dart`**

```dart
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import 'file_storage.dart';

class ExportService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final PhotoRepository photoRepo;
  final FileStorage storage;
  ExportService(this.planRepo, this.zoneRepo, this.photoRepo, this.storage);

  String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '_');

  Future<File> exportPlanToZip(String planId, Directory outDir) async {
    final plans = await planRepo.all();
    final plan = plans.firstWhere((p) => p.id == planId);
    final archive = Archive();
    for (final z in await zoneRepo.forPlan(planId)) {
      for (final ph in await photoRepo.forZone(z.id)) {
        final f = storage.resolve(ph.cheminFichier);
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        final name = '${_safe(plan.nom)}/${_safe(z.nom)}/${ph.datePrise}_${ph.id}.jpg';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }
    final out = File(p.join(outDir.path, 'export_${_safe(plan.nom)}.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }

  Future<File> exportAllToZip(Directory outDir) async {
    final archive = Archive();
    for (final plan in await planRepo.all()) {
      for (final z in await zoneRepo.forPlan(plan.id)) {
        for (final ph in await photoRepo.forZone(z.id)) {
          final f = storage.resolve(ph.cheminFichier);
          if (!f.existsSync()) continue;
          final bytes = f.readAsBytesSync();
          final name = '${_safe(plan.nom)}/${_safe(z.nom)}/${ph.datePrise}_${ph.id}.jpg';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }
    }
    final out = File(p.join(outDir.path, 'export_toutes_photos.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }
}
```

- [ ] **Step 4: Lancer** — Expected: PASS.

- [ ] **Step 5: Bouton Export dans `plan_view_screen.dart`** — ajouter une action AppBar

```dart
IconButton(
  icon: const Icon(Icons.folder_zip),
  tooltip: 'Exporter les photos',
  onPressed: () async {
    final dir = await getTemporaryDirectory();
    final zip = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .exportPlanToZip(widget.plan.id, dir);
    await Share.shareXFiles([XFile(zip.path)]);
  },
),
```

Imports : `package:path_provider/path_provider.dart`, `package:share_plus/share_plus.dart`,
`../../services/export_service.dart`.

- [ ] **Step 6: Vérifier** — `flutter analyze` — Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/export_service.dart test/export_service_test.dart lib/ui/plan/plan_view_screen.dart
git commit -m "feat: export des photos en zip + partage"
```

---

## Task 14 : Rapport PDF par plan

**Files:**
- Create: `lib/services/pdf_service.dart`
- Modify: `lib/ui/plan/plan_view_screen.dart` (bouton PDF)

**Interfaces:**
- Consumes: `PlanRepository`, `ZoneRepository`, `PhotoRepository`, `FileStorage`.
- Produces: `PdfService(...)` avec `Future<Uint8List> buildPlanReport(String planId)` — document : titre + image du plan, puis pour chaque zone son nom et ses photos avec date/heure. Le bouton UI utilise `Printing.sharePdf`/`layoutPdf`.

- [ ] **Step 1: Implémenter `lib/services/pdf_service.dart`**

```dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import '../services/file_storage.dart';
import '../ui/widgets/date_format.dart';

class PdfService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final PhotoRepository photoRepo;
  final FileStorage storage;
  PdfService(this.planRepo, this.zoneRepo, this.photoRepo, this.storage);

  Future<Uint8List> buildPlanReport(String planId) async {
    final plans = await planRepo.all();
    final plan = plans.firstWhere((p) => p.id == planId);
    final doc = pw.Document();

    final planImg = pw.MemoryImage(storage.resolve(plan.cheminImage).readAsBytesSync());
    final zones = await zoneRepo.forPlan(planId);

    final widgets = <pw.Widget>[
      pw.Header(level: 0, child: pw.Text('Rapport de visite — ${plan.nom}')),
      pw.Center(child: pw.Image(planImg, height: 180)),
      pw.SizedBox(height: 12),
    ];

    for (final z in zones) {
      final photos = await photoRepo.forZone(z.id);
      widgets.add(pw.Header(level: 1, child: pw.Text('Zone ${z.nom}')));
      if (photos.isEmpty) {
        widgets.add(pw.Text('Aucune photo', style: const pw.TextStyle(fontSize: 10)));
      } else {
        widgets.add(pw.Wrap(spacing: 8, runSpacing: 8, children: photos.map((ph) {
          final img = pw.MemoryImage(storage.resolve(ph.cheminFichier).readAsBytesSync());
          return pw.Column(children: [
            pw.Image(img, width: 150, height: 110, fit: pw.BoxFit.cover),
            pw.Text(formatDateHeure(ph.datePrise), style: const pw.TextStyle(fontSize: 8)),
          ]);
        }).toList()));
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => widgets,
    ));
    return doc.save();
  }
}
```

- [ ] **Step 2: Bouton PDF dans `plan_view_screen.dart`**

```dart
IconButton(
  icon: const Icon(Icons.picture_as_pdf),
  tooltip: 'Rapport PDF',
  onPressed: () async {
    final bytes = await PdfService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .buildPlanReport(widget.plan.id);
    await Printing.sharePdf(bytes: bytes, filename: 'rapport_${widget.plan.nom}.pdf');
  },
),
```

Imports : `package:printing/printing.dart`, `../../services/pdf_service.dart`.

- [ ] **Step 3: Vérifier** — `flutter analyze` — Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/services/pdf_service.dart lib/ui/plan/plan_view_screen.dart
git commit -m "feat: rapport PDF par plan (plan + photos par zone)"
```

---

## Task 15 : Suppression de plan + finitions

**Files:**
- Modify: `lib/ui/home/plans_screen.dart` (appui long → supprimer un plan, avec ses fichiers)

**Interfaces:**
- Consumes: `PlanRepository.delete` (cascade zones/photos en base), `FileStorage` (supprimer les fichiers photos + image du plan).

- [ ] **Step 1: Ajouter la suppression dans `plans_screen.dart`**

Sur chaque `ListTile`, ajouter `onLongPress` qui demande confirmation, récupère toutes les
photos des zones du plan pour supprimer leurs fichiers, supprime l'image du plan, puis
`ctx.plans.delete(plan.id)` (cascade en base), puis `_load()` :

```dart
onLongPress: () async {
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
    title: Text('Supprimer « ${plan.nom} » ?'),
    content: const Text('Le plan et toutes ses photos seront supprimés.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
    ],
  ));
  if (ok != true) return;
  for (final z in await ctx.zones.forPlan(plan.id)) {
    for (final ph in await ctx.photos.forZone(z.id)) {
      await ctx.storage.deleteRelative(ph.cheminFichier);
    }
  }
  await ctx.storage.deleteRelative(plan.cheminImage);
  await ctx.plans.delete(plan.id);
  _load();
},
```

- [ ] **Step 2: Vérifier** — `flutter analyze` — Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/home/plans_screen.dart
git commit -m "feat: suppression d'un plan et de ses fichiers"
```

---

## Task 16 : Vérification finale + documentation de livraison

**Files:**
- Create: `README.md` (installation, build GitHub, installation APK sur tablette)

- [ ] **Step 1: Lancer toute la suite** — Run: `flutter test && flutter analyze` — Expected: tous PASS, No issues.

- [ ] **Step 2: `README.md`**

Documenter : (a) créer un dépôt GitHub et y pousser le dossier ; (b) l'onglet *Actions*
génère l'APK (artefact `tab-visite-apk`) ; (c) télécharger l'APK, l'envoyer sur la tablette,
activer *Sources inconnues*, installer ; (d) au 1er lancement les plans 2N sont chargés ;
(e) utilisation (tap zone vide = photo, zone verte = galerie, mode édition, recherche,
export, PDF).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: guide d'installation et de build (GitHub Actions, tablette)"
```

---

## Self-Review (couverture de la spec)

| Exigence de la spec | Tâche(s) |
|---------------------|----------|
| Affichage plan plein écran | 10 |
| Zoom deux doigts + déplacement | 10 |
| Zones ancrées au zoom (coords normalisées) | 6, 10 |
| Zones cliquables / hybride (pré-remplies + éditeur) | 6, 7, 10, 11 |
| Tap zone vide → appareil photo → enregistrement + association | 10 |
| Tap zone avec photos → galerie (Ajouter/Voir/Supprimer) | 10 |
| Plusieurs photos par zone | 4, 10 |
| Persistance après fermeture | 3, 5, 8 |
| Données zone : nom, date, heure, chemin photo | 2, 3 |
| Plusieurs plans | 6, 7, 9 |
| Recherche de zone | 4, 12 |
| Export des photos vers dossier/zip | 13 |
| Rapport PDF plan + photos | 14 |
| Hors-ligne, Android 10+ | 1 (minSdk 29), global |
| Livraison APK via GitHub Actions | 1, 16 |

Aucune exigence sans tâche. Types cohérents entre tâches (`Zone.copyWith`, `countsForPlanZones`, `FileStorage.resolve`, `AppContext` réutilisés tels que définis).
