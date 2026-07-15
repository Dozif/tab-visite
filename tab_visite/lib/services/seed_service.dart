import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../data/models/plan.dart';
import '../data/models/zone.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import 'photo_store.dart';

class SeedService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final PhotoStore storage;
  final Uuid _uuid = const Uuid();
  SeedService(this.planRepo, this.zoneRepo, this.storage);

  Future<void> seedIfEmpty(
      String zonesJson, Future<List<int>> Function(String asset) loadAsset) async {
    if ((await planRepo.all()).isNotEmpty) return;
    await storage.ensureReady();

    final data = jsonDecode(zonesJson) as Map<String, Object?>;
    final plans = (data['plans'] as List).cast<Map<String, Object?>>();
    var ordre = 0;
    // NB: pas de Date.now() — dateCreation dérivée de l'ordre (déterministe).
    for (final entry in plans) {
      final bytes = await loadAsset(entry['image'] as String);
      final rel = await storage.importBytes(
          Uint8List.fromList(bytes), 'plans', 'png');

      final planId = _uuid.v4();
      final nom = entry['nom'] as String;
      // Catégorie/série : explicites dans le JSON si fournies, sinon déduites
      // du nom (les plans « Motrice … » sont des motrices, les autres des remorques).
      final categorie = (entry['categorie'] as String?) ??
          (nom.startsWith('Motrice') ? 'motrice' : 'remorque');
      final serie = (entry['serie'] as String?) ?? '2N';
      await planRepo.insert(Plan(
        id: planId,
        nom: nom,
        cheminImage: rel,
        ordre: ordre,
        dateCreation: ordre,
        categorie: categorie,
        serie: serie,
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
          imageReference: z['imageReference'] as String?,
        ));
      }
      ordre++;
    }
  }
}
