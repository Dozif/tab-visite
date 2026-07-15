import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/db_factory.dart';
import 'services/app_context.dart';
import 'services/platform_init.dart';
import 'services/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDatabaseFactory();
  final (db, storage) = await openDbAndStorage();

  final ctx = AppContext(db, storage);
  final seed = SeedService(ctx.plans, ctx.zones, storage);
  final zonesJson = await rootBundle.loadString('assets/seed/zones.json');
  await seed.seedIfEmpty(zonesJson, (asset) async {
    final bytes = await rootBundle.load('assets/plans/$asset');
    return bytes.buffer.asUint8List();
  });

  runApp(Provider.value(value: ctx, child: const MyApp()));
}
