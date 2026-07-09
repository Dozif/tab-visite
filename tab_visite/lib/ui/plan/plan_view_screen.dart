import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/plan.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../zone/zone_sheet.dart';
import 'zone_overlay.dart';
import 'zone_editor_controller.dart';

class PlanViewScreen extends StatefulWidget {
  final Plan plan;
  const PlanViewScreen({super.key, required this.plan});
  @override
  State<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends State<PlanViewScreen> {
  late final AppContext ctx = context.read<AppContext>();
  final ZoneEditorController editor = ZoneEditorController();
  List<Zone> _zones = [];
  Set<String> _avecPhotos = {};
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    editor.addListener(() => setState(() {}));
    _resolveImageSize();
    _load();
  }

  Future<void> _resolveImageSize() async {
    final file = ctx.storage.resolve(widget.plan.cheminImage);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _imageSize = Size(
          frame.image.width.toDouble(), frame.image.height.toDouble()));
    }
  }

  Future<void> _load() async {
    final zones = await ctx.zones.forPlan(widget.plan.id);
    final counts = await ctx.photos.countsForPlanZones(widget.plan.id);
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
      builder: (_) => ZoneSheet(ctx: ctx, zone: z),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.nom),
        actions: [
          IconButton(
            icon: Icon(editor.editing ? Icons.check : Icons.edit_location_alt),
            tooltip: editor.editing ? 'Terminer l\'édition' : 'Mode édition',
            onPressed: editor.toggle,
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
                          Image.file(ctx.storage.resolve(widget.plan.cheminImage),
                              fit: BoxFit.fill),
                          ZoneOverlay(
                            zones: _zones,
                            size: displaySize,
                            zonesAvecPhotos: _avecPhotos,
                            selectedId: editor.selectedZoneId,
                            onTap: _onTapZone,
                            editing: editor.editing,
                            onChanged: (updated) async {
                              setState(() {
                                final i = _zones.indexWhere((e) => e.id == updated.id);
                                if (i >= 0) _zones[i] = updated;
                              });
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
      id: const Uuid().v4(), planId: widget.plan.id, nom: nom,
      x: 0.45, y: 0.45, largeur: 0.1, hauteur: 0.1, dateCreation: now,
    ));
    _load();
  }
}
