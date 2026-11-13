import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path/path.dart' as p;
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';
import 'package:tab_visite/data/models/visite.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/photo_store_io.dart';
import 'package:tab_visite/services/export_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('exportVisiteToZip : photos + data.xlsx', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_expv');
    final ctx = AppContext(db, PhotoStoreIo(root));
    await ctx.storage.ensureReady();

    await ctx.visites.insert(Visite(
        id: 'v1', numeroRame: 3, typeVisite: TypeVisite.mkbdr,
        niveau: Niveau.deux, dateVisite: 0, dateCreation: 0));
    await ctx.plans.insert(Plan(id: 'p1', nom: 'Remorque R3', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'R3 D1', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    File(p.join(root.path, 'plans/p.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([7, 7]);
    File(p.join(root.path, 'photos/a.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/a.jpg', datePrise: 0, dateCreation: 0, visiteId: 'v1'));

    final res = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .exportVisiteToZip((await ctx.visites.all()).first);
    expect(res.filename.endsWith('.zip'), isTrue);
    final archive = ZipDecoder().decodeBytes(res.bytes);
    // La photo est rangée sous photos/<plan>/<zone>/...
    expect(archive.files.any((f) =>
        f.name.startsWith('photos/Remorque R3/R3 D1/')), isTrue);
    // Le récap Excel existe et contient l'en-tête + 1 ligne photo.
    final data = archive.files.firstWhere((f) => f.name == 'data.xlsx');
    final book = xls.Excel.decodeBytes(data.content as List<int>);
    final rows = book.tables['Photos']!.rows;
    expect(rows.length, 2);
    // 16 colonnes : 11 historiques + dessin et position du point.
    final entetes = rows.first.map((c) => c?.value.toString()).toList();
    expect(entetes.length, 16);
    expect(entetes.sublist(11),
        ['Fichier dessin', 'Zone X', 'Zone Y', 'Zone largeur', 'Zone hauteur']);
    final ligne = rows[1].map((c) => c?.value.toString()).toList();
    expect(ligne.sublist(11), ['dessins/p1.png', '0.0', '0.0', '0.1', '0.1']);
    // Le dessin est dans le ZIP.
    final dessin = archive.files.firstWhere((f) => f.name == 'dessins/p1.png');
    expect(dessin.content, [7, 7]);
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('exportAllVisitesToZip : chemins préfixés par visite, sans collision', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_expall');
    final ctx = AppContext(db, PhotoStoreIo(root));
    await ctx.storage.ensureReady();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Rem', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'D1', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    for (final r in [1, 2]) {
      await ctx.visites.insert(Visite(id: 'v$r', numeroRame: r, typeVisite: TypeVisite.mkbdr, niveau: Niveau.deux, dateVisite: r, dateCreation: r));
      File(p.join(root.path, 'photos/p$r.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([r]);
      await ctx.photos.insert(Photo(id: 'f$r', zoneId: 'z1', cheminFichier: 'photos/p$r.jpg', datePrise: r, dateCreation: r, visiteId: 'v$r'));
    }

    final res = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .exportAllVisitesToZip();
    final archive = ZipDecoder().decodeBytes(res.bytes);
    final photos = archive.files.map((f) => f.name).where((n) => n.startsWith('photos/')).toList();
    expect(photos.length, 2);
    expect(photos.any((n) => n.startsWith('photos/R1_MKBDR_2N/')), isTrue);
    expect(photos.any((n) => n.startsWith('photos/R2_MKBDR_2N/')), isTrue);
    // Dessin absent du stockage : pas d'entrée, colonne vide, export OK.
    expect(archive.files.where((f) => f.name.startsWith('dessins/')), isEmpty);
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('exportAllVisitesToZip : un seul dessin pour plusieurs photos du même plan', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_expdes');
    final ctx = AppContext(db, PhotoStoreIo(root));
    await ctx.storage.ensureReady();
    await ctx.plans.insert(Plan(id: 'p1', nom: 'Rem', cheminImage: 'plans/p.jpg', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'D1', x: .25, y: .5, largeur: .03, hauteur: .07, dateCreation: 0));
    File(p.join(root.path, 'plans/p.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([5]);
    for (final r in [1, 2]) {
      await ctx.visites.insert(Visite(id: 'v$r', numeroRame: r, typeVisite: TypeVisite.mkbdr, niveau: Niveau.deux, dateVisite: r, dateCreation: r));
      File(p.join(root.path, 'photos/p$r.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([r]);
      await ctx.photos.insert(Photo(id: 'f$r', zoneId: 'z1', cheminFichier: 'photos/p$r.jpg', datePrise: r, dateCreation: r, visiteId: 'v$r'));
    }
    final res = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .exportAllVisitesToZip();
    final archive = ZipDecoder().decodeBytes(res.bytes);
    expect(archive.files.where((f) => f.name.startsWith('dessins/')).map((f) => f.name).toList(),
        ['dessins/p1.jpg']);
    final book = xls.Excel.decodeBytes(
        archive.files.firstWhere((f) => f.name == 'data.xlsx').content as List<int>);
    final ligne = book.tables['Photos']!.rows[1].map((c) => c?.value.toString()).toList();
    expect(ligne.sublist(11), ['dessins/p1.jpg', '0.25', '0.5', '0.03', '0.07']);
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('exportPlanToZip contient les photos', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_exp');
    final ctx = AppContext(db, PhotoStoreIo(root));
    await ctx.storage.ensureReady();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Voiture', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    File(p.join(root.path, 'photos/a.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/a.jpg', datePrise: 0, dateCreation: 0));

    final service = ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage);
    final res = await service.exportPlanToZip('p1');
    expect(res.filename.endsWith('.zip'), isTrue);
    final archive = ZipDecoder().decodeBytes(res.bytes);
    expect(archive.files.any((f) => f.name.contains('Voiture') && f.name.contains('M')), isTrue);
    await db.close();
    root.deleteSync(recursive: true);
  });
}
