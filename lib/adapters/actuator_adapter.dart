import '../models/actuator_state.dart';
import 'firestore_dates.dart';

/// Adapter de `greenhouses/{id}/actuators/{zoneId}` a [ZoneActuators].
///
/// Documento que escribe el backend:
/// `{ zoneId, recirculationPump: {on, updatedAt, updatedBy}, phDoser, nutrientDoser, ventilation, updatedAt }`.
class ActuatorAdapter {
  ActuatorAdapter._();

  static ZoneActuators fromFirestore(String zoneId, Map<String, dynamic> data) {
    return ZoneActuators(
      zoneId: zoneId,
      updatedAt: parseFecha(data['updatedAt']),
      actuators: {
        for (final kind in ActuatorKind.values)
          if (data[kind.name] case final Map raw when raw['on'] is bool)
            kind: ActuatorStatus(
              on: raw['on'] as bool,
              updatedAt: parseFecha(raw['updatedAt']),
              updatedBy: raw['updatedBy']?.toString(),
            ),
      },
    );
  }
}
