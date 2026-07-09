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
