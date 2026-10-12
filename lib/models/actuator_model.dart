import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de equipo mecánico que puede reportar un ESP32.
enum TipoActuador { bomba, ventilador, calefactor, luz, otro }

/// Estado de un equipo (bomba, ventilador, …) leído de `actuadores/{id}`.
///
/// Es la "bandera" que el ESP32 (o el simulador) publica. La app solo la
/// observa: nunca escribe en `actuadores/` (ver docs/firestore-contract.md).
class Actuador {
  final String id;
  final String nombre;
  final TipoActuador tipo;
  final String? sensorId;
  final String? greenhouseId;
  final bool encendido;
  final DateTime? actualizado;

  const Actuador({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.encendido,
    this.sensorId,
    this.greenhouseId,
    this.actualizado,
  });

  /// Tolerante con lo que escriba el simulador: `tipo` desconocido cae en
  /// [TipoActuador.otro], `encendido` ausente se toma como apagado y
  /// `actualizado` puede ser [Timestamp] o texto ISO 8601.
  factory Actuador.fromFirestore(String docId, Map<String, dynamic> data) {
    final rawTs = data['actualizado'];
    final DateTime? actualizado = switch (rawTs) {
      Timestamp t => t.toDate(),
      String s => DateTime.tryParse(s),
      _ => null,
    };
    final rawTipo = (data['tipo'] as String?)?.trim().toLowerCase();
    return Actuador(
      id: docId,
      nombre: (data['nombre'] as String?) ?? docId,
      tipo: TipoActuador.values.firstWhere(
        (t) => t.name == rawTipo,
        orElse: () => TipoActuador.otro,
      ),
      sensorId: data['sensor_id'] as String?,
      greenhouseId: data['greenhouseId'] as String?,
      encendido: data['encendido'] == true,
      actualizado: actualizado,
    );
  }
}
