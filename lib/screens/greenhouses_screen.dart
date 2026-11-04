import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../services/greenhouse_repository.dart';
import '../utils/colors.dart';
import '../utils/form_style.dart';
import '../utils/neumorphism.dart';
import 'greenhouse_detail_screen.dart';

/// Invernaderos del productor: alta, edición, borrado y acceso a los
/// cultivos y umbrales de cada uno.
class GreenhousesScreen extends StatefulWidget {
  const GreenhousesScreen({super.key});

  @override
  State<GreenhousesScreen> createState() => _GreenhousesScreenState();
}

class _GreenhousesScreenState extends State<GreenhousesScreen> {
  final GreenhouseRepository _repository = GreenhouseRepository.instance;

  @override
  void initState() {
    super.initState();
    // Si ya está cargado no hace nada; si no, el ValueNotifier repinta.
    _repository.load();
  }

  void _openDetail(Greenhouse greenhouse) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GreenhouseDetailScreen(greenhouseId: greenhouse.id),
      ),
    );
  }

  Future<void> _save(Greenhouse? existing) async {
    final result = await showGreenhouseForm(context, existing: existing);
    if (result == null) return;
    if (existing == null) {
      await _repository.addGreenhouse(result);
    } else {
      await _repository.updateGreenhouse(result);
    }
  }

  Future<void> _delete(Greenhouse greenhouse) async {
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
          title: const Text('¿Eliminar invernadero?'),
          content: Text(
            'Se eliminará "${greenhouse.name}" junto con sus cultivos y '
            'umbrales.',
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
      await _repository.deleteGreenhouse(greenhouse.id);
    }
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
        title: Text(
          'Invernaderos',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            tooltip: isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
            onPressed: () => AppThemeController.toggleTheme(),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Greenhouse>>(
        valueListenable: _repository.greenhouses,
        builder: (context, greenhouses, _) {
          if (greenhouses.isEmpty) {
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
                      'TUS INVERNADEROS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: subtextColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final greenhouse in greenhouses) ...[
                    _greenhouseCard(
                      greenhouse,
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
        onPressed: () => _save(null),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'Agregar invernadero',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _greenhouseCard(
    Greenhouse greenhouse, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    final crops = greenhouse.crops.length;
    final subtitle = [
      if (greenhouse.location.isNotEmpty) greenhouse.location,
      crops == 1 ? '1 cultivo' : '$crops cultivos',
    ].join(' · ');

    return Container(
      key: Key('greenhouse_${greenhouse.id}'),
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 18,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(greenhouse),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondary
                      .withValues(alpha: isDark ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warehouse_outlined,
                  color: AppColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greenhouse.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _save(greenhouse),
                tooltip: 'Editar invernadero ${greenhouse.name}',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.secondary,
                ),
              ),
              IconButton(
                onPressed: () => _delete(greenhouse),
                tooltip: 'Eliminar invernadero ${greenhouse.name}',
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.estadoTexto(
                    EstadoNivel.critico,
                    isDark: isDark,
                  ),
                ),
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
              Icons.warehouse_outlined,
              size: 56,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Aún no tienes invernaderos',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Agrega uno para guardar sus cultivos y los umbrales de luz, '
              'pH, temperatura y demás variables.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _save(null),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(64, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                'Agregar invernadero',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario para crear o editar un invernadero. Devuelve el invernadero
/// listo para guardar, o null si se cancela.
Future<Greenhouse?> showGreenhouseForm(
  BuildContext context, {
  Greenhouse? existing,
}) {
  return showDialog<Greenhouse>(
    context: context,
    builder: (_) => _GreenhouseForm(existing: existing),
  );
}

class _GreenhouseForm extends StatefulWidget {
  const _GreenhouseForm({this.existing});

  final Greenhouse? existing;

  @override
  State<_GreenhouseForm> createState() => _GreenhouseFormState();
}

class _GreenhouseFormState extends State<_GreenhouseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _location = TextEditingController(text: widget.existing?.location ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    Navigator.of(context).pop(
      Greenhouse(
        id: existing?.id ?? nuevoId(),
        name: _name.text.trim(),
        location: _location.text.trim(),
        crops: existing?.crops ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Dialog(
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.surface,
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
                widget.existing == null
                    ? 'Nuevo invernadero'
                    : 'Editar invernadero',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('greenhouse_name'),
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
                decoration: inputDecoration('Nombre', isDark: isDark),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un nombre'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('greenhouse_location'),
                controller: _location,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                style: GoogleFonts.inter(fontSize: 14, color: textColor),
                decoration:
                    inputDecoration('Ubicación (opcional)', isDark: isDark),
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
