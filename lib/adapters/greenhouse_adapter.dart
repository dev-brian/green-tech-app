import '../models/greenhouse.dart';

/// Adapter de `greenhouses/{id}` + `greenhouses/{id}/members/{uid}` a
/// [Greenhouse] (contrato v0.2, sección 1).
class GreenhouseAdapter {
  GreenhouseAdapter._();

  static Greenhouse fromFirestore(
    String id,
    Map<String, dynamic> data, {
    Map<String, dynamic>? member,
  }) {
    final name = (data['name'] as String?)?.trim();
    return Greenhouse(
      id: id,
      name: name == null || name.isEmpty ? 'Invernadero sin nombre' : name,
      role: roleFrom(member?['role']),
    );
  }

  static GreenhouseRole roleFrom(Object? raw) => switch (raw) {
        'admin' => GreenhouseRole.admin,
        'operador' => GreenhouseRole.operador,
        _ => GreenhouseRole.desconocido,
      };
}
