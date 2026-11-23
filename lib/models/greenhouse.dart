/// Rol del usuario dentro de un invernadero (`members/{uid}.role`).
///
/// En la app el rol solo se muestra: plantas, umbrales y miembros se
/// gestionan desde la PWA.
enum GreenhouseRole {
  admin('Administrador'),
  operador('Operador'),
  desconocido('Miembro');

  const GreenhouseRole(this.label);
  final String label;
}

/// Un invernadero del que el usuario es miembro (`greenhouses/{id}`).
class Greenhouse {
  final String id;
  final String name;
  final GreenhouseRole role;

  const Greenhouse({
    required this.id,
    required this.name,
    this.role = GreenhouseRole.desconocido,
  });

  @override
  bool operator ==(Object other) =>
      other is Greenhouse &&
      other.id == id &&
      other.name == name &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}
