import '../models/sensor_model.dart';
import 'firestore_dates.dart';
import 'zone_status_adapter.dart';

/// Adapter entre un documento de `greenhouses/{id}/alerts/{alertId}`
/// (contrato v0.2, sección 2.5) y [AlertItem].
///
/// Es el único lugar de la app que conoce los campos de una alerta.
class AlertAdapter {
  AlertAdapter._();

  static const Map<String, AlertStatus> _status = {
    'new': AlertStatus.nueva,
    'attended': AlertStatus.atendida,
    'auto_resolved': AlertStatus.autoResuelta,
  };

  /// Campos que la app escribe al atender una alerta. Son los únicos que
  /// permiten las reglas de Firestore (`isValidAlertAcknowledge`).
  static Map<String, Object?> attendPatch(String uid, Object attendedAt) => {
        'status': 'attended',
        'attendedBy': uid,
        'attendedAt': attendedAt,
      };

  static AlertItem fromFirestore(String id, Map<String, dynamic> data) {
    final variable = ZoneStatusAdapter.variableFromField(data['variable']);
    final value = data['value'];
    return AlertItem(
      id: id,
      zoneId: (data['zoneId'] ?? data['sector'] ?? '').toString(),
      variable: variable,
      // `critical` (o el viejo `red`) es crítico; cualquier otra cosa, aviso.
      nivel: switch (data['severity']) {
        'critical' || 'red' => EstadoNivel.critico,
        _ => EstadoNivel.alerta,
      },
      value: value is num ? value.toDouble() : null,
      mensaje: (data['message'] as String?)?.trim().isNotEmpty == true
          ? data['message'] as String
          : 'Alerta en ${data['zoneId'] ?? 'una zona'}',
      fecha: parseFecha(data['createdAt']) ?? DateTime.now(),
      status: _status[data['status']] ?? AlertStatus.nueva,
      attendedBy: data['attendedBy'] as String?,
      attendedAt: parseFecha(data['attendedAt']),
      resolvedAt: parseFecha(data['resolvedAt']),
    );
  }
}
