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

/// Niveau de la rame (simple ou double étage). Détermine la série des plans
/// inspectés : les motrices/remorques « 1N » vs « 2N ».
class Niveau {
  static const un = '1N'; // rame à un niveau
  static const deux = '2N'; // rame à deux niveaux (double étage)

  static const tous = [deux, un];

  /// Libellé lisible affiché à l'utilisateur.
  static String libelle(String niveau) => switch (niveau) {
        un => '1N — un niveau',
        deux => '2N — deux niveaux',
        _ => niveau,
      };
}

/// Un dossier de visite : une rame, un type, une date. Contient des photos.
class Visite {
  final String id;
  final int numeroRame;
  final String typeVisite; // MKBAM / MKBDR / MKBAR
  final String niveau; // 1N / 2N (série des plans inspectés)
  final int dateVisite; // millisecondsSinceEpoch
  final int dateCreation;

  const Visite({
    required this.id,
    required this.numeroRame,
    required this.typeVisite,
    this.niveau = Niveau.deux,
    required this.dateVisite,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'numero_rame': numeroRame,
        'type_visite': typeVisite,
        'niveau': niveau,
        'date_visite': dateVisite,
        'date_creation': dateCreation,
      };

  factory Visite.fromMap(Map<String, Object?> m) => Visite(
        id: m['id'] as String,
        numeroRame: m['numero_rame'] as int,
        typeVisite: m['type_visite'] as String,
        // Anciennes visites (avant la colonne niveau) : 2N par défaut.
        niveau: (m['niveau'] as String?) ?? Niveau.deux,
        dateVisite: m['date_visite'] as int,
        dateCreation: m['date_creation'] as int,
      );
}
