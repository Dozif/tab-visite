import 'package:flutter/material.dart';
import '../../data/models/zone.dart';

/// Dessine les zones sur une surface de taille [size] (px), à partir de
/// coordonnées normalisées. Vert = a des photos, rouge = vide.
class ZoneOverlay extends StatelessWidget {
  final List<Zone> zones;
  final Size size;
  final Set<String> zonesAvecPhotos;
  final String? selectedId;
  final void Function(Zone) onTap;

  const ZoneOverlay({
    super.key,
    required this.zones,
    required this.size,
    required this.zonesAvecPhotos,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: zones.map((z) {
        final hasPhotos = zonesAvecPhotos.contains(z.id);
        final selected = z.id == selectedId;
        final color = hasPhotos ? Colors.green : Colors.red;
        return Positioned(
          left: z.x * size.width,
          top: z.y * size.height,
          width: z.largeur * size.width,
          height: z.hauteur * size.height,
          child: GestureDetector(
            onTap: () => onTap(z),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(hasPhotos ? 0.35 : 0.12),
                border: Border.all(
                    color: selected ? Colors.blue : color,
                    width: selected ? 3 : 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FittedBox(
                child: Text(z.nom,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
