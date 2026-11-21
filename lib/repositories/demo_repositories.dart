import 'dart:async';
import 'dart:math';

import '../config/variable_config.dart';
import '../models/actuator_state.dart';
import '../models/history.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../services/mock_zone_status_source.dart';
import 'actuators_repository.dart';
import 'alerts_repository.dart';
import 'history_repository.dart';
import '../services/zone_status_source.dart';

// Repositorios del modo demo ("Continuar sin cuenta"). Hacen las veces del
// backend a partir de MockZoneStatusSource, para que la app se pueda
// enseñar sin sesión ni internet. Con sesión iniciada nunca se usan.

/// Imita al motor de alertas del backend: crea una alerta `new` cuando una
/// variable sale de `ok` (sin duplicados por zona y variable), la sube de
/// aviso a crítica si empeora y la marca `auto_resolved` al volver a `ok`.
class MockAlertsRepository implements AlertsRepository {
  MockAlertsRepository(this.source);

  final MockZoneStatusSource source;
  final List<AlertItem> _alerts = [];
  final Set<StreamController<AlertsSnapshot>> _listeners = {};
  StreamSubscription<ZoneStatusSnapshot>? _sub;
  int _seq = 0;

  @override
  Stream<AlertsSnapshot> watch(String greenhouseId) {
    late final StreamController<AlertsSnapshot> c;
    c = StreamController<AlertsSnapshot>(
      onListen: () {
        _listeners.add(c);
        _sub ??= source.watchZones(greenhouseId).listen((s) => _evaluar(s.zones));
        c.add(_snapshot());
      },
      onCancel: () async {
        _listeners.remove(c);
        if (_listeners.isEmpty) {
          await _sub?.cancel();
          _sub = null;
        }
      },
    );
    return c.stream;
  }

  AlertsSnapshot _snapshot() => AlertsSnapshot(alerts: List.unmodifiable(_alerts));

  void _emit() {
    for (final c in _listeners) {
      c.add(_snapshot());
    }
  }

  void _evaluar(Map<String, ZoneStatus> zonas) {
    var cambio = false;
    for (final zona in zonas.values) {
      for (final v in HydroVariable.values) {
        final m = zona[v];
        if (m == null) continue;
        final i = _alerts.indexWhere(
            (a) => a.zoneId == zona.zoneId && a.variable == v && a.activa);
        if (m.level == EstadoNivel.normal) {
          if (i >= 0) {
            _alerts[i] = _copia(_alerts[i], status: AlertStatus.autoResuelta);
            cambio = true;
          }
        } else if (i < 0) {
          _alerts.insert(0, AlertItem(
            id: 'demo-${_seq++}',
            zoneId: zona.zoneId,
            variable: v,
            nivel: m.level,
            value: m.value,
            mensaje: _mensaje(v, m, zona.zoneId),
            fecha: DateTime.now(),
          ));
          cambio = true;
        } else if (_alerts[i].nivel == EstadoNivel.alerta &&
            m.level == EstadoNivel.critico) {
          _alerts[i] = _copia(_alerts[i],
              nivel: EstadoNivel.critico,
              mensaje: _mensaje(v, m, zona.zoneId));
          cambio = true;
        }
      }
    }
    if (cambio) _emit();
  }

  static String _mensaje(HydroVariable v, Measurement m, String zoneId) =>
      '${v.spec.label} ${m.level == EstadoNivel.critico ? 'crítico' : 'en precaución'} '
      'en $zoneId: ${v.spec.display(m.value)}';

  AlertItem _copia(AlertItem a,
          {AlertStatus? status, EstadoNivel? nivel, String? mensaje}) =>
      AlertItem(
        id: a.id,
        zoneId: a.zoneId,
        variable: a.variable,
        nivel: nivel ?? a.nivel,
        value: a.value,
        mensaje: mensaje ?? a.mensaje,
        fecha: a.fecha,
        status: status ?? a.status,
        attendedBy: a.attendedBy,
        attendedAt: a.attendedAt,
        resolvedAt:
            status == AlertStatus.autoResuelta ? DateTime.now() : a.resolvedAt,
      );

  @override
  Future<void> attend(String greenhouseId, String alertId, String uid) async {
    final i = _alerts.indexWhere((a) => a.id == alertId);
    if (i < 0) return;
    _alerts[i] = _alerts[i].atendidaPor(uid, DateTime.now());
    _emit();
  }
}

/// Curvas suaves alrededor de los valores normales de la fuente de prueba.
class MockHistoryRepository implements HistoryRepository {
  MockHistoryRepository({Random? random}) : _random = random ?? Random(7);

  final Random _random;

  static const Map<HydroVariable, (double, double)> _base = {
    HydroVariable.airTemp: (22.5, 3),
    HydroVariable.humidity: (65, 8),
    HydroVariable.light: (18000, 12000),
    HydroVariable.ph: (6.0, 0.25),
    HydroVariable.ec: (1.8, 0.2),
    HydroVariable.solutionTemp: (20.5, 1.2),
    HydroVariable.tankLevel: (78, 10),
  };

  @override
  Future<ZoneHistory> fetch(
      String greenhouseId, String zoneId, HistoryRange range) async {
    final now = DateTime.now();
    final paso = range == HistoryRange.h24
        ? const Duration(minutes: 5)
        : const Duration(hours: 1);
    final n = range.duration.inMinutes ~/ paso.inMinutes;
    return ZoneHistory(
      zoneId: zoneId,
      range: range,
      series: {
        for (final MapEntry(key: v, value: (base, amp)) in _base.entries)
          v: [
            for (var i = n; i >= 0; i--)
              () {
                final t = now.subtract(paso * i);
                // Ciclo diario + ruido.
                final dia = sin((t.hour + t.minute / 60) / 24 * 2 * pi - pi / 2);
                final valor = base +
                    amp * 0.5 * dia +
                    amp * 0.08 * (_random.nextDouble() * 2 - 1);
                return HistoryPoint(t, valor,
                    min: range == HistoryRange.h24 ? null : valor - amp * 0.05,
                    max: range == HistoryRange.h24 ? null : valor + amp * 0.05);
              }(),
          ],
      },
    );
  }
}

/// Actuadores del modo demo, coherentes con el escenario de la zona.
class MockActuatorsRepository implements ActuatorsRepository {
  MockActuatorsRepository(this.source);

  final MockZoneStatusSource source;

  @override
  Stream<ZoneActuators?> watch(String greenhouseId, String zoneId) =>
      source.watchZones(greenhouseId).map((_) {
        final s = source.scenarioOf(zoneId);
        final now = DateTime.now();
        ActuatorStatus st(bool on) =>
            ActuatorStatus(on: on, updatedAt: now, updatedBy: 'backend');
        return ZoneActuators(
          zoneId: zoneId,
          updatedAt: now,
          actuators: {
            ActuatorKind.recirculationPump: st(s != MockScenario.tanqueBajo),
            ActuatorKind.phDoser: st(s == MockScenario.phAlto),
            ActuatorKind.nutrientDoser: st(s == MockScenario.ecBaja),
            ActuatorKind.ventilation: st(s == MockScenario.solucionCaliente),
          },
        );
      });
}
