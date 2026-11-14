/// Rol del usuario dentro de un invernadero (`greenhouses/{id}/members/{uid}`).
enum GreenhouseRole {
  admin('Administrador'),
  operador('Operador');

  const GreenhouseRole(this.label);
  final String label;

  static GreenhouseRole parse(Object? raw) =>
      raw == 'admin' ? GreenhouseRole.admin : GreenhouseRole.operador;
}

/// Invernadero al que pertenece el usuario. Es el mismo "workspace" que
/// usa la PWA: `greenhouses/{id}` con `name` y `memberIds`.
class Greenhouse {
  final String id;
  final String name;
  final GreenhouseRole role;

  const Greenhouse({required this.id, required this.name, required this.role});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role.name};

  static Greenhouse? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    return Greenhouse(
      id: id,
      name: raw['name'] is String ? raw['name'] as String : 'Invernadero',
      role: GreenhouseRole.parse(raw['role']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Greenhouse &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}
