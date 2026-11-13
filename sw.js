// Généré par tool/generate_sw.dart — ne pas modifier à la main.
'use strict';

const VERSION = 'c035c0aa';
const CACHE = 'tab-visite-' + VERSION;
const RUNTIME = 'tab-visite-runtime';
const ASSETS = [
  "./",
  "assets/AssetManifest.bin",
  "assets/AssetManifest.bin.json",
  "assets/FontManifest.json",
  "assets/NOTICES",
  "assets/assets/plans/image1.png",
  "assets/assets/plans/image10.png",
  "assets/assets/plans/image11.png",
  "assets/assets/plans/image12.png",
  "assets/assets/plans/image13.png",
  "assets/assets/plans/image14.png",
  "assets/assets/plans/image15.png",
  "assets/assets/plans/image16.png",
  "assets/assets/plans/image17.png",
  "assets/assets/plans/image18.png",
  "assets/assets/plans/image19.png",
  "assets/assets/plans/image2.png",
  "assets/assets/plans/image20.png",
  "assets/assets/plans/image21.png",
  "assets/assets/plans/image22.png",
  "assets/assets/plans/image23.png",
  "assets/assets/plans/image24.png",
  "assets/assets/plans/image25.png",
  "assets/assets/plans/image26.png",
  "assets/assets/plans/image27.png",
  "assets/assets/plans/image28.png",
  "assets/assets/plans/image29.png",
  "assets/assets/plans/image3.png",
  "assets/assets/plans/image30.png",
  "assets/assets/plans/image31.png",
  "assets/assets/plans/image32.png",
  "assets/assets/plans/image33.png",
  "assets/assets/plans/image34.png",
  "assets/assets/plans/image35.png",
  "assets/assets/plans/image36.png",
  "assets/assets/plans/image37.png",
  "assets/assets/plans/image38.png",
  "assets/assets/plans/image4.png",
  "assets/assets/plans/image5.png",
  "assets/assets/plans/image6.png",
  "assets/assets/plans/image7.png",
  "assets/assets/plans/image8.png",
  "assets/assets/plans/image9.png",
  "assets/assets/reference/motrice1n_point1.png",
  "assets/assets/reference/motrice1n_point2.png",
  "assets/assets/reference/motrice1n_point3.png",
  "assets/assets/reference/motrice1n_point4.png",
  "assets/assets/reference/motrice1n_point5.png",
  "assets/assets/reference/motrice1n_point6.png",
  "assets/assets/reference/motrice_point1.png",
  "assets/assets/reference/motrice_point2.png",
  "assets/assets/reference/point1.png",
  "assets/assets/reference/point2.png",
  "assets/assets/reference/point3.png",
  "assets/assets/reference/point4.png",
  "assets/assets/reference/point5.png",
  "assets/assets/reference/point6.png",
  "assets/assets/reference/point7.png",
  "assets/assets/reference/point8.png",
  "assets/assets/reference/remorque1n_point1.png",
  "assets/assets/reference/remorque1n_point2.png",
  "assets/assets/reference/remorque1n_point3.png",
  "assets/assets/seed/zones.json",
  "assets/fonts/MaterialIcons-Regular.otf",
  "assets/shaders/ink_sparkle.frag",
  "assets/shaders/stretch_effect.frag",
  "canvaskit/canvaskit.js",
  "canvaskit/canvaskit.wasm",
  "canvaskit/chromium/canvaskit.js",
  "canvaskit/chromium/canvaskit.wasm",
  "favicon.png",
  "flutter.js",
  "flutter_bootstrap.js",
  "icons/Icon-192.png",
  "icons/Icon-512.png",
  "icons/Icon-maskable-192.png",
  "icons/Icon-maskable-512.png",
  "index.html",
  "main.dart.js",
  "manifest.json",
  "sqflite_sw.js",
  "sqlite3.wasm",
  "version.json"
];
const FONTS = ["https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2"];

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
