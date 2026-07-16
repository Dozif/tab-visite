import 'package:sqflite/sqflite.dart';
import 'photo_store.dart';

/// Remise à zéro des données de travail après envoi du ZIP.
///
/// Supprime **toutes les visites et leurs photos** (fichiers/blobs inclus).
/// Les plans de référence et leurs zones sont conservés (ils sont re-seedés
/// au besoin, mais ici on les garde pour que l'app reste utilisable).
class ResetService {
  final Database db;
  final PhotoStore storage;
  ResetService(this.db, this.storage);

  /// Renvoie les clés des images supprimées (pour vider un cache d'affichage).
  Future<List<String>> clearVisitesEtPhotos() async {
    final rows = await db.query('photos', columns: ['chemin_fichier']);
    final cles = <String>[];
    for (final r in rows) {
      final key = r['chemin_fichier'] as String?;
      if (key != null) {
        await storage.delete(key);
        cles.add(key);
      }
    }
    await db.delete('photos');
    await db.delete('visites');
    return cles;
  }

  /// Supprime **une seule** visite et ses photos (fichiers/blobs + lignes),
  /// sans toucher aux autres visites. Renvoie les clés des images supprimées
  /// (pour vider un cache d'affichage).
  Future<List<String>> deleteVisite(String visiteId) async {
    final rows = await db.query('photos',
        columns: ['chemin_fichier'],
        where: 'visite_id = ?',
        whereArgs: [visiteId]);
    final cles = <String>[];
    for (final r in rows) {
      final key = r['chemin_fichier'] as String?;
      if (key != null) {
        await storage.delete(key);
        cles.add(key);
      }
    }
    await db.delete('photos', where: 'visite_id = ?', whereArgs: [visiteId]);
    await db.delete('visites', where: 'id = ?', whereArgs: [visiteId]);
    return cles;
  }
}
