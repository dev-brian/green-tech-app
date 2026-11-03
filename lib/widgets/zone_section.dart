import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/variable_config.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../utils/colors.dart';
import 'live_clock.dart';
import 'variable_card.dart';

/// Ordena las zonas de peor a mejor estado: crítico, sin datos recientes,
/// alerta y normal. A igual estado, por id.
///
/// Una zona sin datos recientes va justo después de las críticas: su último
/// nivel ya no es confiable y alguien tiene que revisar el equipo.
List<ZoneStatus> zonasPorSeveridad(Iterable<ZoneStatus> zonas, DateTime now) {
  int rango(ZoneStatus z) {
    if (lecturaDesactualizada(z.timestamp, now)) return 1;
    return switch (z.overallLevel) {
      EstadoNivel.critico => 0,
      EstadoNivel.alerta => 2,
      EstadoNivel.normal => 3,
    };
  }

  return zonas.toList()
    ..sort((a, b) {
      final porRango = rango(a).compareTo(rango(b));
      return porRango != 0 ? porRango : a.zoneId.compareTo(b.zoneId);
    });
}

/// Sección de una zona: encabezado con su estado y dos grupos de tarjetas
/// (Ambiente y Solución nutritiva).
class ZoneSection extends StatelessWidget {
  const ZoneSection({
    super.key,
    required this.zone,
    required this.now,
    this.onOpen,
  });

  final ZoneStatus zone;
  final DateTime now;

  /// Abre el detalle de esta zona.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final stale = lecturaDesactualizada(zone.timestamp, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.zoneId,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      EstadoPill(estado: zone.overallLevel, desactualizada: stale),
                      Text(
                        formatHace(zone.timestamp, now),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onOpen != null)
              IconButton(
                // IconButton ya garantiza un objetivo táctil de 48 x 48.
                onPressed: onOpen,
                tooltip: 'Ver detalle de ${zone.zoneId}',
                icon: Icon(Icons.chevron_right_rounded, color: subtextColor),
              ),
          ],
        ),
        for (final group in VariableGroup.values) ...[
          const SizedBox(height: 14),
          _GroupHeader(group: group, color: subtextColor),
          const SizedBox(height: 8),
          _CardGrid(
            children: [
              for (final v in variablesOf(group))
                VariableCard(
                  variable: v,
                  measurement: zone[v],
                  desactualizada: stale,
                  onTap: onOpen,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.color});

  final VariableGroup group;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(group.icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            group.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rejilla de 2 columnas (4 en pantallas anchas) cuyas filas toman el alto
/// de su tarjeta más alta, así crecen con el tamaño de letra del sistema en
/// lugar de recortar texto.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.children});

  final List<Widget> children;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 600 ? 4 : 2;
      return Column(
        children: [
          for (var i = 0; i < children.length; i += columns) ...[
            if (i > 0) const SizedBox(height: _gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: i + c < children.length
                          ? children[i + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
