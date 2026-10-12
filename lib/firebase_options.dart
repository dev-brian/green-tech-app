// Configuración de Firebase para el proyecto green-tech-96bb2.
// Equivalente a lo que genera `flutterfire configure` (solo Android).
// Si más adelante agregas iOS/Web, vuelve a generar este archivo con:
//   flutterfire configure --project=green-tech-96bb2
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
          'Firebase no está configurado para Web en GREEN TECH. '
          'Ejecuta `flutterfire configure` para agregarlo.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Firebase solo está configurado para Android en GREEN TECH. '
            'Ejecuta `flutterfire configure` para otras plataformas.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAOIAH3LvFbIRBL5BJxtQVQkMKR-ZOdeos',
    appId: '1:998092953685:android:824691da5d099452289cdc',
    messagingSenderId: '998092953685',
    projectId: 'green-tech-96bb2',
    storageBucket: 'green-tech-96bb2.firebasestorage.app',
  );
}
