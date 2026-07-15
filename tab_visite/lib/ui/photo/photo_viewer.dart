import 'package:flutter/material.dart';
import '../../data/models/photo.dart';
import '../../services/photo_store.dart';
import '../widgets/date_format.dart';
import '../widgets/photo_image.dart';

class PhotoViewer extends StatelessWidget {
  final PhotoStore store;
  final String storageKey;
  final Photo photo;
  final Future<void> Function() onDelete;
  const PhotoViewer({super.key, required this.store, required this.storageKey, required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(formatDateHeure(photo.datePrise)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Supprimer',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer la photo ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
                  ],
                ),
              );
              if (ok == true) {
                await onDelete();
                if (context.mounted) Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: PhotoImage(
            store: store,
            storageKey: storageKey,
            errorBuilder: (_) => const Icon(Icons.broken_image,
                color: Colors.grey, size: 64),
          ),
        ),
      ),
    );
  }
}
