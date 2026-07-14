import 'package:flutter/material.dart';
import '../../data/models/photo.dart';
import '../../data/models/zone.dart';
import '../../services/app_context.dart';
import '../../services/photo_capture_service.dart';
import '../photo/photo_viewer.dart';
import '../widgets/date_format.dart';

class ZoneSheet extends StatefulWidget {
  final AppContext ctx;
  final Zone zone;
  final String? visiteId; // visite en cours (null hors d'une visite)
  const ZoneSheet(
      {super.key, required this.ctx, required this.zone, this.visiteId});

  @override
  State<ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends State<ZoneSheet> {
  List<Photo> _photos = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final photos = await widget.ctx.photos.forZone(widget.zone.id);
    if (mounted) setState(() => _photos = photos);
  }

  Future<void> _ajouterPhoto() async {
    final service = PhotoCaptureService(widget.ctx.photos, widget.ctx.storage);
    await service.capture(widget.zone.id, DateTime.now().millisecondsSinceEpoch,
        visiteId: widget.visiteId);
    await _load();
  }

  Future<void> _ouvrir(Photo p) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhotoViewer(
        file: widget.ctx.storage.resolve(p.cheminFichier),
        photo: p,
        onDelete: () async {
          await widget.ctx.storage.deleteRelative(p.cheminFichier);
          await widget.ctx.photos.delete(p.id);
        },
      ),
    ));
    await _load();
  }

  void _agrandirReference(String asset) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.zone.imageReference;
    final estPoint = ref != null;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('${estPoint ? "Point" : "Zone"} ${widget.zone.nom}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _ajouterPhoto,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Ajouter une photo'),
                ),
              ],
            ),
          ),
          if (ref != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Référence (appuyer pour agrandir)',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _agrandirReference(ref),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(ref, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image))),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _photos.isEmpty
                ? const Center(child: Text('Aucune photo pour cette zone'))
                : GridView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: _photos.length,
                    itemBuilder: (_, i) {
                      final p = _photos[i];
                      return GestureDetector(
                        onTap: () => _ouvrir(p),
                        child: GridTile(
                          footer: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.all(2),
                            child: Text(formatDateHeure(p.datePrise),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                                textAlign: TextAlign.center),
                          ),
                          child: Image.file(
                              widget.ctx.storage.resolve(p.cheminFichier),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey))),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
