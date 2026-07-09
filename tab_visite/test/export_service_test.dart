import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive_io.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/file_storage.dart';
import 'package:tab_visite/services/export_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

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
    root.deleteSync(recursive: true);
  });
}
