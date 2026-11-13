{{flutter_js}}
{{flutter_build_config}}

// Moteur de rendu (canvaskit) servi depuis le site lui-même et non depuis le
// CDN de Google : indispensable pour démarrer sans réseau.
// Pas de serviceWorkerSettings : le service worker de Flutter est abandonné
// (il se désinstalle tout seul) ; c'est notre sw.js qui gère le hors-ligne.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
