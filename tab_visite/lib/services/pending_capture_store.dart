import 'package:sqflite/sqflite.dart';

/// Contexte d'une capture photo en attente (zone + visite), persisté juste
/// avant de lancer la caméra. Sert à récupérer une photo dont l'app a été tuée
/// par Android pendant la prise de vue : `retrieveLostData()` rend le fichier
/// mais pas la zone/visite d'origine, qu'on relit ici. Une seule ligne à la fois.
class PendingCaptureStore {
  final Database db;
  PendingCaptureStore(this.db);

  /// Remplace le contexte courant (delete-all puis insert).
  Future<void> set(String zoneId, String? visiteId, int nowMs) async {
    await db.transaction((txn) async {
      await txn.delete('pending_capture');
      await txn.insert('pending_capture', {
        'zone_id': zoneId,
        'visite_id': visiteId,
        'date': nowMs,
      });
    });
  }

  /// Contexte courant, ou `null` si aucune capture n'est en attente.
  Future<({String zoneId, String? visiteId})?> get() async {
    final rows = await db.query('pending_capture', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (zoneId: r['zone_id'] as String, visiteId: r['visite_id'] as String?);
  }

  /// Efface le contexte (capture terminée ou récupérée).
  Future<void> clear() => db.delete('pending_capture');
}
