import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';

/// v5 -> v6 : table `reglages` créée, données existantes préservées.
void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('migration v5->v6 crée la table reglages', () async {
    final dir = Directory.systemTemp.createTempSync('tv_mig6');
    final path = p.join(dir.path, 'test.db');
    final db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(version: 5, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE plans(id TEXT PRIMARY KEY, nom TEXT NOT NULL, chemin_image TEXT NOT NULL, ordre INTEGER NOT NULL, date_creation INTEGER NOT NULL, categorie TEXT, serie TEXT)');
    }));
    await db.insert('plans', {'id': 'm1', 'nom': 'Motrice', 'chemin_image': 'a', 'ordre': 0, 'date_creation': 0});
    await db.close();

    final db2 = await AppDatabase.open(path: path);
    await db2.insert('reglages', {'cle': 'k', 'valeur': 'v'});
    expect((await db2.query('reglages')).single['valeur'], 'v');
    expect((await db2.query('plans')).length, 1);
    await db2.close();
    dir.deleteSync(recursive: true);
  });
}
