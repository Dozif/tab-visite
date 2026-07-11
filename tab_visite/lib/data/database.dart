import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Future<Database> open({String? path}) async {
    return openDatabase(
      path ?? 'tab_visite.db',
      version: 3,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plans(
            id TEXT PRIMARY KEY,
            nom TEXT NOT NULL,
            chemin_image TEXT NOT NULL,
            ordre INTEGER NOT NULL,
            date_creation INTEGER NOT NULL,
            categorie TEXT,
            serie TEXT
          )''');
        await db.execute('''
          CREATE TABLE zones(
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            nom TEXT NOT NULL,
            x REAL NOT NULL, y REAL NOT NULL,
            largeur REAL NOT NULL, hauteur REAL NOT NULL,
            date_creation INTEGER NOT NULL,
            image_reference TEXT,
            FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE CASCADE
          )''');
        await db.execute('''
          CREATE TABLE visites(
            id TEXT PRIMARY KEY,
            numero_rame INTEGER NOT NULL,
            type_visite TEXT NOT NULL,
            date_visite INTEGER NOT NULL,
            date_creation INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE photos(
            id TEXT PRIMARY KEY,
            zone_id TEXT NOT NULL,
            chemin_fichier TEXT NOT NULL,
            date_prise INTEGER NOT NULL,
            date_creation INTEGER NOT NULL,
            visite_id TEXT,
            traitee INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(zone_id) REFERENCES zones(id) ON DELETE CASCADE,
            FOREIGN KEY(visite_id) REFERENCES visites(id) ON DELETE CASCADE
          )''');
        await db.execute('CREATE INDEX idx_zones_plan ON zones(plan_id)');
        await db.execute('CREATE INDEX idx_photos_zone ON photos(zone_id)');
        await db.execute('CREATE INDEX idx_photos_visite ON photos(visite_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2 : notion de visite (dossier par rame), catégories de plans,
        // rattachement des photos à une visite + statut « traité ».
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE plans ADD COLUMN categorie TEXT');
          await db.execute('ALTER TABLE plans ADD COLUMN serie TEXT');
          await db.execute('''
            CREATE TABLE visites(
              id TEXT PRIMARY KEY,
              numero_rame INTEGER NOT NULL,
              type_visite TEXT NOT NULL,
              date_visite INTEGER NOT NULL,
              date_creation INTEGER NOT NULL
            )''');
          await db.execute('ALTER TABLE photos ADD COLUMN visite_id TEXT');
          await db.execute(
              'ALTER TABLE photos ADD COLUMN traitee INTEGER NOT NULL DEFAULT 0');
          await db.execute('CREATE INDEX idx_photos_visite ON photos(visite_id)');
          // Renseigne catégorie/série des plans déjà seedés (déduits du nom).
          await db.execute('''
            UPDATE plans SET
              categorie = CASE WHEN nom LIKE 'Motrice%' THEN 'motrice' ELSE 'remorque' END,
              serie = '2N' ''');
        }
        // v2 -> v3 : image de référence par zone (point de corrosion).
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE zones ADD COLUMN image_reference TEXT');
        }
      },
    );
  }
}
