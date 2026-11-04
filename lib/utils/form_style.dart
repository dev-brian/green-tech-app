import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sensor_model.dart';
import 'colors.dart';

/// Decoración compartida por los campos de formulario de la app (nombre,
/// ubicación, umbrales): borde redondeado, fondo neumórfico y error en el
/// color con contraste AA del semáforo.
InputDecoration inputDecoration(String label, {required bool isDark}) {
  final textStyle = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final labelColor =
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  final fillColor = isDark ? AppColors.darkBackground : AppColors.background;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
  final focusColor = isDark ? AppColors.mintAccent : AppColors.secondaryDark;
  final errorColor = AppColors.estadoTexto(EstadoNivel.critico, isDark: isDark);

  OutlineInputBorder borde(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 14, color: labelColor),
    floatingLabelStyle: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: textStyle,
    ),
    errorStyle: GoogleFonts.inter(fontSize: 12, color: errorColor),
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: borde(borderColor),
    enabledBorder: borde(borderColor),
    focusedBorder: borde(focusColor, width: 1.5),
    errorBorder: borde(errorColor),
    focusedErrorBorder: borde(errorColor, width: 1.5),
  );
}

/// Fila "Cancelar / Guardar" al pie de los formularios en diálogo.
class DialogActions extends StatelessWidget {
  const DialogActions({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Guardar',
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    // Wrap en vez de Row: si los botones no caben (tipografía grande del
    // sistema), pasan a la siguiente línea en lugar de desbordar.
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: subtext,
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Text(
            'Cancelar',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Text(
            saveLabel,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
