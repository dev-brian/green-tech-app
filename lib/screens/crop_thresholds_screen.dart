import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/variable_config.dart';
import '../models/crop_thresholds.dart';
import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';

/// Umbrales efectivos de un cultivo, en **solo lectura**.
///
/// Antes aquí había un editor que guardaba en el teléfono: no tenía efecto
/// en el semáforo ni en las alertas, que el backend calcula con los umbrales
/// de Firestore. Ahora se muestran los mismos rangos que usa el backend.
class CropThresholdsScreen extends StatelessWidget {
  const CropThresholdsScreen({
    super.key,
    required this.greenhouse,
    required this.umbrales,
  });

  final Greenhouse greenhouse;
  final CropThresholds umbrales;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: Text(
          'Umbrales · ${umbrales.crop.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: subtextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estos son los rangos que usa el backend para el '
                        'semáforo y las alertas. Se gestionan en la PWA; '
                        'solo el administrador puede cambiarlos.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subtextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final group in VariableGroup.values) ...[
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Row(
                    children: [
                      Icon(group.icon, size: 18, color: subtextColor),
                      const SizedBox(width: 6),
                      Text(
                        group.label.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final variable in variablesOf(group)) ...[
                  _rangoCard(
                    context,
                    variable,
                    isDark: isDark,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rangoCard(
    BuildContext context,
    HydroVariable variable, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    final spec = variableSpecs[variable]!;
    final rango = umbrales.ranges[variable]!;
    final personalizada = umbrales.personalizadas.contains(variable);

    return Container(
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 18,
      ),
      child: Semantics(
        label: '${spec.label}: precaución de ${spec.display(rango.yellowMin)} '
            'a ${spec.display(rango.yellowMax)}. '
            'Crítico por debajo de ${spec.display(rango.redMin)} o por encima '
            'de ${spec.display(rango.redMax)}.'
            '${personalizada ? ' Valor personalizado.' : ''}',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(spec.icon, size: 18, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.unit.isEmpty ? spec.label : '${spec.label} (${spec.unit})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                key: Key('umbral_precaucion_${variable.name}'),
                'Precaución  ${spec.display(rango.yellowMin)} – '
                '${spec.display(rango.yellowMax)}',
                style: GoogleFonts.inter(fontSize: 13, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                key: Key('umbral_critico_${variable.name}'),
                'Crítico  < ${spec.display(rango.redMin)} · '
                '> ${spec.display(rango.redMax)}',
                style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
              ),
              if (personalizada) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.estadoTexto(
                        EstadoNivel.normal,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Valor personalizado',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.estadoTexto(
                          EstadoNivel.normal,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
