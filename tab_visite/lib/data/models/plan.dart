class Plan {
  final String id;
  final String nom;
  final String cheminImage; // relatif au dossier de l'app
  final int ordre;
  final int dateCreation;

  const Plan({
    required this.id,
    required this.nom,
    required this.cheminImage,
    required this.ordre,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'chemin_image': cheminImage,
        'ordre': ordre,
        'date_creation': dateCreation,
      };

  factory Plan.fromMap(Map<String, Object?> m) => Plan(
        id: m['id'] as String,
        nom: m['nom'] as String,
        cheminImage: m['chemin_image'] as String,
        ordre: m['ordre'] as int,
        dateCreation: m['date_creation'] as int,
      );

  Plan copyWith({String? nom, int? ordre}) => Plan(
        id: id,
        nom: nom ?? this.nom,
        cheminImage: cheminImage,
        ordre: ordre ?? this.ordre,
        dateCreation: dateCreation,
      );
}
