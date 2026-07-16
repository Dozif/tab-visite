import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';

/// Vérifie que la migration v4 -> v5 crée la table `pending_capture` sans
/// toucher aux données existantes.
/// Utilise un fichier réel (une base « en mémoire » ne survit pas à la fermeture).
void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('migration v4->v5 crée la table pending_capture', () async {
    final dir = Directory.systemTemp.createTempSync('tv_mig5');
    final path = p.join(dir.path, 'test.db');

    // 1) Crée une base au schéma v4 (avant la table pending_capture).
    final db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(version: 4, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE plans(id TEXT PRIMARY KEY, nom TEXT NOT NULL, chemin_image TEXT NOT NULL, ordre INTEGER NOT NULL, date_creation INTEGER NOT NULL, categorie TEXT, serie TEXT)');
      await db.execute(
          'CREATE TABLE zones(id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, nom TEXT NOT NULL, x REAL, y REAL, largeur REAL, hauteur REAL, date_creation INTEGER NOT NULL, image_reference TEXT)');
      await db.execute(
          "CREATE TABLE visites(id TEXT PRIMARY KEY, numero_rame INTEGER NOT NULL, type_visite TEXT NOT NULL, niveau TEXT NOT NULL DEFAULT '2N', date_visite INTEGER NOT NULL, date_creation INTEGER NOT NULL)");
      await db.execute(
          'CREATE TABLE photos(id TEXT PRIMARY KEY, zone_id TEXT NOT NULL, chemin_fichier TEXT NOT NULL, date_prise INTEGER NOT NULL, date_creation INTEGER NOT NULL, visite_id TEXT, traitee INTEGER NOT NULL DEFAULT 0)');
    }));
    await db.insert('plans', {'id': 'm1', 'nom': 'Motrice', 'chemin_image': 'a', 'ordre': 0, 'date_creation': 0});
    await db.close();

    // 2) Rouvre via AppDatabase.open (v5) -> onUpgrade se déclenche.
    final db2 = await AppDatabase.open(path: path);

    // La table pending_capture existe.
    final tables = await db2.query('sqlite_master',
        where: "type = 'table' AND name = 'pending_capture'");
    expect(tables.length, 1);

    // Elle est utilisable (insert/lecture) et le plan existant est préservé.
    await db2.insert('pending_capture',
        {'zone_id': 'z1', 'visite_id': 'v1', 'date': 123});
    final rows = await db2.query('pending_capture');
    expect(rows.length, 1);
    expect(rows.first['zone_id'], 'z1');
    expect((await db2.query('plans')).length, 1);
    await db2.close();

    dir.deleteSync(recursive: true);
  });

  test('création directe en v5 inclut pending_capture', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final tables = await db.query('sqlite_master',
        where: "type = 'table' AND name = 'pending_capture'");
    expect(tables.length, 1);
    await db.close();
  });
}
