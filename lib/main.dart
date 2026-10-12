import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart'; // generado por `flutterfire configure`
import 'screens/splash_screen.dart';
import 'services/app_status.dart';
import 'services/notification_service.dart';
import 'services/sensor_data_controller.dart';
import 'utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  // Si Firebase falla (p. ej. plataforma sin configurar), la app sigue en
  // modo local y las pantallas lo consultan con `firebaseReady`.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Caché local de Firestore: los streams siguen entregando la última
    // lectura conocida cuando se cae la red en campo (Task 2.3).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    firebaseReady = true;
  } catch (e) {
    firebaseReady = false;
    debugPrint('Firebase no está configurado todavía: $e');
  }

  await AppThemeController.init();
  await SensorDataController.instance.init();
  // Suscripción en tiempo real a los sensores (telemetria/ en Firestore).
  SensorDataController.instance.start();
  await NotificationService.instance.init();

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
          title: 'Green Tech App',
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
