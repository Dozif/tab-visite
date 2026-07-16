import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/visite.dart';
import 'package:tab_visite/data/repositories/visite_repository.dart';
import 'package:tab_visite/ui/home/nouvelle_visite_sheet.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('une visite par type coché, ordre canonique MKBAM->MKBDR->MKBAR', () {
    var n = 0;
    final visites = construireVisitesGroupees(
        {TypeVisite.mkbar, TypeVisite.mkbam}, Niveau.un, 12, 1000,
        nouvelId: () => 'id${n++}');

    // Ordre canonique quel que soit l'ordre de sélection.
    expect(visites.map((v) => v.typeVisite).toList(),
        [TypeVisite.mkbam, TypeVisite.mkbar]);
    // Ids distincts, rame/niveau/dates partagés.
    expect(visites.map((v) => v.id).toSet().length, 2);
    for (final v in visites) {
      expect(v.numeroRame, 12);
      expect(v.niveau, Niveau.un);
      expect(v.dateVisite, 1000);
      expect(v.dateCreation, 1000);
    }
  });

  test('les 3 types cochés -> 3 visites', () {
    var n = 0;
    final visites = construireVisitesGroupees(
        {TypeVisite.mkbam, TypeVisite.mkbdr, TypeVisite.mkbar},
        Niveau.deux, 5, 0,
        nouvelId: () => 'id${n++}');
    expect(visites.length, 3);
    expect(visites.map((v) => v.typeVisite).toList(),
        [TypeVisite.mkbam, TypeVisite.mkbdr, TypeVisite.mkbar]);
  });

  test('un seul type -> une seule visite', () {
    final visites = construireVisitesGroupees(
        {TypeVisite.mkbdr}, Niveau.deux, 7, 0,
        nouvelId: () => 'x');
    expect(visites.length, 1);
    expect(visites.first.typeVisite, TypeVisite.mkbdr);
  });

  test('insertion en base des visites groupées (bout en bout)', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);
    final repo = VisiteRepository(db);
    var n = 0;
    final visites = construireVisitesGroupees(
        {TypeVisite.mkbam, TypeVisite.mkbdr}, Niveau.deux, 9, 100,
        nouvelId: () => 'id${n++}');
    for (final v in visites) {
      await repo.insert(v);
    }
    final toutes = await repo.forRame(9);
    expect(toutes.length, 2);
    expect(toutes.map((v) => v.typeVisite).toSet(),
        {TypeVisite.mkbam, TypeVisite.mkbdr});
  });
}
