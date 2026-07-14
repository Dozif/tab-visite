import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/visite.dart';
import '../../services/app_context.dart';
import '../../services/export_service.dart';
import '../widgets/date_format.dart';
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
  }

  Future<void> _load() async {
    final v = await ctx.visites.all();
    if (mounted) setState(() => _visites = v);
  }

  Future<void> _nouvelleVisite() async {
    final visite = await showNouvelleVisite(context, ctx);
    if (visite == null) return;
    await _load();
    _ouvrir(visite);
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

  Future<void> _exporterVisite(Visite v) => _exporter(
      (dir) => _export.exportVisiteToZip(v, dir), 'Export de la visite');

  Future<void> _exporterTout() => _exporter(
      (dir) => _export.exportAllVisitesToZip(dir), 'Export de toutes les visites');

  /// Génère le ZIP (avec un indicateur d'attente) puis ouvre le partage Android
  /// pour l'envoyer vers le PC. Affiche un message en cas d'échec.
  Future<void> _exporter(
      Future<File> Function(Directory outDir) run, String libelle) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final dir = await getTemporaryDirectory();
      final zip = await run(dir);
      if (mounted) Navigator.of(context).pop(); // ferme l'indicateur
      await Share.shareXFiles([XFile(zip.path)]);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$libelle : échec ($e)')));
      }
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
                TextButton.icon(
                  onPressed: _visites.isEmpty ? null : _exporterTout,
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('Tout exporter'),
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
