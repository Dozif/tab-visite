import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tab_visite/services/file_storage.dart';

void main() {
  test('importImage copie et renvoie un chemin relatif; delete supprime', () async {
    final root = Directory.systemTemp.createTempSync('tv_test');
    final storage = FileStorage(root);
    await storage.ensureDirs();

    final src = File(p.join(root.path, 'src.jpg'))..writeAsBytesSync([1, 2, 3]);
    final rel = await storage.importImage(src, 'photos', 'jpg');

    expect(rel.startsWith('photos/'), isTrue);
    expect(storage.resolve(rel).existsSync(), isTrue);

    await storage.deleteRelative(rel);
    expect(storage.resolve(rel).existsSync(), isFalse);
    root.deleteSync(recursive: true);
  });
}
