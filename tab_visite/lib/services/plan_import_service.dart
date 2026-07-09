import 'dart:io';
import 'package:uuid/uuid.dart';
import '../data/models/plan.dart';
import '../data/repositories/plan_repository.dart';
import 'file_storage.dart';

class PlanImportService {
  final PlanRepository planRepo;
  final FileStorage storage;
  final Uuid _uuid = const Uuid();
  PlanImportService(this.planRepo, this.storage);

  Future<Plan> importFromFile(File image, String nom, int nowMs) async {
    final ext = image.path.split('.').last.toLowerCase();
    final rel = await storage.importImage(image, 'plans', ext.isEmpty ? 'png' : ext);
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
