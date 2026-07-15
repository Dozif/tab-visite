import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/database.dart';
import 'data/db_factory.dart';
import 'services/app_context.dart';
import 'services/photo_store_io.dart';
import 'services/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDatabaseFactory();
  final docs = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(path: p.join(docs.path, 'tab_visite.db'));
  final storage = PhotoStoreIo(docs);
  await storage.ensureReady();

  final ctx = AppContext(db, storage);
  final seed = SeedService(ctx.plans, ctx.zones, storage);
  final zonesJson = await rootBundle.loadString('assets/seed/zones.json');
  await seed.seedIfEmpty(zonesJson, (asset) async {
    final bytes = await rootBundle.load('assets/plans/$asset');
    return bytes.buffer.asUint8List();
  });

  runApp(Provider.value(value: ctx, child: const MyApp()));
}
