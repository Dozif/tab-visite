import 'package:sqflite/sqflite.dart';
import '../data/database.dart';
import 'idb_blob_backend.dart';
import 'photo_store.dart';
import 'photo_store_web.dart';

/// Web : base persistée dans IndexedDB (sqflite_common_ffi_web) ; images
/// dans un IndexedDB dédié (voir [PhotoStoreWeb] et [IdbBlobBackend]).
Future<(Database, PhotoStore)> openDbAndStorage() async {
  final db = await AppDatabase.open(path: 'tab_visite.db');
  final storage = PhotoStoreWeb(db, await IdbBlobBackend.open());
  await storage.ensureReady();
  return (db, storage);
}
