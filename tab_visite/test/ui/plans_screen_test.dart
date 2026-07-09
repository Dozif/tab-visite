import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:tab_visite/data/database.dart';
import 'package:tab_visite/data/models/plan.dart';
import 'package:tab_visite/services/app_context.dart';
import 'package:tab_visite/services/file_storage.dart';
import 'package:tab_visite/ui/home/plans_screen.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  testWidgets('affiche les plans existants', (tester) async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final root = Directory.systemTemp.createTempSync('tv_ui');
    final ctx = AppContext(db, FileStorage(root));
    await ctx.plans.insert(Plan(id: 'p1', nom: 'Voiture M–Y', cheminImage: 'plans/x.png', ordre: 0, dateCreation: 0));

    await tester.pumpWidget(Provider.value(
      value: ctx,
      child: const MaterialApp(home: PlansScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Voiture M–Y'), findsOneWidget);
    root.deleteSync(recursive: true);
  });
}
