import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/services/pending_capture_store.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('set/get/clear et unicité de la ligne', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final store = PendingCaptureStore(db);

    // Aucun contexte au départ.
    expect(await store.get(), isNull);

    // set puis get.
    await store.set('z1', 'v1', 100);
    final ctx = await store.get();
    expect(ctx!.zoneId, 'z1');
    expect(ctx.visiteId, 'v1');

    // set remplace : une seule ligne conservée.
    await store.set('z2', null, 200);
    final ctx2 = await store.get();
    expect(ctx2!.zoneId, 'z2');
    expect(ctx2.visiteId, isNull);
    expect((await db.query('pending_capture')).length, 1);

    // clear vide la table.
    await store.clear();
    expect(await store.get(), isNull);

    await db.close();
  });
}
