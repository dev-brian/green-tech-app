import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../adapters/threshold_adapter.dart';
import '../models/crop_thresholds.dart';
import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../repositories/greenhouse_repository.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'crop_thresholds_screen.dart';

/// Umbrales reales de un invernadero de Firestore, en **solo lectura**.
///
/// Muestra los mismos rangos que usa el backend (`thresholdsByCrop` con el
/// perfil de cultivo por defecto encima). La app no calcula niveles ni
/// escribe umbrales: se gestionan en la PWA y solo el administrador puede
/// cambiarlos.
class GreenhouseDetailScreen extends StatefulWidget {
  const GreenhouseDetailScreen({
    super.key,
    required this.greenhouse,
    this.session,
    this.repository,
  });

  final Greenhouse greenhouse;
  final GreenhouseSession? session;
  final GreenhouseRepository? repository;

  @override
  State<GreenhouseDetailScreen> createState() =>
      _GreenhouseDetailScreenState();
}

class _GreenhouseDetailScreenState extends State<GreenhouseDetailScreen> {
  late final GreenhouseSession _session =
      widget.session ?? GreenhouseSession.instance;
  late final GreenhouseRepository _repository =
      widget.repository ?? FirestoreGreenhouseRepository();

  Map<CropType, CropThresholds>? _umbrales;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_session.isDemo) {
      _umbrales = ThresholdAdapter.fromFirestore({});
    } else {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    try {
      final umbrales = await _repository.thresholds(widget.greenhouse.id);
      if (mounted) setState(() => _umbrales = umbrales);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar los umbrales');
      }
    }
  }

  void _abrirCultivo(CropThresholds umbrales) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CropThresholdsScreen(
          greenhouse: widget.greenhouse,
          umbrales: umbrales,
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
    final esAdmin = widget.greenhouse.role == GreenhouseRole.admin;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: Text(
          widget.greenhouse.name,
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
              _aviso(
                icon: Icons.info_outline,
                texto: 'Rol: ${widget.greenhouse.role.label}. Los umbrales se '
                    'consultan aquí y se gestionan en la PWA'
                    '${esAdmin ? '' : ' · solo el administrador puede cambiarlos'}.',
                color: subtextColor,
              ),
              if (_session.isDemo)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _aviso(
                    icon: Icons.science_outlined,
                    texto: 'Modo demostración: umbrales de ejemplo.',
                    color: subtextColor,
                  ),
                ),
              const SizedBox(height: 20),
              if (_error != null)
                _aviso(
                  icon: Icons.wifi_off_rounded,
                  texto: _error!,
                  color: AppColors.estadoTexto(
                    EstadoNivel.alerta,
                    isDark: isDark,
                  ),
                )
              else if (_umbrales == null)
                const Center(child: CircularProgressIndicator())
              else ...[
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
                for (final umbrales in _umbrales!.values) ...[
                  _cropCard(
                    umbrales,
                    isDark: isDark,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cropCard(
    CropThresholds umbrales, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    final total = umbrales.personalizadas.length;
    final resumen = total == 0
        ? 'Perfil por defecto · sin cambios'
        : '$total ${total == 1 ? 'variable ajustada' : 'variables ajustadas'}';
    return Container(
      key: Key('crop_${umbrales.crop.name}'),
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 18,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _abrirCultivo(umbrales),
        child: Semantics(
          button: true,
          label: '${umbrales.crop.label}. $resumen. Ver umbrales',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.local_florist_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        umbrales.crop.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resumen,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aviso({
    required IconData icon,
    required String texto,
    required Color color,
  }) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
