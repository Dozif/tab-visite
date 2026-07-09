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
