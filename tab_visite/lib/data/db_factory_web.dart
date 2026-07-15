import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Web : SQLite compilé en WASM, persisté dans IndexedDB du navigateur.
//
// On utilise la variante SANS web worker : elle fait tourner SQLite dans le
// thread principal et n'exige donc pas les en-têtes COOP/COEP (SharedArrayBuffer)
// — indispensable car GitHub Pages ne permet pas de définir ces en-têtes.
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
