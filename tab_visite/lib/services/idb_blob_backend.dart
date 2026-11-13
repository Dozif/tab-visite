import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'blob_backend.dart';

/// [BlobBackend] sur un IndexedDB dédié (`tab_visite_photos`), séparé de la
/// base SQLite. Web uniquement.
///
/// Chaque écriture est une transaction en durabilité « strict » : [put] ne se
/// termine qu'une fois les octets écrits sur le disque de l'appareil.
class IdbBlobBackend implements BlobBackend {
  static const _dbName = 'tab_visite_photos';
  static const _store = 'blobs';

  final web.IDBDatabase _db;
  IdbBlobBackend._(this._db);

  static Future<IdbBlobBackend> open() async {
    final req = web.window.indexedDB.open(_dbName, 1);
    req.onupgradeneeded = ((web.Event _) {
      final db = req.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_store)) {
        db.createObjectStore(_store);
      }
    }).toJS;
    final db = await _resultat(req) as web.IDBDatabase;
    return IdbBlobBackend._(db);
  }

  static Future<JSAny?> _resultat(web.IDBRequest req) {
    final c = Completer<JSAny?>();
    req.onsuccess = ((web.Event _) => c.complete(req.result)).toJS;
    req.onerror = ((web.Event _) => c.completeError(
        StateError('IndexedDB : ${req.error?.message ?? 'erreur'}'))).toJS;
    return c.future;
  }

  static Future<void> _terminee(web.IDBTransaction tx) {
    final c = Completer<void>();
    tx.oncomplete = ((web.Event _) => c.complete()).toJS;
    tx.onerror = ((web.Event _) {
      if (!c.isCompleted) {
        c.completeError(
            StateError('IndexedDB : ${tx.error?.message ?? 'erreur'}'));
      }
    }).toJS;
    tx.onabort = ((web.Event _) {
      if (!c.isCompleted) {
        c.completeError(StateError(
            'IndexedDB : transaction annulée (${tx.error?.message ?? ''})'));
      }
    }).toJS;
    return c.future;
  }

  web.IDBTransaction _tx(String mode) => _db.transaction(
      _store.toJS, mode, web.IDBTransactionOptions(durability: 'strict'));

  @override
  Future<void> put(String key, Uint8List bytes) async {
    // Le clonage d'un Uint8Array copie tout son ArrayBuffer : on n'enregistre
    // qu'une copie exacte si [bytes] est une vue sur un tampon plus grand.
    final exact = (bytes.offsetInBytes == 0 &&
            bytes.lengthInBytes == bytes.buffer.lengthInBytes)
        ? bytes
        : Uint8List.fromList(bytes);
    final tx = _tx('readwrite');
    tx.objectStore(_store).put(exact.toJS, key.toJS);
    await _terminee(tx);
  }

  @override
  Future<Uint8List?> get(String key) async {
    final tx = _tx('readonly');
    final res = await _resultat(tx.objectStore(_store).get(key.toJS));
    if (res == null || res.isUndefinedOrNull) return null;
    if (res.isA<JSUint8Array>()) return (res as JSUint8Array).toDart;
    if (res.isA<JSArrayBuffer>()) {
      return (res as JSArrayBuffer).toDart.asUint8List();
    }
    return null;
  }

  @override
  Future<void> delete(String key) async {
    final tx = _tx('readwrite');
    tx.objectStore(_store).delete(key.toJS);
    await _terminee(tx);
  }
}
