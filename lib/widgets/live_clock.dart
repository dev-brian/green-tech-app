import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tiempo sin lecturas nuevas a partir del cual consideramos que el
/// sensor dejó de reportar y su semáforo ya no es confiable.
const Duration vigenciaLectura = Duration(minutes: 5);

bool lecturaDesactualizada(DateTime timestamp, DateTime now) =>
    now.difference(timestamp) > vigenciaLectura;

/// "Hace 12 seg", "Hace 3 min" o la fecha si ya pasó más de una hora.
String formatHace(DateTime timestamp, DateTime now) {
  final diff = now.difference(timestamp);
  if (diff.inSeconds < 5) return 'Justo ahora';
  if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds} seg';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  return DateFormat('dd/MM HH:mm').format(timestamp);
}

/// Reconstruye [builder] periódicamente con la hora actual, para que los
/// textos relativos ("hace X seg") y el aviso de datos desactualizados
/// avancen aunque no llegue una lectura nueva.
class LiveClock extends StatefulWidget {
  final Duration interval;
  final Widget Function(BuildContext context, DateTime now) builder;

  const LiveClock({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 10),
  });

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}
