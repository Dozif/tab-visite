import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test de fumée minimal et autonome. Sa présence empêche `flutter create`
// (exécuté en CI) de régénérer le test par défaut qui référence un MyApp
// incompatible avec notre bootstrap (MyApp requiert un Provider<AppContext>).
void main() {
  testWidgets('smoke: une MaterialApp se construit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
