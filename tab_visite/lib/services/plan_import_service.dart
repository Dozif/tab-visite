import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../data/models/plan.dart';
import '../data/repositories/plan_repository.dart';
import 'photo_store.dart';

class PlanImportService {
  final PlanRepository planRepo;
  final PhotoStore storage;
  final Uuid _uuid = const Uuid();
  PlanImportService(this.planRepo, this.storage);

  Future<Plan> importFromBytes(
      Uint8List bytes, String ext, String nom, int nowMs) async {
    final rel = await storage.importBytes(bytes, 'plans', ext.isEmpty ? 'png' : ext);
    final plan = Plan(
      id: _uuid.v4(),
      nom: nom,
      cheminImage: rel,
      ordre: await planRepo.nextOrdre(),
      dateCreation: nowMs,
    );
    await planRepo.insert(plan);
    return plan;
  }
}
