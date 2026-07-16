import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';
import 'package:tab_visite/data/models/visite.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/photo_store_io.dart';
import 'package:tab_visite/services/reset_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('clearVisitesEtPhotos supprime visites+photos+blobs, garde les plans', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_reset');
    final ctx = AppContext(db, PhotoStoreIo(root));
    await ctx.storage.ensureReady();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Rem', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'D1', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    await ctx.visites.insert(Visite(id: 'v1', numeroRame: 3, typeVisite: TypeVisite.mkbdr, niveau: Niveau.deux, dateVisite: 0, dateCreation: 0));
    final key = await ctx.storage.importBytes(Uint8List.fromList([1, 2, 3]), 'photos', 'jpg');
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: key, datePrise: 0, dateCreation: 0, visiteId: 'v1'));

    final cles = await ResetService(db, ctx.storage).clearVisitesEtPhotos();

    expect(cles, contains(key));
    expect(await ctx.storage.readBytes(key), isNull); // blob/fichier supprimé
    expect((await ctx.visites.all()).isEmpty, isTrue); // visites vidées
    expect((await ctx.photos.forZone('z1')).isEmpty, isTrue); // photos vidées
    expect((await ctx.plans.all()).length, 1); // plan de référence conservé
    expect((await ctx.zones.forPlan('p1')).length, 1); // zone conservée

    await db.close();
    root.deleteSync(recursive: true);
  });

  test('deleteVisite supprime UNE visite + ses photos, garde les autres', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_del1');
    final ctx = AppContext(db, PhotoStoreIo(root));
    await ctx.storage.ensureReady();

    await ctx.plans.insert(Plan(id: 'p1', nom: 'Rem', cheminImage: 'plans/p.png', ordre: 0, dateCreation: 0));
    await ctx.zones.insert(Zone(id: 'z1', planId: 'p1', nom: 'D1', x: 0, y: 0, largeur: .1, hauteur: .1, dateCreation: 0));
    await ctx.visites.insert(Visite(id: 'v1', numeroRame: 3, typeVisite: TypeVisite.mkbam, niveau: Niveau.deux, dateVisite: 0, dateCreation: 0));
    await ctx.visites.insert(Visite(id: 'v2', numeroRame: 3, typeVisite: TypeVisite.mkbdr, niveau: Niveau.deux, dateVisite: 0, dateCreation: 0));
    final k1 = await ctx.storage.importBytes(Uint8List.fromList([1]), 'photos', 'jpg');
    final k2 = await ctx.storage.importBytes(Uint8List.fromList([2]), 'photos', 'jpg');
    await ctx.photos.insert(Photo(id: 'f1', zoneId: 'z1', cheminFichier: k1, datePrise: 0, dateCreation: 0, visiteId: 'v1'));
    await ctx.photos.insert(Photo(id: 'f2', zoneId: 'z1', cheminFichier: k2, datePrise: 0, dateCreation: 0, visiteId: 'v2'));

    final cles = await ResetService(db, ctx.storage).deleteVisite('v1');

    expect(cles, contains(k1));
    expect(await ctx.storage.readBytes(k1), isNull); // blob de v1 supprimé
    expect(await ctx.storage.readBytes(k2), isNotNull); // blob de v2 conservé
    final restantes = await ctx.visites.all();
    expect(restantes.map((v) => v.id).toList(), ['v2']); // seule v1 supprimée
    expect((await ctx.photos.forZone('z1')).map((p) => p.id).toList(), ['f2']);

    await db.close();
    root.deleteSync(recursive: true);
  });
}
