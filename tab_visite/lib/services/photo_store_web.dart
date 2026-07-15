import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'photo_store.dart';

/// Implémentation web : les images sont des blobs stockés dans la table
/// `medias` de la base — elle-même persistée dans IndexedDB par
/// sqflite_common_ffi_web. La clé est l'identifiant `<subdir>/<uuid>.<ext>`.
///
/// N'utilise que l'API standard `Database`, donc testable sur la VM avec une
/// base ffi en mémoire.
class PhotoStoreWeb implements PhotoStore {
  final Database db;
  final Uuid _uuid = const Uuid();
  PhotoStoreWeb(this.db);

  @override
  Future<void> ensureReady() async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS medias(id TEXT PRIMARY KEY, bytes BLOB NOT NULL)');
  }

  @override
  Future<String> importBytes(Uint8List bytes, String subdir, String ext) async {
    final key = '$subdir/${_uuid.v4()}.$ext';
    await db.insert('medias', {'id': key, 'bytes': bytes},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return key;
  }

  @override
  Future<Uint8List?> readBytes(String key) async {
    final rows = await db.query('medias',
        columns: ['bytes'], where: 'id = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    final b = rows.first['bytes'];
    if (b is Uint8List) return b;
    if (b is List<int>) return Uint8List.fromList(b);
    return null;
  }

  @override
  Future<void> delete(String key) async {
    await db.delete('medias', where: 'id = ?', whereArgs: [key]);
  }
}
