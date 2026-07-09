import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/database.dart';
import 'services/app_context.dart';
import 'services/file_storage.dart';
import 'services/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(path: p.join(docs.path, 'tab_visite.db'));
  final storage = FileStorage(docs);
  await storage.ensureDirs();

  final ctx = AppContext(db, storage);
  final seed = SeedService(ctx.plans, ctx.zones, storage);
  final zonesJson = await rootBundle.loadString('assets/seed/zones.json');
  await seed.seedIfEmpty(zonesJson, (asset) async {
    final bytes = await rootBundle.load('assets/plans/$asset');
    return bytes.buffer.asUint8List();
  });

  runApp(Provider.value(value: ctx, child: const MyApp()));
}
