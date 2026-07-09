import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import 'file_storage.dart';

class ExportService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final PhotoRepository photoRepo;
  final FileStorage storage;
  ExportService(this.planRepo, this.zoneRepo, this.photoRepo, this.storage);

  String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '_');

  Future<File> exportPlanToZip(String planId, Directory outDir) async {
    final plans = await planRepo.all();
    final plan = plans.firstWhere((p) => p.id == planId);
    final archive = Archive();
    for (final z in await zoneRepo.forPlan(planId)) {
      for (final ph in await photoRepo.forZone(z.id)) {
        final f = storage.resolve(ph.cheminFichier);
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        final name = '${_safe(plan.nom)}/${_safe(z.nom)}/${ph.datePrise}_${ph.id}.jpg';
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }
    final out = File(p.join(outDir.path, 'export_${_safe(plan.nom)}.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }

  Future<File> exportAllToZip(Directory outDir) async {
    final archive = Archive();
    for (final plan in await planRepo.all()) {
      for (final z in await zoneRepo.forPlan(plan.id)) {
        for (final ph in await photoRepo.forZone(z.id)) {
          final f = storage.resolve(ph.cheminFichier);
          if (!f.existsSync()) continue;
          final bytes = f.readAsBytesSync();
          final name = '${_safe(plan.nom)}/${_safe(z.nom)}/${ph.datePrise}_${ph.id}.jpg';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
        }
      }
    }
    final out = File(p.join(outDir.path, 'export_toutes_photos.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }
}
