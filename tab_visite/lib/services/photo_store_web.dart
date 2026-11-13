import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'blob_backend.dart';
import 'photo_store.dart';

/// Implémentation web : les images (photos, plans importés) sont stockées
/// dans un IndexedDB dédié via [BlobBackend], **hors de SQLite**.
///
/// Pourquoi : la base SQLite web (sqflite_common_ffi_web) est entièrement
/// gardée en mémoire et ne recopie ses modifications dans IndexedDB que plus
/// tard, sans garantie. Avec les photos dedans, l'app grossissait à chaque
/// photo (Android finissait par tuer l'onglet) et une photo affichée pouvait
/// ne pas être réellement enregistrée.
///
/// Les anciennes versions stockaient les octets dans la table `medias` :
/// [ensureReady] les transfère (copie confirmée, puis suppression de la ligne)
/// et [readBytes] garde une lecture de repli tant qu'il en reste.
class PhotoStoreWeb implements PhotoStore {
  final Database db;
  final BlobBackend backend;
  final Uuid _uuid = const Uuid();
  PhotoStoreWeb(this.db, this.backend);

  @override
  Future<void> ensureReady() async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS medias(id TEXT PRIMARY KEY, bytes BLOB NOT NULL)');
    await _transfererAnciennesImages();
  }

  /// Transfère les images de la table `medias` vers [backend], une par une
  /// (pour limiter la mémoire). Une ligne n'est supprimée qu'après écriture
  /// confirmée. Un échec n'empêche pas l'app de démarrer : on réessaiera au
  /// prochain lancement, et [readBytes] lit encore l'ancienne table.
  Future<void> _transfererAnciennesImages() async {
    final ids = (await db.query('medias', columns: ['id']))
        .map((r) => r['id'] as String)
        .toList();
    if (ids.isEmpty) return;
    var transferees = 0;
    try {
      for (final id in ids) {
        final bytes = await _lireAncienne(id);
        if (bytes != null) await backend.put(id, bytes);
        await db.delete('medias', where: 'id = ?', whereArgs: [id]);
        transferees++;
      }
    } catch (e) {
      debugPrint('Transfert des images interrompu : $e');
    }
    if (transferees > 0) {
      // Rend la place : sinon le fichier SQLite (gardé en mémoire) reste gros.
      try {
        await db.execute('VACUUM');
      } catch (e) {
        debugPrint('VACUUM impossible : $e');
      }
    }
  }

  Future<Uint8List?> _lireAncienne(String key) async {
    final rows = await db.query('medias',
        columns: ['bytes'], where: 'id = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final b = rows.first['bytes'];
    if (b is Uint8List) return b;
    if (b is List<int>) return Uint8List.fromList(b);
    return null;
  }

  @override
  Future<String> importBytes(Uint8List bytes, String subdir, String ext) async {
    final key = '$subdir/${_uuid.v4()}.$ext';
    await backend.put(key, bytes);
    return key;
  }

  @override
  Future<Uint8List?> readBytes(String key) async =>
      await backend.get(key) ?? await _lireAncienne(key);

  @override
  Future<void> delete(String key) async {
    await backend.delete(key);
    await db.delete('medias', where: 'id = ?', whereArgs: [key]);
  }
}
