import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:greentech_app/screens/forgot_password_screen.dart';
import 'package:greentech_app/screens/login_screen.dart';
import 'package:greentech_app/services/firebase_service.dart';
import 'package:greentech_app/utils/validators.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), 'Ingresa tu email');
      expect(Validators.email('foo@'), 'Email inválido');
      expect(Validators.email('foo@bar'), 'Email inválido');
      expect(Validators.email('productor@greentech.com'), isNull);
    });

    test('password', () {
      expect(Validators.password(''), 'Ingresa tu contraseña');
      expect(Validators.password('123'), 'Mínimo 6 caracteres');
      expect(Validators.password('123456'), isNull);
    });
  });

  test('mensajes de error de Firebase en español', () {
    expect(FirebaseService.messageForCode('invalid-credential'),
        'Email o contraseña incorrectos');
    expect(FirebaseService.messageForCode('network-request-failed'),
        contains('Sin conexión'));
  });

  group('LoginScreen (Task 1.1)', () {
    testWidgets('muestra el formulario y el link de recuperación',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido de nuevo'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    });

    testWidgets('valida campos vacíos sin llamar a Firebase', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
      await tester.pump();

      expect(find.text('Ingresa tu email'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('abre recuperación con el email prellenado', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('login_email')), 'productor@greentech.com');
      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.text('productor@greentech.com'), findsOneWidget);
    });
  });

  testWidgets('Task 1.3: prellena el último email guardado', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'last_login_email': 'admin@greentech.com'});
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('admin@greentech.com'), findsOneWidget);
  });
}
