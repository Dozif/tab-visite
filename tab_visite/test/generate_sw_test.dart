import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_sw.dart';

void main() {
  late Directory dir;

  void write(String rel, String content) {
    final f = File('${dir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sw_test');
    write('index.html', '<html></html>');
    write('main.dart.js',
        'x="https://fonts.gstatic.com/s/";y="roboto/v32/ABC.woff2";');
    write('flutter_bootstrap.js', 'boot');
    write('sqlite3.wasm', 'wasm');
    write('assets/assets/plans/image1.png', 'png');
    write('canvaskit/chromium/canvaskit.wasm', 'ck');
    write('canvaskit/chromium/canvaskit.js.symbols', 'sym');
    write('canvaskit/skwasm.wasm', 'sk');
    write('canvaskit/wimp.wasm', 'wimp');
    write('canvaskit/experimental_webparagraph/a.wasm', 'exp');
    write('flutter_service_worker.js', 'old');
    write('.last_build_id', 'id');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('liste les fichiers utiles, exclut symboles/variantes inutiles/SW', () {
    final assets = listPrecache(dir);
    expect(
        assets,
        containsAll([
          './',
          'index.html',
          'main.dart.js',
          'flutter_bootstrap.js',
          'sqlite3.wasm',
          'assets/assets/plans/image1.png',
          'canvaskit/chromium/canvaskit.wasm',
        ]));
    for (final exclu in [
      'canvaskit/chromium/canvaskit.js.symbols',
      'canvaskit/skwasm.wasm',
      'canvaskit/wimp.wasm',
      'canvaskit/experimental_webparagraph/a.wasm',
      'flutter_service_worker.js',
      'sw.js',
      '.last_build_id',
    ]) {
      expect(assets, isNot(contains(exclu)), reason: exclu);
    }
  });

  test('ajoute la police Roboto trouvée dans main.dart.js', () {
    expect(fontUrls(dir),
        ['https://fonts.gstatic.com/s/roboto/v32/ABC.woff2']);
  });

  test('la version change quand un fichier change', () {
    final v1 = buildVersion(dir, listPrecache(dir));
    expect(buildVersion(dir, listPrecache(dir)), v1);
    write('main.dart.js', 'modifié');
    expect(buildVersion(dir, listPrecache(dir)), isNot(v1));
  });

  test('génère sw.js avec version, fichiers et polices', () {
    generate(dir);
    final sw = File('${dir.path}/sw.js').readAsStringSync();
    expect(sw, contains('"main.dart.js"'));
    expect(sw, contains('https://fonts.gstatic.com/s/roboto/v32/ABC.woff2'));
    expect(sw, contains("addEventListener('fetch'"));
    expect(sw, isNot(contains('__VERSION__')));
  });
}
