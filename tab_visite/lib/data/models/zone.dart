class Zone {
  final String id;
  final String planId;
  final String nom;
  final double x, y, largeur, hauteur; // normalisés 0–1
  final int dateCreation;

  const Zone({
    required this.id,
    required this.planId,
    required this.nom,
    required this.x,
    required this.y,
    required this.largeur,
    required this.hauteur,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'plan_id': planId,
        'nom': nom,
        'x': x,
        'y': y,
        'largeur': largeur,
        'hauteur': hauteur,
        'date_creation': dateCreation,
      };

  factory Zone.fromMap(Map<String, Object?> m) => Zone(
        id: m['id'] as String,
        planId: m['plan_id'] as String,
        nom: m['nom'] as String,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        largeur: (m['largeur'] as num).toDouble(),
        hauteur: (m['hauteur'] as num).toDouble(),
        dateCreation: m['date_creation'] as int,
      );

  Zone copyWith({String? nom, double? x, double? y, double? largeur, double? hauteur}) => Zone(
        id: id,
        planId: planId,
        nom: nom ?? this.nom,
        x: x ?? this.x,
        y: y ?? this.y,
        largeur: largeur ?? this.largeur,
        hauteur: hauteur ?? this.hauteur,
        dateCreation: dateCreation,
      );
}
