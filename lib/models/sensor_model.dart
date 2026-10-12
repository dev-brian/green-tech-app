/// Estados posibles derivados de las lecturas del sensor.
enum EstadoNivel { normal, alerta, critico }

/// Representa una lectura de un sensor ESP32 en un momento dado.
class SensorReading {
  final String sensorId;
  final String ubicacion;
  final double temperatura;
  final double humedadAire;
  final double humedadSuelo;
  final DateTime timestamp;

  SensorReading({
    required this.sensorId,
    required this.ubicacion,
    required this.temperatura,
    required this.humedadAire,
    required this.humedadSuelo,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      sensorId: json['sensor_id'] as String,
      ubicacion: json['ubicacion'] as String,
      temperatura: (json['temperatura'] as num).toDouble(),
      humedadAire: (json['humedad_aire'] as num).toDouble(),
      humedadSuelo: (json['humedad_suelo'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'sensor_id': sensorId,
        'ubicacion': ubicacion,
        'temperatura': temperatura,
        'humedad_aire': humedadAire,
        'humedad_suelo': humedadSuelo,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Dato de prueba tal como lo definiste en la especificación.
  factory SensorReading.mock() {
    return SensorReading(
      sensorId: 'ESP32-01',
      ubicacion: 'Zona Tomate A',
      temperatura: 24.5,
      humedadAire: 65,
      humedadSuelo: 70,
      timestamp: DateTime.now(),
    );
  }

  /// Reglas de negocio: rango normal 18-26°C (ajusta según tu cultivo).
  EstadoNivel get estadoTemperatura {
    if (temperatura >= 18 && temperatura <= 26) return EstadoNivel.normal;
    if (temperatura > 26 && temperatura <= 30) return EstadoNivel.alerta;
    if (temperatura < 18 && temperatura >= 15) return EstadoNivel.alerta;
    return EstadoNivel.critico;
  }

  EstadoNivel get estadoHumedadAire {
    if (humedadAire >= 50 && humedadAire <= 80) return EstadoNivel.normal;
    if (humedadAire >= 40 && humedadAire < 50) return EstadoNivel.alerta;
    if (humedadAire > 80 && humedadAire <= 90) return EstadoNivel.alerta;
    return EstadoNivel.critico;
  }

  EstadoNivel get estadoHumedadSuelo {
    if (humedadSuelo >= 60 && humedadSuelo <= 80) return EstadoNivel.normal;
    if (humedadSuelo >= 45 && humedadSuelo < 60) return EstadoNivel.alerta;
    if (humedadSuelo > 80 && humedadSuelo <= 90) return EstadoNivel.alerta;
    return EstadoNivel.critico;
  }

  /// Estado general del cultivo (el peor de los tres indicadores).
  EstadoNivel get estadoGeneral {
    final estados = [estadoTemperatura, estadoHumedadAire, estadoHumedadSuelo];
    if (estados.contains(EstadoNivel.critico)) return EstadoNivel.critico;
    if (estados.contains(EstadoNivel.alerta)) return EstadoNivel.alerta;
    return EstadoNivel.normal;
  }

  String get mensajeEstado {
    switch (estadoGeneral) {
      case EstadoNivel.normal:
        return 'Condiciones óptimas';
      case EstadoNivel.alerta:
        return 'Atención: valores fuera de rango';
      case EstadoNivel.critico:
        return 'Riesgo de estrés térmico';
    }
  }
}

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

extension SensorReadingCopy on SensorReading {
  /// Crea una copia con overrides puntuales — usada por el simulador de
  /// sensores del Dashboard para "escribir" valores manuales encima del
  /// clima real, sin perder el resto de la lectura.
  SensorReading copyWith({
    String? sensorId,
    String? ubicacion,
    double? temperatura,
    double? humedadAire,
    double? humedadSuelo,
    DateTime? timestamp,
  }) {
    return SensorReading(
      sensorId: sensorId ?? this.sensorId,
      ubicacion: ubicacion ?? this.ubicacion,
      temperatura: temperatura ?? this.temperatura,
      humedadAire: humedadAire ?? this.humedadAire,
      humedadSuelo: humedadSuelo ?? this.humedadSuelo,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

extension SensorReadingAlerts on SensorReading {
  /// Genera las alertas de ESTA lectura usando exactamente los mismos
  /// rangos que el semáforo (estadoTemperatura/estadoHumedadAire/
  /// estadoHumedadSuelo), para que el Dashboard y la pantalla de Alertas
  /// nunca queden desincronizados entre sí.
  List<AlertItem> get alertasGeneradas {
    final items = <AlertItem>[];

    void addSiAplica(String prefijo, EstadoNivel estado, String etiqueta, String valorTexto) {
      if (estado == EstadoNivel.normal) return;
      final esCritico = estado == EstadoNivel.critico;
      items.add(AlertItem(
        id: '$prefijo-${timestamp.millisecondsSinceEpoch}',
        mensaje: esCritico
            ? '$etiqueta en nivel crítico ($valorTexto)'
            : '$etiqueta fuera de rango ($valorTexto)',
        nivel: estado,
        fecha: timestamp,
        activa: true,
      ));
    }

    addSiAplica('temp', estadoTemperatura, 'Temperatura',
        '${temperatura.toStringAsFixed(1)}°C');
    addSiAplica('aire', estadoHumedadAire, 'Humedad ambiental',
        '${humedadAire.toStringAsFixed(0)}%');
    addSiAplica('suelo', estadoHumedadSuelo, 'Humedad del suelo',
        '${humedadSuelo.toStringAsFixed(0)}%');

    if (items.isEmpty) {
      items.add(AlertItem(
        id: 'normal-${timestamp.millisecondsSinceEpoch}',
        mensaje: 'Condiciones óptimas en todos los sensores',
        nivel: EstadoNivel.normal,
        fecha: timestamp,
        activa: false,
      ));
    }

    return items;
  }
}
