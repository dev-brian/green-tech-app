import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/variable_config.dart';
import '../models/greenhouse.dart';
import '../models/zone_status.dart';
import '../services/greenhouse_repository.dart';
import '../utils/colors.dart';
import '../utils/form_style.dart';
import '../utils/neumorphism.dart';

/// Solo dígitos con coma o punto decimal (también se pega desde otro lado;
/// el formateador lo recorta).
final _numero = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Editor de umbrales de un cultivo: su nombre y el rango mínimo/máximo
/// que el productor quiere mantener para cada variable hidropónica.
///
/// Los umbrales se guardan en el dispositivo como referencia; la app no
/// calcula niveles con ellos (el Dashboard sigue pintando el nivel del
/// backend).
class ThresholdEditorScreen extends StatefulWidget {
  const ThresholdEditorScreen({
    super.key,
    required this.greenhouseId,
    required this.cropId,
  });

  final String greenhouseId;
  final String cropId;

  @override
  State<ThresholdEditorScreen> createState() => _ThresholdEditorScreenState();
}

class _ThresholdEditorScreenState extends State<ThresholdEditorScreen> {
  final GreenhouseRepository _repository = GreenhouseRepository.instance;
  final _formKey = GlobalKey<FormState>();

  Crop? _crop;
  late final TextEditingController _name;
  final Map<HydroVariable, TextEditingController> _min = {};
  final Map<HydroVariable, TextEditingController> _max = {};

  @override
  void initState() {
    super.initState();
    final greenhouse = _repository.greenhouseById(widget.greenhouseId);
    _crop = greenhouse?.cropById(widget.cropId);
    _name = TextEditingController(text: _crop?.name ?? '');
    for (final variable in HydroVariable.values) {
      final threshold = _crop?.thresholds[variable];
      _min[variable] = TextEditingController(
        text: threshold == null ? '' : variable.spec.format(threshold.min),
      );
      _max[variable] = TextEditingController(
        text: threshold == null ? '' : variable.spec.format(threshold.max),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final controller in [..._min.values, ..._max.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parse(String raw) {
    final limpio = raw.trim().replaceAll(',', '.');
    if (limpio.isEmpty) return null;
    return double.tryParse(limpio);
  }

  /// Un campo solo se considera válido si los dos traen número y el
  /// mínimo no supera al máximo. Dejar los dos vacíos quita el umbral.
  String? Function(String?) _validador(HydroVariable variable) {
    return (raw) {
      final texto = (raw ?? '').trim();
      if (texto.isEmpty) {
        final min = _parse(_min[variable]!.text);
        final max = _parse(_max[variable]!.text);
        if (min == null && max == null) return null;
        return 'Completa los dos campos';
      }
      if (_parse(texto) == null) return 'Número no válido';
      final min = _parse(_min[variable]!.text);
      final max = _parse(_max[variable]!.text);
      if (min == null || max == null) return 'Completa los dos campos';
      if (min > max) return 'El mínimo no puede superar al máximo';
      return null;
    };
  }

  void _save() {
    final crop = _crop;
    if (crop == null) {
      Navigator.of(context).pop();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final thresholds = <HydroVariable, VariableThreshold>{};
    for (final variable in HydroVariable.values) {
      final min = _parse(_min[variable]!.text);
      final max = _parse(_max[variable]!.text);
      if (min == null || max == null) continue;
      thresholds[variable] = VariableThreshold(min: min, max: max);
    }

    _repository.updateCrop(
      widget.greenhouseId,
      crop.copyWith(name: _name.text.trim(), thresholds: thresholds),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    if (_crop == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          title: Text(
            'Umbrales',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Text(
            'Cultivo no encontrado',
            style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        title: Text(
          'Umbrales',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _save,
            tooltip: 'Guardar cambios',
            icon: const Icon(Icons.check_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  decoration: NeumorphismDecoration.extruded(
                    context: context,
                    isDark: isDark,
                    borderRadius: 18,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextFormField(
                      key: const Key('crop_name'),
                      controller: _name,
                      style: GoogleFonts.inter(fontSize: 14, color: textColor),
                      decoration:
                          inputDecoration('Nombre del cultivo', isDark: isDark),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Ingresa un nombre'
                              : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Deja los dos campos vacíos para no configurar esa '
                  'variable.',
                  style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
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
                  Container(
                    decoration: NeumorphismDecoration.extruded(
                      context: context,
                      isDark: isDark,
                      borderRadius: 18,
                    ),
                    child: Column(
                      children: [
                        for (final (index, variable)
                            in variablesOf(group).indexed) ...[
                          if (index > 0)
                            const Divider(
                              height: 1,
                              indent: 14,
                              endIndent: 14,
                            ),
                          _ThresholdRow(
                            variable: variable,
                            isDark: isDark,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            minController: _min[variable]!,
                            maxController: _max[variable]!,
                            validator: _validador(variable),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.variable,
    required this.isDark,
    required this.textColor,
    required this.subtextColor,
    required this.minController,
    required this.maxController,
    required this.validator,
  });

  final HydroVariable variable;
  final bool isDark;
  final Color textColor;
  final Color subtextColor;
  final TextEditingController minController;
  final TextEditingController maxController;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final spec = variable.spec;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spec.icon, size: 18, color: subtextColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  spec.unit.isEmpty
                      ? spec.label
                      : '${spec.label} (${spec.unit})',
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('umbral_min_${variable.name}'),
                  controller: minController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_numero],
                  style: GoogleFonts.inter(fontSize: 14, color: textColor),
                  decoration: inputDecoration('Mín', isDark: isDark),
                  validator: validator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: Key('umbral_max_${variable.name}'),
                  controller: maxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_numero],
                  style: GoogleFonts.inter(fontSize: 14, color: textColor),
                  decoration: inputDecoration('Máx', isDark: isDark),
                  validator: validator,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
