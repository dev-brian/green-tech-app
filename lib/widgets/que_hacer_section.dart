import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/plain_language.dart';
import '../config/variable_config.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../services/alerts_controller.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'live_clock.dart';
import 'variable_card.dart';

/// Una variable fuera de rango en una zona, para "Qué hacer ahora".
class Pendiente {
  const Pendiente(this.zone, this.variable, this.measurement);
  final ZoneStatus zone;
  final HydroVariable variable;
  final Measurement measurement;
}

/// Variables en alerta o crítico de las zonas que siguen reportando,
/// críticas primero. El nivel lo manda el backend.
List<Pendiente> pendientesDe(List<ZoneStatus> zonas, DateTime now) {
  final lista = <Pendiente>[
    for (final z in zonas)
      if (!lecturaDesactualizada(z.timestamp, now))
        for (final v in HydroVariable.values)
          if (z[v] case final m? when m.level != EstadoNivel.normal)
            Pendiente(z, v, m),
  ];
  lista.sort((a, b) {
    final c = b.measurement.level.index.compareTo(a.measurement.level.index);
    return c != 0 ? c : a.zone.zoneId.compareTo(b.zone.zoneId);
  });
  return lista;
}

/// Encabezado del inicio "sencillo primero": una frase que dice si hay
/// algo que hacer.
class ResumenHoy extends StatelessWidget {
  const ResumenHoy({super.key, required this.zonas, required this.now});

  final List<ZoneStatus> zonas;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final text2 =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    final pendientes = pendientesDe(zonas, now);
    final sinDatos =
        zonas.where((z) => lecturaDesactualizada(z.timestamp, now)).length;
    final urgentes = pendientes
        .where((p) => p.measurement.level == EstadoNivel.critico)
        .length;
    final n = pendientes.length;

    final String titulo;
    final String detalle;
    final EstadoNivel? tono;
    if (n > 0) {
      titulo = n == 1 ? 'Hay 1 cosa por revisar' : 'Hay $n cosas por revisar';
      detalle = urgentes > 0
          ? '${urgentes == 1 ? '1 es urgente' : '$urgentes son urgentes'}. '
              'Abajo te decimos qué hacer.'
          : 'Nada urgente. Abajo te decimos qué hacer.';
      tono = urgentes > 0 ? EstadoNivel.critico : EstadoNivel.alerta;
    } else if (sinDatos > 0) {
      titulo = sinDatos == 1
          ? 'No llegan datos de una zona'
          : 'No llegan datos de $sinDatos zonas';
      detalle = 'Revisa que el equipo de la zona tenga luz e internet.';
      tono = null;
    } else {
      titulo = 'Todo en orden';
      detalle = zonas.length == 1
          ? 'Tu zona está bien. No tienes que hacer nada.'
          : 'Tus ${zonas.length} zonas están bien. No tienes que hacer nada.';
      tono = EstadoNivel.normal;
    }

    final acento = tono == null
        ? (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)
        : AppColors.estadoTexto(tono, isDark: isDark);
    final icono = switch (tono) {
      null => Icons.wifi_off_rounded,
      EstadoNivel.normal => Icons.check_circle_rounded,
      EstadoNivel.alerta => Icons.warning_rounded,
      EstadoNivel.critico => Icons.report_rounded,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const Key('resumen_hoy'),
        padding: const EdgeInsets.all(18),
        decoration: NeumorphismDecoration.extruded(
          context: context,
          isDark: isDark,
          borderRadius: 20,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: acento.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icono, color: acento, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detalle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      height: 1.4,
                      color: text2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Qué hacer ahora": una tarjeta por variable fuera de rango, con qué
/// significa, qué hace el sistema solo y qué hace el productor.
class QueHacerSection extends StatelessWidget {
  const QueHacerSection({
    super.key,
    required this.zonas,
    required this.now,
    required this.onOpenZone,
  });

  final List<ZoneStatus> zonas;
  final DateTime now;
  final void Function(String zoneId) onOpenZone;

  @override
  Widget build(BuildContext context) {
    final pendientes = pendientesDe(zonas, now);
    if (pendientes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const TituloSeccion('Qué hacer ahora'),
        for (final p in pendientes) ...[
          const SizedBox(height: 12),
          _ConsejoCard(
            pendiente: p,
            now: now,
            onOpenZone: () => onOpenZone(p.zone.zoneId),
          ),
        ],
      ],
    );
  }
}

/// Título de sección del inicio ("Qué hacer ahora", "Tus zonas").
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      child: Text(
        texto,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ConsejoCard extends StatelessWidget {
  const _ConsejoCard({
    required this.pendiente,
    required this.now,
    required this.onOpenZone,
  });

  final Pendiente pendiente;
  final DateTime now;
  final VoidCallback onOpenZone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final text2 =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final well = isDark ? AppColors.darkWell : AppColors.well;

    final p = pendiente;
    final spec = variableSpecs[p.variable]!;
    final consejo = consejoPara(p.variable, p.measurement.value);
    final acento = AppColors.estadoTexto(p.measurement.level, isDark: isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: well,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(spec.icon, color: acento, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consejo.titulo,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_zonaLegible(p.zone.zoneId)} · '
                      '${nombreSimple(p.variable)} · '
                      '${formatHace(p.zone.timestamp, now).toLowerCase()}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5, color: text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                spec.display(p.measurement.value),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              EstadoPill(estado: p.measurement.level),
            ],
          ),
          const SizedBox(height: 12),
          _Linea(titulo: 'Qué significa', texto: consejo.significa),
          if (consejo.sistema case final s?)
            _Linea(titulo: 'Qué hace el sistema', texto: s),
          _Linea(titulo: 'Qué haces tú', texto: consejo.hacesTu, fuerte: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _YaLoReviseButton(pendiente: p),
              TextButton.icon(
                onPressed: onOpenZone,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Ver la zona'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "zona-1" → "Zona 1".
  static String _zonaLegible(String id) {
    final limpio = id.replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (limpio.isEmpty) return id;
    return limpio[0].toUpperCase() + limpio.substring(1);
  }
}

class _Linea extends StatelessWidget {
  const _Linea(
      {required this.titulo, required this.texto, this.fuerte = false});
  final String titulo;
  final String texto;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final text2 =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$titulo: ',
            style: TextStyle(fontWeight: FontWeight.w800, color: text),
          ),
          TextSpan(
            text: texto,
            style: TextStyle(
              color: fuerte ? text : text2,
              fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ]),
        style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.45),
      ),
    );
  }
}

/// Marca como atendida la alerta abierta de esa zona y variable, si existe.
class _YaLoReviseButton extends StatelessWidget {
  const _YaLoReviseButton({required this.pendiente});
  final Pendiente pendiente;

  @override
  Widget build(BuildContext context) {
    final alertas = AlertsController.instance;
    return ValueListenableBuilder<List<AlertItem>>(
      valueListenable: alertas.alerts,
      builder: (context, lista, _) {
        AlertItem? abierta;
        for (final a in lista) {
          if (a.activa &&
              a.zoneId == pendiente.zone.zoneId &&
              a.variable == pendiente.variable) {
            abierta = a;
            break;
          }
        }
        final uid = GreenhouseSession.instance.uid;
        if (abierta == null || uid == null) return const SizedBox.shrink();
        final alerta = abierta;
        return FilledButton.icon(
          onPressed: () async {
            final ok = await alertas.attend(alerta, uid);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok
                  ? 'Listo, marcamos la alerta como revisada.'
                  : 'No se pudo marcar. Intenta de nuevo.'),
            ));
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Ya lo revisé'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        );
      },
    );
  }
}
