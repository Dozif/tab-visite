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
