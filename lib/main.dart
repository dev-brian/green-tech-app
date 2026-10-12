import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Solo importamos Firebase: firebase_core 4.x también exporta una clase
// FirebaseService que choca con la nuestra (lib/services/firebase_service.dart).
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart'; // generado por `flutterfire configure`
import 'screens/splash_screen.dart';
import 'services/app_status.dart';
import 'services/firebase_service.dart';
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
    firebaseReady = true;
    // HU-M01 / Task 1.3: sincroniza el token de sesión cifrado.
    await FirebaseService.instance.init();
  } catch (e) {
    firebaseReady = false;
    debugPrint('Firebase no está configurado todavía: $e');
  }

  await AppThemeController.init();
  await SensorDataController.instance.init();
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
