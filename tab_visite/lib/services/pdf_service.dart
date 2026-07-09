import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import '../services/file_storage.dart';
import '../ui/widgets/date_format.dart';

class PdfService {
  final PlanRepository planRepo;
  final ZoneRepository zoneRepo;
  final PhotoRepository photoRepo;
  final FileStorage storage;
  PdfService(this.planRepo, this.zoneRepo, this.photoRepo, this.storage);

  Future<Uint8List> buildPlanReport(String planId) async {
    final plans = await planRepo.all();
    final plan = plans.firstWhere((p) => p.id == planId);
    final doc = pw.Document();

    final planImg = pw.MemoryImage(storage.resolve(plan.cheminImage).readAsBytesSync());
    final zones = await zoneRepo.forPlan(planId);

    final widgets = <pw.Widget>[
      pw.Header(level: 0, child: pw.Text('Rapport de visite — ${plan.nom}')),
      pw.Center(child: pw.Image(planImg, height: 180)),
      pw.SizedBox(height: 12),
    ];

    for (final z in zones) {
      final photos = await photoRepo.forZone(z.id);
      widgets.add(pw.Header(level: 1, child: pw.Text('Zone ${z.nom}')));
      if (photos.isEmpty) {
        widgets.add(pw.Text('Aucune photo', style: const pw.TextStyle(fontSize: 10)));
      } else {
        widgets.add(pw.Wrap(spacing: 8, runSpacing: 8, children: photos.map((ph) {
          final img = pw.MemoryImage(storage.resolve(ph.cheminFichier).readAsBytesSync());
          return pw.Column(children: [
            pw.Image(img, width: 150, height: 110, fit: pw.BoxFit.cover),
            pw.Text(formatDateHeure(ph.datePrise), style: const pw.TextStyle(fontSize: 8)),
          ]);
        }).toList()));
      }
      widgets.add(pw.SizedBox(height: 10));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => widgets,
    ));
    return doc.save();
  }
}
