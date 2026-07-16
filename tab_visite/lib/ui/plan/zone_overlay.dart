import 'dart:math' as math;
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
  final bool editing;
  final void Function(Zone updated) onChanged;
  final void Function(Zone updated) onCommit;

  const ZoneOverlay({
    super.key,
    required this.zones,
    required this.size,
    required this.zonesAvecPhotos,
    required this.selectedId,
    required this.onTap,
    required this.editing,
    required this.onChanged,
    required this.onCommit,
  });

  /// Libellé du point (nom de la zone) : lettres noires nettes + contour blanc
  /// (halo) pour rester lisible même sur les zones chargées du dessin.
  Widget _label(String nom) {
    return FittedBox(
      child: Stack(
        children: [
          Text(nom,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..strokeJoin = StrokeJoin.round
                  ..color = Colors.white,
              )),
          Text(nom,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildZone(Zone z, Color color, bool selected) {
    final body = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        border: Border.all(color: selected ? Colors.blue : color, width: selected ? 3 : 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _label(z.nom),
    );
    if (!editing) {
      return GestureDetector(onTap: () => onTap(z), child: body);
    }
    return GestureDetector(
      onTap: () => onTap(z),
      onPanUpdate: (d) {
        final nx = (z.x + d.delta.dx / size.width)
            .clamp(0.0, math.max(0.0, 1.0 - z.largeur))
            .toDouble();
        final ny = (z.y + d.delta.dy / size.height)
            .clamp(0.0, math.max(0.0, 1.0 - z.hauteur))
            .toDouble();
        onChanged(z.copyWith(x: nx, y: ny));
      },
      onPanEnd: (_) => onCommit(z),
      child: Stack(children: [
        Positioned.fill(child: body),
        Positioned(
          right: 0, bottom: 0,
          child: GestureDetector(
            onPanUpdate: (d) {
              final nw = (z.largeur + d.delta.dx / size.width)
                  .clamp(0.02, math.max(0.02, 1.0 - z.x))
                  .toDouble();
              final nh = (z.hauteur + d.delta.dy / size.height)
                  .clamp(0.02, math.max(0.02, 1.0 - z.y))
                  .toDouble();
              onChanged(z.copyWith(largeur: nw, hauteur: nh));
            },
            onPanEnd: (_) => onCommit(z),
            child: const Icon(Icons.open_in_full, size: 18, color: Colors.blue),
          ),
        ),
      ]),
    );
  }

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
          child: _buildZone(z, color, selected),
        );
      }).toList(),
    );
  }
}
