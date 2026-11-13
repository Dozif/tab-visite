import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/repositories/reglages_repository.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  test('destinataires par défaut puis modifiables', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final repo = ReglagesRepository(db);
    expect(await repo.destinataires(),
        ['franck.dozieres@sncf.fr', 'denis.martel@sncf.fr']);
    await repo.setDestinataires(['chef@sncf.fr']);
    expect(await repo.destinataires(), ['chef@sncf.fr']);
    await repo.setDestinataires([]);
    expect(await repo.destinataires(), isEmpty);
    await db.close();
  });

  test('parseAdresses : virgules, points-virgules, espaces, doublons', () {
    expect(parseAdresses(' a@x.fr ; b@x.fr,\n a@x.fr  c@x.fr '),
        ['a@x.fr', 'b@x.fr', 'c@x.fr']);
    expect(parseAdresses('   '), isEmpty);
  });
}
