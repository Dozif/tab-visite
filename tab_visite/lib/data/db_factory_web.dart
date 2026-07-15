import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Web : SQLite compilé en WASM, persisté dans IndexedDB du navigateur.
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
