import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/data/models/zone.dart';

void main() {
  test('déplacement borne x/y dans [0,1-taille]', () {
    var z = Zone(id: 'z', planId: 'p', nom: 'M', x: 0.9, y: 0.9, largeur: 0.2, hauteur: 0.2, dateCreation: 0);
    final nx = (z.x + 0.5).clamp(0.0, 1.0 - z.largeur);
    expect(nx, 0.8);
  });

  test('resize près du bord droit ne lève pas ArgumentError et reste borné', () {
    const zx = 0.99; // zone collée à droite
    final nw = (0.05 + 0.2).clamp(0.02, math.max(0.02, 1.0 - zx));
    expect(nw, 0.02); // borné à la valeur minimale sûre, pas de crash
  });
}
