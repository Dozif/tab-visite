import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart' as xls;
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';
import 'package:tab_visite/data/models/visite.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/file_storage.dart';
import 'package:tab_visite/services/export_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('exportVisiteToZip : photos + data.xlsx', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_expv');
    final ctx = AppContext(db, FileStorage(root));
    await ctx.storage.ensureDirs();

    await ctx.visites.insert(Visite(
        id: 'v1', numeroRame: 3, typeVisite: TypeVisite.mkbdr,
        niveau: Niveau.deux, dateVisite: 0, dateCreation: 0));
    await ctx.plans.insert(Plan(id: 'p1', nom: 'Remorque R3', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'R3 D1', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    final photoFile = ctx.storage.resolve('photos/a.jpg')..createSync(recursive: true);
    photoFile.writeAsBytesSync([1, 2, 3]);
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/a.jpg', datePrise: 0, dateCreation: 0, visiteId: 'v1'));

    final zip = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .exportVisiteToZip(
            (await ctx.visites.all()).first, root);
    expect(zip.existsSync(), isTrue);
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    // La photo est rangée sous photos/<plan>/<zone>/...
    expect(archive.files.any((f) =>
        f.name.startsWith('photos/Remorque R3/R3 D1/')), isTrue);
    // Le récap Excel existe et contient l'en-tête + 1 ligne photo.
    final data = archive.files.firstWhere((f) => f.name == 'data.xlsx');
    final book = xls.Excel.decodeBytes(data.content as List<int>);
    final rows = book.tables['Photos']!.rows;
    expect(rows.length, 2);
    // 11 colonnes attendues (9 + Visite ID + Photo ID).
    expect(book.tables['Photos']!.rows.first.length, 11);
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('exportAllVisitesToZip : chemins préfixés par visite, sans collision', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_expall');
    final ctx = AppContext(db, FileStorage(root));
    await ctx.storage.ensureDirs();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Rem', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'D1', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    for (final r in [1, 2]) {
      await ctx.visites.insert(Visite(id: 'v$r', numeroRame: r, typeVisite: TypeVisite.mkbdr, niveau: Niveau.deux, dateVisite: r, dateCreation: r));
      final f = ctx.storage.resolve('photos/p$r.jpg')..createSync(recursive: true);
      f.writeAsBytesSync([r]);
      await ctx.photos.insert(Photo(id: 'f$r', zoneId: 'z1', cheminFichier: 'photos/p$r.jpg', datePrise: r, dateCreation: r, visiteId: 'v$r'));
    }

    final zip = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
        .exportAllVisitesToZip(root);
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    final photos = archive.files.map((f) => f.name).where((n) => n.startsWith('photos/')).toList();
    expect(photos.length, 2);
    expect(photos.any((n) => n.startsWith('photos/R1_MKBDR_2N/')), isTrue);
    expect(photos.any((n) => n.startsWith('photos/R2_MKBDR_2N/')), isTrue);
    await db.close();
    root.deleteSync(recursive: true);
  });

  test('exportPlanToZip contient les photos', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_exp');
    final ctx = AppContext(db, FileStorage(root));
    await ctx.storage.ensureDirs();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Voiture', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    final photoFile = ctx.storage.resolve('photos/a.jpg')..createSync(recursive: true);
    photoFile.writeAsBytesSync([1, 2, 3]);
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/a.jpg', datePrise: 0, dateCreation: 0));

    final service = ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage);
    final zip = await service.exportPlanToZip('p1', root);
    expect(zip.existsSync(), isTrue);
    final archive = ZipDecoder().decodeBytes(zip.readAsBytesSync());
    expect(archive.files.any((f) => f.name.contains('Voiture') && f.name.contains('M')), isTrue);
    await db.close();
    root.deleteSync(recursive: true);
  });
}
