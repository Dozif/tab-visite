import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/services/blob_backend.dart';
import 'package:tab_visite/services/photo_store_web.dart';

/// Faux stockage d'octets (remplace IndexedDB sur la VM).
class _MemBackend implements BlobBackend {
  final Map<String, Uint8List> data = {};
  int puts = 0;
  bool failPuts = false;
  @override
  Future<void> put(String key, Uint8List bytes) async {
    if (failPuts) throw StateError('écriture impossible');
    puts++;
    data[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> get(String key) async => data[key];
  @override
  Future<void> delete(String key) async => data.remove(key);
}

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  Future<Database> openDb() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);
    return db;
  }

  Future<void> ancienneTable(Database db, Map<String, List<int>> rows) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS medias(id TEXT PRIMARY KEY, bytes BLOB NOT NULL)');
    for (final e in rows.entries) {
      await db.insert('medias', {'id': e.key, 'bytes': Uint8List.fromList(e.value)});
    }
  }

  test('importBytes/readBytes/delete passent par le backend, pas par SQLite',
      () async {
    final db = await openDb();
    final backend = _MemBackend();
    final store = PhotoStoreWeb(db, backend);
    await store.ensureReady();

    final key =
        await store.importBytes(Uint8List.fromList([9, 8, 7]), 'photos', 'jpg');
    expect(key.startsWith('photos/'), isTrue);
    expect(key.endsWith('.jpg'), isTrue);
    expect(backend.data[key], [9, 8, 7]);
    expect(await store.readBytes(key), [9, 8, 7]);
    expect(await store.readBytes('photos/inexistant.jpg'), isNull);

    await store.delete(key);
    expect(await store.readBytes(key), isNull);
    expect(backend.data, isEmpty);
  });

  test('ensureReady transfère les anciennes photos de la table medias', () async {
    final db = await openDb();
    await ancienneTable(db, {
      'photos/a.jpg': [1, 2],
      'plans/b.png': [3],
    });
    final backend = _MemBackend();
    final store = PhotoStoreWeb(db, backend);
    await store.ensureReady();

    expect(backend.data['photos/a.jpg'], [1, 2]);
    expect(backend.data['plans/b.png'], [3]);
    // Vidée de SQLite (la base ne garde plus les octets en mémoire).
    expect(await db.query('medias'), isEmpty);
    expect(await store.readBytes('photos/a.jpg'), [1, 2]);

    // Idempotent : rien de plus à transférer.
    await store.ensureReady();
    expect(backend.puts, 2);
  });

  test('transfert interrompu : les lignes restent lisibles et non perdues',
      () async {
    final db = await openDb();
    await ancienneTable(db, {
      'photos/a.jpg': [1, 2],
    });
    final backend = _MemBackend()..failPuts = true;
    final store = PhotoStoreWeb(db, backend);
    await store.ensureReady(); // ne doit pas lever : l'app doit démarrer

    // Rien supprimé tant que la copie n'est pas confirmée.
    expect((await db.query('medias')).length, 1);
    // Lecture de repli depuis l'ancienne table.
    expect(await store.readBytes('photos/a.jpg'), [1, 2]);
    // Suppression : retirée aussi de l'ancienne table.
    await store.delete('photos/a.jpg');
    expect(await db.query('medias'), isEmpty);
  });
}
