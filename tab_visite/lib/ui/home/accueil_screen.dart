import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/visite.dart';
import '../../services/app_context.dart';
import '../../services/export_service.dart';
import '../../services/photo_capture_service.dart';
import '../../services/reset_service.dart';
import '../widgets/date_format.dart';
import '../widgets/photo_image.dart';
import 'nouvelle_visite_sheet.dart';
import 'selection_vehicule_screen.dart';

/// Écran d'accueil : identité de l'app + création / reprise de visites.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});
  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  late final AppContext ctx = context.read<AppContext>();
  List<Visite> _visites = [];

  @override
  void initState() {
    super.initState();
    _load();
    _recupererPhotoPerdue();
  }

  Future<void> _load() async {
    final v = await ctx.visites.all();
    if (mounted) setState(() => _visites = v);
  }

  /// Récupère une photo dont l'app a été tuée par Android pendant la prise de
  /// vue (voir [PhotoCaptureService.recoverLostPhoto]). Android uniquement.
  Future<void> _recupererPhotoPerdue() async {
    final service = PhotoCaptureService(
        ctx.photos, ctx.storage, ctx.zones, ctx.visites, ctx.pending);
    final recuperee = await service
        .recoverLostPhoto(DateTime.now().millisecondsSinceEpoch);
    if (recuperee && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Une photo prise a été récupérée et enregistrée.')));
      await _load();
    }
  }

  Future<void> _nouvelleVisite() async {
    final visites = await showNouvelleVisite(context, ctx);
    if (visites.isEmpty) return;
    await _load();
    // Une seule visite : on l'ouvre directement (choix véhicule → plans).
    // Plusieurs : on reste sur l'accueil, elles apparaissent dans la liste.
    if (visites.length == 1) _ouvrir(visites.first);
  }

  Future<void> _ouvrir(Visite v) async {
    // Choix du véhicule (M1/M2 ou R1..R8) avant de voir les images.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelectionVehiculeScreen(visite: v)),
    );
    _load();
  }

  ExportService get _export =>
      ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage);

  Future<void> _exporterVisite(Visite v) =>
      _exporter(() => _export.exportVisiteToZip(v), 'Export de la visite');

  Future<void> _exporterTout() => _exporter(
      () => _export.exportAllVisitesToZip(), 'Export de toutes les visites');

  /// Génère le ZIP (avec un indicateur d'attente) puis ouvre le partage
  /// (feuille native / téléchargement) pour l'envoyer. Message en cas d'échec.
  Future<void> _exporter(Future<ZipExport> Function() run, String libelle) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await run();
      if (mounted) Navigator.of(context).pop(); // ferme l'indicateur
      await Share.shareXFiles([
        XFile.fromData(res.bytes,
            name: res.filename, mimeType: 'application/zip')
      ], fileNameOverrides: [res.filename]);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$libelle : échec ($e)')));
      }
    }
  }

  /// Efface visites + photos (après envoi du ZIP). Garde les plans de référence.
  Future<void> _effacerDonnees() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Effacer les données ?'),
        content: const Text(
            'Toutes les visites et leurs photos seront supprimées de la '
            'tablette. Les plans de référence sont conservés.\n\n'
            'À faire seulement après avoir envoyé le ZIP.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ResetService(ctx.db, ctx.storage).clearVisitesEtPhotos();
    PhotoImage.clearCache();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Données effacées.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _Banniere(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _nouvelleVisite,
                icon: const Icon(Icons.add),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                label: const Text('Nouvelle visite',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Visites',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _visites.isEmpty ? null : _exporterTout,
                      icon: const Icon(Icons.archive_outlined, size: 18),
                      label: const Text('Tout exporter'),
                    ),
                    TextButton.icon(
                      onPressed: _visites.isEmpty ? null : _effacerDonnees,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Effacer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _visites.isEmpty
                ? const Center(
                    child: Text('Aucune visite pour l\'instant.\nAppuie sur « Nouvelle visite ».',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _visites.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = _visites[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${v.numeroRame}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        title: Text('Rame ${v.numeroRame}'),
                        subtitle: Text(
                            '${TypeVisite.libelle(v.typeVisite)} • ${v.niveau} • ${formatDate(v.dateVisite)}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (s) {
                            if (s == 'export') _exporterVisite(v);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'export',
                                child: Text('Exporter cette visite')),
                          ],
                        ),
                        onTap: () => _ouvrir(v),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau haut : image de TGV (placeholder) + titre « Visite corrosion ».
class _Banniere extends StatelessWidget {
  const _Banniere();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
      ),
      child: const Column(
        children: [
          // Placeholder image TGV — sera remplacé par la vraie image plus tard.
          Icon(Icons.train, size: 72, color: Colors.white),
          SizedBox(height: 8),
          Text('Visite corrosion',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
