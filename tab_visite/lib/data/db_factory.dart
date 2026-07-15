// Sélecteur de configuration de la base selon la plateforme.
// - mobile/desktop/VM (tests) : voir db_factory_io.dart
// - web : voir db_factory_web.dart (sqflite_common_ffi_web / IndexedDB)
export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
