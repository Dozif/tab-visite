import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/services/photo_store_web.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('PhotoStoreWeb: importBytes/readBytes/delete via la table medias', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final store = PhotoStoreWeb(db);
    await store.ensureReady();

    final key = await store.importBytes(Uint8List.fromList([9, 8, 7]), 'photos', 'jpg');
    expect(key.startsWith('photos/'), isTrue);
    expect(await store.readBytes(key), equals([9, 8, 7]));

    // Clé absente -> null.
    expect(await store.readBytes('photos/inexistant.jpg'), isNull);

    await store.delete(key);
    expect(await store.readBytes(key), isNull);
    await db.close();
  });

  test('PhotoStoreWeb: ensureReady est idempotent', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final store = PhotoStoreWeb(db);
    await store.ensureReady();
    await store.ensureReady(); // ne doit pas lever (CREATE TABLE IF NOT EXISTS)
    await db.close();
  });
}
