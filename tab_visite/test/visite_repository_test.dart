import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/visite.dart';
import 'package:tab_visite/data/repositories/visite_repository.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('insert, all (récentes d\'abord), forRame', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = VisiteRepository(db);
    await repo.insert(Visite(id: 'v1', numeroRame: 384, typeVisite: TypeVisite.mkbam, dateVisite: 100, dateCreation: 0));
    await repo.insert(Visite(id: 'v2', numeroRame: 384, typeVisite: TypeVisite.mkbdr, dateVisite: 300, dateCreation: 0));
    await repo.insert(Visite(id: 'v3', numeroRame: 512, typeVisite: TypeVisite.mkbdr, dateVisite: 200, dateCreation: 0));

    final all = await repo.all();
    expect(all.map((v) => v.id).toList(), ['v2', 'v3', 'v1']); // tri date_visite desc

    final rame384 = await repo.forRame(384);
    expect(rame384.map((v) => v.id).toList(), ['v2', 'v1']); // 2 visites, récente d'abord
    await db.close();
  });

  test('Visite round-trip map', () {
    final v = Visite(id: 'v', numeroRame: 42, typeVisite: TypeVisite.mkbar, dateVisite: 9, dateCreation: 1);
    final back = Visite.fromMap(v.toMap());
    expect(back.numeroRame, 42);
    expect(back.typeVisite, 'MKBAR');
    expect(back.dateVisite, 9);
  });
}
