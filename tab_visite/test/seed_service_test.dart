import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/repositories/plan_repository.dart';
import 'package:tab_visite/data/repositories/zone_repository.dart';
import 'package:tab_visite/services/photo_store_io.dart';
import 'package:tab_visite/services/seed_service.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('seedIfEmpty crée plans + zones une seule fois', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_seed');
    final storage = PhotoStoreIo(root);
    await storage.ensureReady();
    final planRepo = PlanRepository(db);
    final service = SeedService(planRepo, ZoneRepository(db), storage);

    const json = '{"plans":[{"nom":"P1","image":"image1.png","zones":['
        '{"nom":"M","x":0.1,"y":0.2,"largeur":0.05,"hauteur":0.1}]}]}';
    Future<List<int>> loader(String a) async => [0, 1, 2];

    await service.seedIfEmpty(json, loader);
    await service.seedIfEmpty(json, loader); // 2e appel : no-op

    final plans = await planRepo.all();
    expect(plans.length, 1);
    expect(await storage.readBytes(plans.first.cheminImage), isNotNull);
    root.deleteSync(recursive: true);
  });
}
