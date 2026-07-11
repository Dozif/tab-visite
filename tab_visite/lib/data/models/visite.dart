/// Types de visite. Chaque type détermine quels plans sont inspectés.
class TypeVisite {
  static const mkbam = 'MKBAM'; // motrices
  static const mkbdr = 'MKBDR'; // remorques série 2N
  static const mkbar = 'MKBAR'; // remorques d'une autre série (plans à venir)

  static const tous = [mkbam, mkbdr, mkbar];

  /// Libellé lisible affiché à l'utilisateur.
  static String libelle(String type) => switch (type) {
        mkbam => 'MKBAM — Motrices',
        mkbdr => 'MKBDR — Remorques',
        mkbar => 'MKBAR — Remorques (autre série)',
        _ => type,
      };
}

/// Un dossier de visite : une rame, un type, une date. Contient des photos.
class Visite {
  final String id;
  final int numeroRame;
  final String typeVisite; // MKBAM / MKBDR / MKBAR
  final int dateVisite; // millisecondsSinceEpoch
  final int dateCreation;

  const Visite({
    required this.id,
    required this.numeroRame,
    required this.typeVisite,
    required this.dateVisite,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'numero_rame': numeroRame,
        'type_visite': typeVisite,
        'date_visite': dateVisite,
        'date_creation': dateCreation,
      };

  factory Visite.fromMap(Map<String, Object?> m) => Visite(
        id: m['id'] as String,
        numeroRame: m['numero_rame'] as int,
        typeVisite: m['type_visite'] as String,
        dateVisite: m['date_visite'] as int,
        dateCreation: m['date_creation'] as int,
      );
}
