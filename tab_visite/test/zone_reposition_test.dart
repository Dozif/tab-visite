import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/data/models/zone.dart';

void main() {
  test('déplacement borne x/y dans [0,1-taille]', () {
    var z = Zone(id: 'z', planId: 'p', nom: 'M', x: 0.9, y: 0.9, largeur: 0.2, hauteur: 0.2, dateCreation: 0);
    final nx = (z.x + 0.5).clamp(0.0, 1.0 - z.largeur);
    expect(nx, 0.8);
  });
}
