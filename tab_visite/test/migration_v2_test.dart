import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';

/// Vérifie que la migration v1 -> v2 préserve les données existantes et
/// renseigne catégorie/série des plans déjà présents.
/// Utilise un fichier réel (une base « en mémoire » ne survit pas à la fermeture).
void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('migration v1->v2 ajoute colonnes/table et classe les plans', () async {
    final dir = Directory.systemTemp.createTempSync('tv_mig');
    final path = p.join(dir.path, 'test.db');

    // 1) Crée une base au schéma v1 avec un plan Motrice et un plan Remorque.
    final db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE plans(id TEXT PRIMARY KEY, nom TEXT NOT NULL, chemin_image TEXT NOT NULL, ordre INTEGER NOT NULL, date_creation INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE zones(id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, nom TEXT NOT NULL, x REAL, y REAL, largeur REAL, hauteur REAL, date_creation INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE photos(id TEXT PRIMARY KEY, zone_id TEXT NOT NULL, chemin_fichier TEXT NOT NULL, date_prise INTEGER NOT NULL, date_creation INTEGER NOT NULL)');
    }));
    await db.insert('plans', {'id': 'm1', 'nom': 'Motrice (Droit-Pair) M1', 'chemin_image': 'a', 'ordre': 0, 'date_creation': 0});
    await db.insert('plans', {'id': 'r1', 'nom': 'Remorque (Droit-Pair) R1', 'chemin_image': 'b', 'ordre': 1, 'date_creation': 0});
    await db.close();

    // 2) Rouvre via AppDatabase.open (v2) -> onUpgrade se déclenche.
    final db2 = await AppDatabase.open(path: path);

    // La table visites existe.
    final tables = await db2.query('sqlite_master',
        where: "type = 'table' AND name = 'visites'");
    expect(tables.length, 1);

    // Les plans existants sont préservés, classés (déduit du nom) et en série 2N.
    final m = (await db2.query('plans', where: 'id = ?', whereArgs: ['m1'])).first;
    final r = (await db2.query('plans', where: 'id = ?', whereArgs: ['r1'])).first;
    expect(m['categorie'], 'motrice');
    expect(r['categorie'], 'remorque');
    expect(m['serie'], '2N');

    // Les colonnes photos existent (insert avec visite_id + traitee).
    await db2.insert('visites', {'id': 'v1', 'numero_rame': 1, 'type_visite': 'MKBAM', 'date_visite': 0, 'date_creation': 0});
    await db2.insert('zones', {'id': 'z1', 'plan_id': 'm1', 'nom': 'M', 'x': 0.0, 'y': 0.0, 'largeur': 0.1, 'hauteur': 0.1, 'date_creation': 0});
    await db2.insert('photos', {'id': 'f1', 'zone_id': 'z1', 'chemin_fichier': 'p.jpg', 'date_prise': 0, 'date_creation': 0, 'visite_id': 'v1', 'traitee': 1});
    final ph = (await db2.query('photos', where: 'id = ?', whereArgs: ['f1'])).first;
    expect(ph['traitee'], 1);
    expect(ph['visite_id'], 'v1');
    await db2.close();

    dir.deleteSync(recursive: true);
  });
}
