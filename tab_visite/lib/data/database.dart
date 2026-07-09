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
