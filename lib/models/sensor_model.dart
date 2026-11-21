import 'zone_status.dart';

/// Nivel de una variable (semáforo). Lo calcula el backend; la app solo lo
/// muestra. El adaptador traduce `ok`/`warn`/`critical` a estos valores
/// (ver lib/adapters/zone_status_adapter.dart).
enum EstadoNivel { normal, alerta, critico }

/// Estado de una alerta en `greenhouses/{id}/alerts` (contrato v0.2, 2.5).
enum AlertStatus {
  /// `new`: la variable sigue fuera de rango y nadie la ha atendido.
  nueva,

  /// `attended`: un miembro la atendió desde la PWA o la app.
  atendida,

  /// `auto_resolved`: la variable volvió a `ok` y el backend la cerró.
  autoResuelta,
}

/// Una alerta tal como la crea el motor de alertas del backend.
///
/// La app NO crea alertas: las lee de Firestore (ver
/// lib/adapters/alert_adapter.dart) y lo único que puede cambiar es
/// marcarlas como atendidas.
class AlertItem {
  final String id;
  final String zoneId;

  /// null si el backend mandó una variable que la app no conoce.
  final HydroVariable? variable;
  final EstadoNivel nivel;

  /// Lectura que disparó la alerta.
  final double? value;
  final String mensaje;
  final DateTime fecha;
  final AlertStatus status;
  final String? attendedBy;
  final DateTime? attendedAt;
  final DateTime? resolvedAt;

  const AlertItem({
    required this.id,
    required this.mensaje,
    required this.nivel,
    required this.fecha,
    this.zoneId = '',
    this.variable,
    this.value,
    this.status = AlertStatus.nueva,
    this.attendedBy,
    this.attendedAt,
    this.resolvedAt,
  });

  /// Sigue abierta: nadie la ha atendido y la variable no ha vuelto a `ok`.
  bool get activa => status == AlertStatus.nueva;

  /// Copia marcada como atendida por [uid] (actualización optimista).
  AlertItem atendidaPor(String uid, DateTime cuando) => AlertItem(
        id: id,
        zoneId: zoneId,
        variable: variable,
        nivel: nivel,
        value: value,
        mensaje: mensaje,
        fecha: fecha,
        status: AlertStatus.atendida,
        attendedBy: uid,
        attendedAt: cuando,
        resolvedAt: resolvedAt,
      );
}
