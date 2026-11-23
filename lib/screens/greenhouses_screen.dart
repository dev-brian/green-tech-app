import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/greenhouse.dart';
import '../models/sensor_model.dart';
import '../repositories/greenhouse_repository.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'greenhouse_detail_screen.dart';
import 'greenhouse_gate_screen.dart';

/// Invernaderos de los que el usuario es miembro en Firestore.
///
/// Es la MISMA fuente que "Tus invernaderos" ([GreenhouseSession]); aquí no
/// se crea ni se borra nada: solo se consultan los umbrales reales. Para
/// unirse con un código se reutiliza [GreenhouseGateScreen].
class GreenhousesScreen extends StatefulWidget {
  const GreenhousesScreen({super.key, this.session, this.repository});

  /// Inyectable en pruebas; por defecto la sesión de la app.
  final GreenhouseSession? session;

  /// Inyectable en pruebas; por defecto el repositorio de Firestore.
  final GreenhouseRepository? repository;

  @override
  State<GreenhousesScreen> createState() => _GreenhousesScreenState();
}

class _GreenhousesScreenState extends State<GreenhousesScreen> {
  late final GreenhouseSession _session =
      widget.session ?? GreenhouseSession.instance;
  late final GreenhouseRepository _repository =
      widget.repository ?? FirestoreGreenhouseRepository();

  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_session.greenhouses.value.isEmpty &&
        !_session.isDemo &&
        _session.uid != null) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _session.load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar tus invernaderos');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirDetalle(Greenhouse greenhouse) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GreenhouseDetailScreen(
          greenhouse: greenhouse,
          session: _session,
          repository: _repository,
        ),
      ),
    );
  }

  void _unirse() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GreenhouseGateScreen(cambiar: true),
      ),
    );
  }

  List<Greenhouse> _lista() {
    final lista = _session.greenhouses.value;
    if (lista.isNotEmpty) return lista;
    final demo = _session.isDemo ? _session.current.value : null;
    return demo == null ? const [] : [demo];
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
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
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
      body: AnimatedBuilder(
        animation: Listenable.merge([_session.greenhouses, _session.current]),
        builder: (context, _) {
          if (_cargando && _lista().isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final greenhouses = _lista();
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _aviso(
                        icon: Icons.wifi_off_rounded,
                        texto: _error!,
                        color: AppColors.estadoTexto(
                          EstadoNivel.alerta,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  if (_session.isDemo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _aviso(
                        icon: Icons.science_outlined,
                        texto: 'Modo demostración: umbrales de ejemplo.',
                        color: subtextColor,
                      ),
                    ),
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
                  const SizedBox(height: 8),
                  Text(
                    'Los umbrales se consultan aquí; se gestionan en la PWA.',
                    style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _greenhouseCard(
    Greenhouse greenhouse, {
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
  }) {
    final enUso = _session.current.value?.id == greenhouse.id;
    return Container(
      key: Key('greenhouse_${greenhouse.id}'),
      decoration: NeumorphismDecoration.extruded(
        context: context,
        isDark: isDark,
        borderRadius: 18,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _abrirDetalle(greenhouse),
        child: Semantics(
          button: true,
          label: '${greenhouse.name}. ${greenhouse.role.label}. '
              '${enUso ? 'En uso. ' : ''}Ver umbrales',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enUso
                            ? '${greenhouse.role.label} · En uso'
                            : greenhouse.role.label,
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
                const SizedBox(width: 4),
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
    return Row(
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
              'Pídele un código de invitación al administrador para '
              'consultar los umbrales de su invernadero.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: subtextColor),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('unirse_con_codigo'),
              onPressed: _unirse,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(64, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.qr_code_rounded),
              label: Text(
                'Unirse con código',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
