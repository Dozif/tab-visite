// Bootstrap dépendant de la plateforme : ouvre la base et crée le stockage
// d'images adapté.
// - mobile/desktop/VM : platform_init_io.dart (fichiers + path_provider)
// - web : platform_init_web.dart (blobs dans la base IndexedDB)
export 'platform_init_io.dart'
    if (dart.library.js_interop) 'platform_init_web.dart';
