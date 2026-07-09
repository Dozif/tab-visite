import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/data/models/zone.dart';
import 'package:tab_visite/data/models/photo.dart';

void main() {
  test('Plan round-trip map', () {
    final p = Plan(id: 'p1', nom: '2N V1', cheminImage: 'plans/a.png', ordre: 2, dateCreation: 1000);
    expect(Plan.fromMap(p.toMap()).toMap(), p.toMap());
    expect(p.toMap()['nom'], '2N V1');
  });

  test('Zone round-trip et bornes normalisées', () {
    final z = Zone(id: 'z1', planId: 'p1', nom: 'M', x: 0.1, y: 0.2, largeur: 0.05, hauteur: 0.08, dateCreation: 1);
    final back = Zone.fromMap(z.toMap());
    expect(back.x, 0.1);
    expect(back.nom, 'M');
    expect(back.planId, 'p1');
  });

  test('Photo round-trip map', () {
    final ph = Photo(id: 'f1', zoneId: 'z1', cheminFichier: 'photos/x.jpg', datePrise: 5, dateCreation: 6);
    expect(Photo.fromMap(ph.toMap()).cheminFichier, 'photos/x.jpg');
  });
}
