import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tab_visite/services/photo_store_io.dart';

void main() {
  test('importBytes enregistre et renvoie une clé relative; readBytes/delete', () async {
    final root = Directory.systemTemp.createTempSync('tv_test');
    final store = PhotoStoreIo(root);
    await store.ensureReady();

    final key = await store.importBytes(Uint8List.fromList([1, 2, 3]), 'photos', 'jpg');
    expect(key.startsWith('photos/'), isTrue);
    expect(await store.readBytes(key), equals([1, 2, 3]));

    await store.delete(key);
    expect(await store.readBytes(key), isNull);
    root.deleteSync(recursive: true);
  });
}
