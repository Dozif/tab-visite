import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/visite.dart';
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

  test('forTypeVisite filtre par catégorie et niveau (série)', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = PlanRepository(db);
    await repo.insert(Plan(id: 'm1', nom: 'Motrice M1', cheminImage: 'a', ordre: 0, dateCreation: 0, categorie: 'motrice', serie: '2N'));
    await repo.insert(Plan(id: 'm2', nom: 'Motrice 1N M1', cheminImage: 'a1', ordre: 4, dateCreation: 0, categorie: 'motrice', serie: '1N'));
    await repo.insert(Plan(id: 'r1', nom: 'Remorque R1', cheminImage: 'b', ordre: 1, dateCreation: 0, categorie: 'remorque', serie: '2N'));
    await repo.insert(Plan(id: 'r2', nom: 'Remorque R2', cheminImage: 'c', ordre: 2, dateCreation: 0, categorie: 'remorque', serie: '2N'));
    await repo.insert(Plan(id: 'x1', nom: 'Remorque autre', cheminImage: 'd', ordre: 3, dateCreation: 0, categorie: 'remorque', serie: 'AUTRE'));

    // MKBAM filtre les motrices de la série choisie (niveau).
    expect((await repo.forTypeVisite(TypeVisite.mkbam, Niveau.deux)).map((p) => p.id).toList(), ['m1']);
    expect((await repo.forTypeVisite(TypeVisite.mkbam, Niveau.un)).map((p) => p.id).toList(), ['m2']);
    // MKBDR filtre les remorques de la série choisie.
    expect((await repo.forTypeVisite(TypeVisite.mkbdr, Niveau.deux)).map((p) => p.id).toList(), ['r1', 'r2']);
    // MKBAR (legacy) : remorques d'une autre série, indépendant du niveau.
    expect((await repo.forTypeVisite(TypeVisite.mkbar, Niveau.deux)).map((p) => p.id).toList(), ['x1']);
    await db.close();
  });
}
