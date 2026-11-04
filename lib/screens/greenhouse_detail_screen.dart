import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/variable_config.dart';
import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../models/zone_status.dart';
import '../services/greenhouse_repository.dart';
import '../utils/colors.dart';
import '../utils/form_style.dart';
import '../utils/neumorphism.dart';
import 'threshold_editor_screen.dart';

/// Cultivos de un invernadero: alta, borrado y acceso al editor de
/// umbrales de cada cultivo.
class GreenhouseDetailScreen extends StatefulWidget {
  const GreenhouseDetailScreen({super.key, required this.greenhouseId});

  final String greenhouseId;

  @override
  State<GreenhouseDetailScreen> createState() =>
      _GreenhouseDetailScreenState();
}

class _GreenhouseDetailScreenState extends State<GreenhouseDetailScreen> {
  final GreenhouseRepository _repository = GreenhouseRepository.instance;

  Future<void> _addCrop() async {
    final name = await showCropNameForm(context, titulo: 'Nuevo cultivo');
    if (name == null) return;
    await _repository.addCrop(
      widget.greenhouseId,
      Crop(id: nuevoId(), name: name),
    );
  }

  Future<void> _deleteCrop(Crop crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark =
            Theme.of(dialogContext).brightness == Brightness.dark;
        final cancelColor =
            isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('¿Eliminar cultivo?'),
          content: Text(
            'Se eliminará "${crop.name}" y todos sus umbrales.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: cancelColor,
                minimumSize: const Size(64, 48),
              ),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.estadoTexto(
                  EstadoNivel.critico,
                  isDark: isDark,
                ),
                minimumSize: const Size(64, 48),
              ),
              child: Text(
                'Eliminar',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _repository.deleteCrop(widget.greenhouseId, crop.id);
    }
  }

  void _openThresholds(Crop crop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThresholdEditorScreen(
          greenhouseId: widget.greenhouseId,
          cropId: crop.id,
        ),
      ),
    );
  }

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
        title: ValueListenableBuilder<List<Greenhouse>>(
          valueListenable: _repository.greenhouses,
          builder: (context, greenhouses, _) {
            final greenhouse = _find(greenhouses);
            return Text(
              greenhouse?.name ?? 'Invernadero',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            );
          },
        ),
      ),
      body: ValueListenableBuilder<List<Greenhouse>>(
        valueListenable: _repository.greenhouses,
        builder: (context, greenhouses, _) {
          final greenhouse = _find(greenhouses);
          if (greenhouse == null) {
            return Center(
              child: Text(
                'Invernadero no encontrado',
                style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
              ),
            );
          }
          if (greenhouse.crops.isEmpty) {
            return _emptyState(
              isDark: isDark,
              textColor: textColor,
              subtextColor: subtextColor,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'CULTIVOS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: subtextColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final crop in greenhouse.crops) ...[
                    _cropCard(
                      crop,
                      isDark: isDark,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCrop,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar cultivo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Greenhouse? _find(List<Greenhouse> greenhouses) {
    for (final g in greenhouses) {
      if (g.id == widget.greenhouseId) return g;
    }
    return null;
  }

  Widget _cropCard(
    Crop crop, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      key: Key('crop_${crop.id}'),
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 18,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openThresholds(crop),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_florist_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      crop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteCrop(crop),
                    tooltip: 'Eliminar cultivo ${crop.name}',
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.estadoTexto(
                        EstadoNivel.critico,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openThresholds(crop),
                    tooltip: 'Umbrales de ${crop.name}',
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (crop.thresholds.isEmpty)
                Text(
                  'Sin umbrales configurados',
                  style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in crop.thresholds.entries)
                      _ThresholdChip(
                        variable: entry.key,
                        threshold: entry.value,
                        isDark: isDark,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_florist_outlined,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Este invernadero no tiene cultivos',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Agrega un cultivo para configurar los umbrales de luz, pH, '
              'temperatura y demás variables que necesita.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rango legible de un umbral, p. ej. `Temperatura 20.0–26.0°C`.
String umbralTexto(HydroVariable variable, VariableThreshold threshold) {
  final spec = variable.spec;
  final unit = spec.unit;
  final sufijo = unit.isEmpty
      ? ''
      : (unit == '°C' || unit == '%' ? unit : ' $unit');
  return '${spec.label} ${spec.format(threshold.min)}–'
      '${spec.format(threshold.max)}$sufijo';
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({
    required this.variable,
    required this.threshold,
    required this.isDark,
  });

  final HydroVariable variable;
  final VariableThreshold threshold;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: NeumorphismDecoration.inset(isDark: isDark, borderRadius: 10),
      child: Text(
        umbralTexto(variable, threshold),
        style: GoogleFonts.inter(fontSize: 12, color: textColor),
      ),
    );
  }
}

/// Formulario para dar de alta o renombrar un cultivo. Devuelve el nombre
/// recortado, o null si se cancela.
Future<String?> showCropNameForm(
  BuildContext context, {
  required String titulo,
  String inicial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CropNameForm(titulo: titulo, inicial: inicial),
  );
}

class _CropNameForm extends StatefulWidget {
  const _CropNameForm({required this.titulo, this.inicial = ''});

  final String titulo;
  final String inicial;

  @override
  State<_CropNameForm> createState() => _CropNameFormState();
}

class _CropNameFormState extends State<_CropNameForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.titulo,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('crop_name'),
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
                decoration: inputDecoration('Nombre del cultivo', isDark: isDark),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 20),
              DialogActions(
                onCancel: () => Navigator.of(context).pop(),
                onSave: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
