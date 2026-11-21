import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Solo importamos Firebase: firebase_core 4.x también exporta una clase
// FirebaseService que choca con la nuestra (lib/services/firebase_service.dart).
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'firebase_options.dart'; // generado por `flutterfire configure`
import 'screens/splash_screen.dart';
import 'services/alerts_controller.dart';
import 'services/app_status.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/sensor_data_controller.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si Firebase falla (p. ej. plataforma sin configurar), la app sigue en
  // modo local y las pantallas lo consultan con `firebaseReady`.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Caché local de Firestore: los streams siguen entregando la última
    // lectura conocida cuando se cae la red en campo (Task 2.3).
    // Tope de 50 MB: alcanza para varios días de histórico y evita que la
    // caché crezca sin límite en el teléfono.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 50 * 1024 * 1024,
    );
    firebaseReady = true;
    // HU-M01 / Task 1.3: sincroniza el token de sesión cifrado.
    await FirebaseService.instance.init();
  } catch (e) {
    firebaseReady = false;
    debugPrint('Firebase no está configurado todavía: $e');
  }

  await AppThemeController.init();
  await SensorDataController.instance.init();
  // Las alertas nuevas solo se notifican si el usuario no apagó esa
  // variable en su Perfil.
  AlertsController.instance
      .configure(notifEnabled: SensorDataController.instance.notifEnabled);
  await NotificationService.instance.init();
  if (firebaseReady) {
    // Push FCM: registra el token al iniciar sesión (users/{uid}/fcmTokens).
    await PushService.instance.init(
      uidChanges:
          FirebaseService.instance.authStateChanges().map((u) => u?.uid),
      bandejaEscucha: AlertsController.instance.escucha,
      mostrar: NotificationService.instance.showPush,
    );
  }
  // Las suscripciones en tiempo real arrancan al elegir invernadero
  // (GreenhouseGateScreen → GreenhouseSession.select).

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'GreenTech',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
