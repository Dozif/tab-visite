import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database.dart';
import 'photo_store.dart';
import 'photo_store_io.dart';

/// Mobile/desktop : base fichier sous le répertoire documents, images en
/// fichiers.
Future<(Database, PhotoStore)> openDbAndStorage() async {
  final docs = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(path: p.join(docs.path, 'tab_visite.db'));
  final storage = PhotoStoreIo(docs);
  await storage.ensureReady();
  return (db, storage);
}
