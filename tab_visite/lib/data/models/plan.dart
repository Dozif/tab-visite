class Plan {
  final String id;
  final String nom;
  final String cheminImage; // relatif au dossier de l'app
  final int ordre;
  final int dateCreation;
  final String? categorie; // 'motrice' | 'remorque' (null pour plans importés)
  final String? serie; // ex '2N' (null pour plans importés)

  const Plan({
    required this.id,
    required this.nom,
    required this.cheminImage,
    required this.ordre,
    required this.dateCreation,
    this.categorie,
    this.serie,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'chemin_image': cheminImage,
        'ordre': ordre,
        'date_creation': dateCreation,
        'categorie': categorie,
        'serie': serie,
      };

  factory Plan.fromMap(Map<String, Object?> m) => Plan(
        id: m['id'] as String,
        nom: m['nom'] as String,
        cheminImage: m['chemin_image'] as String,
        ordre: m['ordre'] as int,
        dateCreation: m['date_creation'] as int,
        categorie: m['categorie'] as String?,
        serie: m['serie'] as String?,
      );

  /// Numéro de véhicule extrait du nom : « M1 »/« M2 » (motrices) ou
  /// « R1 »..« R8 » (remorques), ou null si absent.
  /// Ex : « Remorque (Droit-Pair) R3 » → « R3 » ; « Motrice M1 Côté Gauche » → « M1 ».
  String? get numeroVehicule {
    final m = RegExp(r'\b([MR])(\d+)\b').firstMatch(nom);
    return m == null ? null : '${m.group(1)}${m.group(2)}';
  }

  Plan copyWith({String? nom, int? ordre}) => Plan(
        id: id,
        nom: nom ?? this.nom,
        cheminImage: cheminImage,
        ordre: ordre ?? this.ordre,
        dateCreation: dateCreation,
        categorie: categorie,
        serie: serie,
      );
}
