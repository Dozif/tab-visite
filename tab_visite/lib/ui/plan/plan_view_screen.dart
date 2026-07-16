import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../data/models/plan.dart';
import '../../data/models/visite.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../zone/zone_sheet.dart';
import '../widgets/photo_image.dart';
import 'zone_overlay.dart';
import 'zone_editor_controller.dart';

class PlanViewScreen extends StatefulWidget {
  final Plan plan;
  final Visite? visite; // visite en cours (null hors d'une visite)
  const PlanViewScreen({super.key, required this.plan, this.visite});
  @override
  State<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends State<PlanViewScreen> {
  late final AppContext ctx = context.read<AppContext>();
  final ZoneEditorController editor = ZoneEditorController();
  late Plan _plan = widget.plan; // dessin courant (change avec ◀ ▶)
  List<Plan> _freres = []; // tous les dessins de la visite, dans l'ordre
  int _index = 0; // position de _plan dans _freres
  List<Zone> _zones = [];
  Set<String> _avecPhotos = {};
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    editor.addListener(() => setState(() {}));
    _chargerFreres();
    _resolveImageSize();
    _load();
  }

  /// Charge la liste ordonnée des dessins parcourables avec ◀ ▶ : ceux de la
  /// visite (type + niveau), ou tous les plans en accès direct.
  Future<void> _chargerFreres() async {
    final freres = widget.visite == null
        ? await ctx.plans.all()
        : await ctx.plans
            .forTypeVisite(widget.visite!.typeVisite, widget.visite!.niveau);
    final idx = freres.indexWhere((p) => p.id == _plan.id);
    if (mounted) {
      setState(() {
        _freres = freres;
        _index = idx < 0 ? 0 : idx;
      });
    }
  }

  /// Bascule vers le dessin d'index [i] (recharge image + zones).
  Future<void> _allerVers(int i) async {
    if (i < 0 || i >= _freres.length) return;
    if (editor.editing) editor.toggle(); // sort du mode édition avant de changer
    setState(() {
      _index = i;
      _plan = _freres[i];
      _imageSize = null;
      _zones = [];
      _avecPhotos = {};
    });
    await _resolveImageSize();
    await _load();
  }

  Future<void> _resolveImageSize() async {
    final bytes = await ctx.storage.readBytes(_plan.cheminImage);
    if (bytes == null) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _imageSize = Size(
          frame.image.width.toDouble(), frame.image.height.toDouble()));
    }
  }

  /// Persiste tous les points du dessin courant et confirme. Les déplacements
  /// sont déjà sauvegardés au fil de l'eau ; ce bouton garantit l'écriture de
  /// l'état final et donne un retour visuel « enregistré ».
  Future<void> _enregistrerPoints() async {
    for (final z in _zones) {
      await ctx.zones.update(z);
    }
    editor.toggle(); // sort du mode édition
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Points enregistrés')));
    }
  }

  Future<void> _load() async {
    final zones = await ctx.zones.forPlan(_plan.id);
    final counts = await ctx.photos.countsForPlanZones(_plan.id);
    if (mounted) {
      setState(() {
        _zones = zones;
        _avecPhotos = counts.keys.toSet();
      });
    }
  }

  Future<void> _onTapZone(Zone z) async {
    if (editor.editing) {
      editor.select(z.id);
      _menuEdition(z);
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ZoneSheet(ctx: ctx, zone: z, visiteId: widget.visite?.id),
    );
    _load();
  }

  Future<void> _menuEdition(Zone z) async {
    // Renommer / supprimer (déplacement/redimension : Task 11).
    await showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Renommer'),
          onTap: () async { Navigator.pop(context); await _renommer(z); },
        ),
        ListTile(
          leading: const Icon(Icons.delete),
          title: const Text('Supprimer la zone'),
          onTap: () async {
            Navigator.pop(context);
            await ctx.zones.delete(z.id);
            _load();
          },
        ),
      ]),
    ));
  }

  Future<void> _renommer(Zone z) async {
    final c = TextEditingController(text: z.nom);
    final nom = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Nom de la zone'),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
      ],
    ));
    if (nom != null && nom.isNotEmpty) {
      await ctx.zones.update(z.copyWith(nom: nom));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _imageSize;
    final aPrecedent = _index > 0;
    final aSuivant = _index < _freres.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(_plan.nom),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Retour à l\'accueil',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Dessin précédent',
            onPressed: aPrecedent ? () => _allerVers(_index - 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Dessin suivant',
            onPressed: aSuivant ? () => _allerVers(_index + 1) : null,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(editor.editing ? Icons.save : Icons.edit_location_alt),
            tooltip:
                editor.editing ? 'Enregistrer les points' : 'Modifier les points',
            onPressed: editor.editing ? _enregistrerPoints : editor.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.folder_zip),
            tooltip: 'Exporter les photos',
            onPressed: () async {
              final res = await ExportService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
                  .exportPlanToZip(_plan.id);
              await Share.shareXFiles([
                XFile.fromData(res.bytes,
                    name: res.filename, mimeType: 'application/zip')
              ], fileNameOverrides: [res.filename]);
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Rapport PDF',
            onPressed: () async {
              final bytes = await PdfService(ctx.plans, ctx.zones, ctx.photos, ctx.storage)
                  .buildPlanReport(_plan.id);
              await Printing.sharePdf(bytes: bytes, filename: 'rapport_${_plan.nom}.pdf');
            },
          ),
        ],
      ),
      body: size == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              // Surface à ratio d'image, ancrage garanti par coords normalisées.
              final imgRatio = size.width / size.height;
              return InteractiveViewer(
                maxScale: 6,
                minScale: 0.5,
                panEnabled: !editor.editing,
                scaleEnabled: !editor.editing,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: imgRatio,
                    child: LayoutBuilder(builder: (context, box) {
                      final displaySize = Size(box.maxWidth, box.maxHeight);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          PhotoImage(
                              store: ctx.storage,
                              storageKey: _plan.cheminImage,
                              fit: BoxFit.fill,
                              errorBuilder: (_) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey)))),
                          ZoneOverlay(
                            zones: _zones,
                            size: displaySize,
                            zonesAvecPhotos: _avecPhotos,
                            selectedId: editor.selectedZoneId,
                            onTap: _onTapZone,
                            editing: editor.editing,
                            onChanged: (updated) {
                              setState(() {
                                final i = _zones.indexWhere((e) => e.id == updated.id);
                                if (i >= 0) _zones[i] = updated;
                              });
                            },
                            onCommit: (updated) async {
                              await ctx.zones.update(updated);
                            },
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            }),
      floatingActionButton: editor.editing
          ? FloatingActionButton.extended(
              onPressed: _ajouterZone,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une zone'),
            )
          : null,
    );
  }

  Future<void> _ajouterZone() async {
    // Ajout au centre ; repositionnement en Task 11.
    final c = TextEditingController();
    final nom = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Nom de la nouvelle zone'),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
      ],
    ));
    if (nom == null || nom.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await ctx.zones.insert(Zone(
      id: const Uuid().v4(), planId: _plan.id, nom: nom,
      x: 0.45, y: 0.45, largeur: 0.1, hauteur: 0.1, dateCreation: now,
    ));
    _load();
  }
}
