// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:greentech_app/main.dart';

void main() {
  testWidgets('renders the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('GREEN TECH'), findsOneWidget);
    expect(find.text('Monitoreo inteligente de cultivos'), findsOneWidget);

    // Pump time to allow splash screen timer to finish
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
