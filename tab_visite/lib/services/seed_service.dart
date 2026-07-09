import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../data/models/plan.dart';
import '../data/models/zone.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import 'file_storage.dart';

class SeedService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final FileStorage storage;
  final Uuid _uuid = const Uuid();
  SeedService(this.planRepo, this.zoneRepo, this.storage);

  Future<void> seedIfEmpty(
      String zonesJson, Future<List<int>> Function(String asset) loadAsset) async {
    if ((await planRepo.all()).isNotEmpty) return;
    await storage.ensureDirs();

    final data = jsonDecode(zonesJson) as Map<String, Object?>;
    final plans = (data['plans'] as List).cast<Map<String, Object?>>();
    var ordre = 0;
    // NB: pas de Date.now() — dateCreation dérivée de l'ordre (déterministe).
    for (final entry in plans) {
      final bytes = await loadAsset(entry['image'] as String);
      final rel = 'plans/${_uuid.v4()}.png';
      final dest = storage.resolve(rel);
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(bytes);

      final planId = _uuid.v4();
      await planRepo.insert(Plan(
        id: planId,
        nom: entry['nom'] as String,
        cheminImage: rel,
        ordre: ordre,
        dateCreation: ordre,
      ));
      for (final z in (entry['zones'] as List).cast<Map<String, Object?>>()) {
        await zoneRepo.insert(Zone(
          id: _uuid.v4(),
          planId: planId,
          nom: z['nom'] as String,
          x: (z['x'] as num).toDouble(),
          y: (z['y'] as num).toDouble(),
          largeur: (z['largeur'] as num).toDouble(),
          hauteur: (z['hauteur'] as num).toDouble(),
          dateCreation: ordre,
        ));
      }
      ordre++;
    }
  }
}
