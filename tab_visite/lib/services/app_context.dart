import 'package:sqflite/sqflite.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import 'file_storage.dart';

class AppContext {
  final Database db;
  final FileStorage storage;
  late final PlanRepository plans = PlanRepository(db);
  late final ZoneRepository zones = ZoneRepository(db);
  late final PhotoRepository photos = PhotoRepository(db);
  AppContext(this.db, this.storage);
}
