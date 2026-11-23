import 'package:flutter/material.dart';

/// Los 4 actuadores virtuales de cada zona (contrato v0.2, 2.7).
enum ActuatorKind {
  recirculationPump('Bomba de recirculación', Icons.cyclone),
  phDoser('Dosificador de pH', Icons.science_outlined),
  nutrientDoser('Dosificador de nutrientes', Icons.opacity),
  ventilation('Ventilación', Icons.air);

  const ActuatorKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Estado de un actuador. En la app es solo lectura: lo controla el backend.
class ActuatorStatus {
  final bool on;
  final DateTime? updatedAt;

  /// `backend` (lazo automático) o el uid de quien lo cambió en la PWA.
  final String? updatedBy;

  const ActuatorStatus({required this.on, this.updatedAt, this.updatedBy});
}

/// `greenhouses/{id}/actuators/{zoneId}`.
class ZoneActuators {
  final String zoneId;
  final Map<ActuatorKind, ActuatorStatus> actuators;
  final DateTime? updatedAt;

  const ZoneActuators({
    required this.zoneId,
    required this.actuators,
    this.updatedAt,
  });

  ActuatorStatus? operator [](ActuatorKind kind) => actuators[kind];
}
