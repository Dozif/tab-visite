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
