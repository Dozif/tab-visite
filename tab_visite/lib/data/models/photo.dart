class Photo {
  final String id;
  final String zoneId;
  final String cheminFichier; // relatif au dossier de l'app
  final int datePrise;
  final int dateCreation;

  const Photo({
    required this.id,
    required this.zoneId,
    required this.cheminFichier,
    required this.datePrise,
    required this.dateCreation,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'zone_id': zoneId,
        'chemin_fichier': cheminFichier,
        'date_prise': datePrise,
        'date_creation': dateCreation,
      };

  factory Photo.fromMap(Map<String, Object?> m) => Photo(
        id: m['id'] as String,
        zoneId: m['zone_id'] as String,
        cheminFichier: m['chemin_fichier'] as String,
        datePrise: m['date_prise'] as int,
        dateCreation: m['date_creation'] as int,
      );
}
