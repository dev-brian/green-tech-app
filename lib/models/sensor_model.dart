/// Nivel de una variable (semáforo). Lo calcula el backend; la app solo lo
/// muestra. El adaptador traduce `ok`/`warn`/`critical` a estos valores
/// (ver lib/adapters/zone_status_adapter.dart).
enum EstadoNivel { normal, alerta, critico }

/// Representa una alerta generada a partir de una lectura anómala.
class AlertItem {
  final String id;
  final String mensaje;
  final EstadoNivel nivel;
  final DateTime fecha;
  final bool activa;

  AlertItem({
    required this.id,
    required this.mensaje,
    required this.nivel,
    required this.fecha,
    required this.activa,
  });
}

/// Punto simple para graficar series de tiempo (temperatura/humedad).
class ChartPoint {
  final DateTime time;
  final double value;

  ChartPoint(this.time, this.value);
}
