import '../repositories/actuators_repository.dart';
import '../repositories/alerts_repository.dart';
import '../repositories/demo_repositories.dart';
import '../repositories/history_repository.dart';
import 'mock_zone_status_source.dart';
import 'zone_status_source.dart';

/// Juego de fuentes de datos que usa la app: o todas de Firestore (con
/// sesión) o todas de prueba (modo demo).
///
/// Factory Method: [DataSources.firestore] y [DataSources.demo] crean las
/// implementaciones concretas; el resto de la app solo ve las interfaces.
class DataSources {
  const DataSources._({
    required this.zones,
    required this.alerts,
    required this.history,
    required this.actuators,
    required this.isDemo,
  });

  final ZoneStatusSource zones;
  final AlertsRepository alerts;
  final HistoryRepository history;
  final ActuatorsRepository actuators;

  /// true en "Continuar sin cuenta": datos de prueba, sin Firestore.
  final bool isDemo;

  factory DataSources.firestore() => DataSources._(
        zones: FirestoreZoneStatusSource(),
        alerts: FirestoreAlertsRepository(),
        history: FirestoreHistoryRepository(),
        actuators: FirestoreActuatorsRepository(),
        isDemo: false,
      );

  factory DataSources.demo({MockZoneStatusSource? mock}) {
    final source = mock ?? MockZoneStatusSource();
    return DataSources._(
      zones: source,
      alerts: MockAlertsRepository(source),
      history: MockHistoryRepository(),
      actuators: MockActuatorsRepository(source),
      isDemo: true,
    );
  }
}
