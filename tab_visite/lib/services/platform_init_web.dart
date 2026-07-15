import 'package:sqflite/sqflite.dart';
import '../data/database.dart';
import 'photo_store.dart';
import 'photo_store_web.dart';

/// Web : base persistée dans IndexedDB (sqflite_common_ffi_web), images en
/// blobs dans la table `medias` de cette même base.
Future<(Database, PhotoStore)> openDbAndStorage() async {
  final db = await AppDatabase.open(path: 'tab_visite.db');
  final storage = PhotoStoreWeb(db);
  await storage.ensureReady();
  return (db, storage);
}
