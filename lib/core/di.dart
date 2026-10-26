import 'package:get_it/get_it.dart';

import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/sensor_data_controller.dart';
import '../services/telemetry_repository.dart';

/// Localizador de servicios de la app.
///
/// Patrón Singleton con inyección de dependencias: cada servicio existe una
/// sola vez, pero se crea y se registra AQUÍ, en un solo lugar, en vez de
/// que cada clase tenga su propio `static instance`. Las pantallas lo piden
/// con `sl<SensorDataController>()` y las pruebas pueden registrar
/// versiones falsas sin tocar Firebase.
final GetIt sl = GetIt.instance;

/// Registra los servicios. Se llama una vez en `main()`, después de
/// inicializar Firebase. Los `registerLazySingleton` no crean nada hasta la
/// primera vez que alguien pide el servicio.
void setupDependencies() {
  // Fachadas sobre plugins nativos (siguen siendo una sola instancia).
  sl.registerLazySingleton<FirebaseService>(() => FirebaseService.instance);
  sl.registerLazySingleton<NotificationService>(
      () => NotificationService.instance);

  // Repositorios: la app solo conoce la interfaz, no Firestore.
  sl.registerLazySingleton<TelemetryRepository>(
      () => FirestoreTelemetryRepository());

  // Controladores de estado compartidos entre pantallas.
  sl.registerLazySingleton<SensorDataController>(
    () => SensorDataController(
      repository: sl<TelemetryRepository>(),
      notifications: sl<NotificationService>(),
    ),
  );
}
