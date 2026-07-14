import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../data/models/visite.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import '../ui/widgets/date_format.dart';
import 'file_storage.dart';

class ExportService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final PhotoRepository photoRepo;
  final FileStorage storage;
  ExportService(this.planRepo, this.zoneRepo, this.photoRepo, this.storage);

  /// Colonnes du récapitulatif `data.xlsx` (une ligne par photo).
  static const _entetes = [
    'Rame', 'Type', 'Niveau', 'Date visite',
    'Plan', 'Zone', 'Date prise', 'Traitée', 'Chemin photo',
  ];

  String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '_');
  String _jour(int epochMs) =>
      DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(epochMs));
  String _ouiNon(Object? traitee) =>
      (traitee is int ? traitee != 0 : traitee == true) ? 'oui' : 'non';

  // --- Export par visite / global (photos + data.xlsx) -----------------------

  /// Exporte le dossier d'une visite : toutes ses photos + un récapitulatif
  /// Excel. Arborescence du ZIP : `photos/<plan>/<zone>/<date>_<id>.jpg`.
  Future<File> exportVisiteToZip(Visite v, Directory outDir) async {
    final archive = Archive();
    final data = <List<String>>[];
    for (final r in await photoRepo.joinedForVisite(v.id)) {
      final datePrise = r['date_prise'] as int;
      final chemin = 'photos/${_safe(r['plan_nom'] as String)}'
          '/${_safe(r['zone_nom'] as String)}'
          '/${datePrise}_${r['id']}.jpg';
      _addPhoto(archive, r['chemin_fichier'] as String, chemin);
      data.add([
        '${v.numeroRame}', v.typeVisite, v.niveau, formatDate(v.dateVisite),
        r['plan_nom'] as String, r['zone_nom'] as String,
        formatDateHeure(datePrise), _ouiNon(r['traitee']), chemin,
      ]);
    }
    _addXlsx(archive, data);
    final nom =
        'visite_R${v.numeroRame}_${v.typeVisite}_${v.niveau}_${_jour(v.dateVisite)}';
    final out = File(p.join(outDir.path, '${_safe(nom)}.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }

  /// Exporte toutes les visites : photos préfixées par visite pour éviter les
  /// collisions (`photos/R<rame>_<type>_<niveau>/<plan>/<zone>/...`) + récap.
  Future<File> exportAllVisitesToZip(Directory outDir) async {
    final archive = Archive();
    final data = <List<String>>[];
    for (final r in await photoRepo.joinedAllByVisite()) {
      final rame = r['numero_rame'] as int;
      final type = r['type_visite'] as String;
      final niveau = r['niveau'] as String;
      final datePrise = r['date_prise'] as int;
      final dossier = _safe('R${rame}_${type}_$niveau');
      final chemin = 'photos/$dossier'
          '/${_safe(r['plan_nom'] as String)}'
          '/${_safe(r['zone_nom'] as String)}'
          '/${datePrise}_${r['id']}.jpg';
      _addPhoto(archive, r['chemin_fichier'] as String, chemin);
      data.add([
        '$rame', type, niveau, formatDate(r['date_visite'] as int),
        r['plan_nom'] as String, r['zone_nom'] as String,
        formatDateHeure(datePrise), _ouiNon(r['traitee']), chemin,
      ]);
    }
    _addXlsx(archive, data);
    final out = File(p.join(outDir.path,
        'toutes_visites_${_jour(DateTime.now().millisecondsSinceEpoch)}.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }

  void _addPhoto(Archive archive, String cheminRelatif, String pathInZip) {
    final f = storage.resolve(cheminRelatif);
    if (!f.existsSync()) return; // photo manquante : ignorée silencieusement
    final bytes = f.readAsBytesSync();
    archive.addFile(ArchiveFile(pathInZip, bytes.length, bytes));
  }

  void _addXlsx(Archive archive, List<List<String>> data) {
    final book = xls.Excel.createExcel();
    book.rename('Sheet1', 'Photos');
    final sheet = book['Photos'];
    sheet.appendRow(<xls.CellValue?>[for (final e in _entetes) xls.TextCellValue(e)]);
    for (final row in data) {
      sheet.appendRow(<xls.CellValue?>[for (final c in row) xls.TextCellValue(c)]);
    }
    final bytes = book.save()!;
    archive.addFile(ArchiveFile('data.xlsx', bytes.length, bytes));
  }

  // --- Export par plan (existant) --------------------------------------------

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
