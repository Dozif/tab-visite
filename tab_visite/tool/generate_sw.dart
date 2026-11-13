// Génère `sw.js` (service worker hors-ligne) dans le dossier du build web.
//
//   dart run tool/generate_sw.dart build/web
//
// Le service worker de Flutter est abandonné (le fichier généré se désinstalle
// tout seul) : sans le nôtre, l'app ne démarre pas sans réseau. Celui-ci met en
// cache, à l'installation, tous les fichiers du build (+ la police Roboto que
// Flutter va chercher chez Google), puis sert l'app depuis ce cache.
//
// La version (nom du cache) est une empreinte du contenu des fichiers : chaque
// nouveau déploiement change `sw.js`, ce qui déclenche la mise à jour.
import 'dart:convert';
import 'dart:io';

/// Fichiers à mettre en cache, chemins relatifs au build (séparateur `/`).
List<String> listPrecache(Directory build) {
  final root = build.absolute.path.replaceAll('\\', '/');
  final out = <String>['./'];
  for (final e in build.listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = e.absolute.path.replaceAll('\\', '/').substring(root.length + 1);
    if (_exclu(rel)) continue;
    out.add(rel);
  }
  out.sort();
  return out;
}

bool _exclu(String rel) {
  final nom = rel.split('/').last;
  if (nom.startsWith('.')) return true; // .last_build_id, etc.
  if (rel.endsWith('.symbols') || rel.endsWith('.map')) return true;
  if (rel == 'sw.js' || rel == 'flutter_service_worker.js') return true;
  // Variantes du moteur non utilisées par le rendu canvaskit (dart2js).
  if (rel.startsWith('canvaskit/skwasm') ||
      rel.startsWith('canvaskit/wimp') ||
      rel.startsWith('canvaskit/experimental_webparagraph/')) {
    return true;
  }
  return false;
}

/// Polices téléchargées par le moteur Flutter chez Google (Roboto par défaut).
List<String> fontUrls(Directory build) {
  final js = File('${build.path}/main.dart.js');
  if (!js.existsSync()) return const [];
  final m = RegExp(r'"(roboto/v\d+/[A-Za-z0-9_\-]+\.woff2)"')
      .allMatches(js.readAsStringSync())
      .map((m) => 'https://fonts.gstatic.com/s/${m.group(1)}')
      .toSet()
      .toList()
    ..sort();
  return m;
}

/// Empreinte FNV-1a 32 bits des chemins et contenus.
String buildVersion(Directory build, List<String> assets) {
  var h = 0x811c9dc5;
  void mix(List<int> bytes) {
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
  }

  for (final rel in assets) {
    mix(utf8.encode(rel));
    if (rel == './') continue;
    mix(File('${build.path}/$rel').readAsBytesSync());
  }
  return h.toRadixString(16).padLeft(8, '0');
}

void generate(Directory build) {
  final assets = listPrecache(build);
  final fonts = fontUrls(build);
  final version = buildVersion(build, assets);
  final sw = _template
      .replaceAll('__VERSION__', version)
      .replaceAll('__ASSETS__', const JsonEncoder.withIndent('  ').convert(assets))
      .replaceAll('__FONTS__', jsonEncode(fonts));
  File('${build.path}/sw.js').writeAsStringSync(sw);
  stdout.writeln('sw.js : version $version, ${assets.length} fichiers, '
      '${fonts.length} police(s).');
}

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'build/web' : args.first);
  if (!File('${dir.path}/index.html').existsSync()) {
    stderr.writeln('Build web introuvable : ${dir.path}');
    exit(1);
  }
  generate(dir);
}

const _template = r'''
// Généré par tool/generate_sw.dart — ne pas modifier à la main.
'use strict';

const VERSION = '__VERSION__';
const CACHE = 'tab-visite-' + VERSION;
const RUNTIME = 'tab-visite-runtime';
const ASSETS = __ASSETS__;
const FONTS = __FONTS__;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // cache: 'reload' : ne pas reprendre une copie périmée du cache HTTP.
    await cache.addAll(ASSETS.map((u) => new Request(u, { cache: 'reload' })));
    // Polices Google : au mieux (l'app reste utilisable sans).
    await Promise.all(FONTS.map(async (u) => {
      try {
        const r = await fetch(u, { mode: 'cors' });
        if (r.ok) await cache.put(u, r);
      } catch (_) {}
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const k of await caches.keys()) {
      if (k.startsWith('tab-visite-') && k !== CACHE && k !== RUNTIME) {
        await caches.delete(k);
      }
    }
    await self.clients.claim();
  })());
});

const SCOPE = new URL(self.registration.scope).pathname;

async function depuisCache(request) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(request, { ignoreSearch: true });
  if (hit) return hit;
  return fetch(request);
}

async function cacheRuntime(request) {
  const hit = await caches.match(request);
  if (hit) return hit;
  const r = await fetch(request);
  if (r.ok || r.type === 'opaque') {
    const cache = await caches.open(RUNTIME);
    await cache.put(request, r.clone());
  }
  return r;
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (url.origin === self.location.origin) {
    if (!url.pathname.startsWith(SCOPE)) return;
    if (req.mode === 'navigate') {
      // Toujours la page de l'app, même sans réseau.
      event.respondWith((async () => {
        const cache = await caches.open(CACHE);
        return (await cache.match('./', { ignoreSearch: true })) ||
            (await cache.match('index.html')) || fetch(req);
      })());
      return;
    }
    event.respondWith(depuisCache(req));
    return;
  }

  // Polices et moteur éventuellement demandés chez Google.
  if (url.hostname === 'fonts.gstatic.com' || url.hostname === 'www.gstatic.com') {
    event.respondWith(cacheRuntime(req));
  }
});
''';
