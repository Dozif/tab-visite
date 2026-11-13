import 'package:sqflite/sqflite.dart';
import '../data/repositories/plan_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/photo_repository.dart';
import '../data/repositories/visite_repository.dart';
import '../data/repositories/reglages_repository.dart';
import 'pending_capture_store.dart';
import 'photo_store.dart';

class AppContext {
  final Database db;
  final PhotoStore storage;
  late final PlanRepository plans = PlanRepository(db);
  late final ZoneRepository zones = ZoneRepository(db);
  late final PhotoRepository photos = PhotoRepository(db);
  late final VisiteRepository visites = VisiteRepository(db);
  late final ReglagesRepository reglages = ReglagesRepository(db);
  late final PendingCaptureStore pending = PendingCaptureStore(db);
  AppContext(this.db, this.storage);
}
