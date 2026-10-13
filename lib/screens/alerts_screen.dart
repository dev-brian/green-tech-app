import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../widgets/alert_tile.dart';

/// Pantalla de Alertas: ya NO calcula sus propios umbrales. Lee las
/// alertas directamente de [SensorDataController], que las genera con las
/// mismas reglas de semáforo que usa el Dashboard (sensor_model.dart) a
/// partir de la lectura en tiempo real de los sensores. Así el Dashboard y
/// las Alertas siempre están de acuerdo.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final SensorDataController _controller = SensorDataController.instance;
  bool _soloActivas = false;

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
          'Alertas de Cultivo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: () => AppThemeController.toggleTheme(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _controller.loading,
            builder: (context, loading, _) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loading ? null : () => _controller.start(),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, loading, _) {
          return ValueListenableBuilder<List<AlertItem>>(
            valueListenable: _controller.alerts,
            builder: (context, allAlerts, __) {
              if (loading && allAlerts.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              final visibles = _soloActivas
                  ? allAlerts.where((a) => a.activa).toList()
                  : allAlerts;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(
                                'Solo activas',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _soloActivas
                                      ? AppColors.accentOrange
                                      : textColor,
                                ),
                              ),
                              selected: _soloActivas,
                              onSelected: (v) =>
                                  setState(() => _soloActivas = v),
                              selectedColor: AppColors.accentOrange
                                  .withValues(alpha: isDark ? 0.25 : 0.15),
                              backgroundColor: isDark
                                  ? AppColors.darkSurface
                                  : AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _soloActivas
                                      ? AppColors.accentOrange
                                      : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.border),
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: visibles.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay alertas para mostrar',
                                  style: GoogleFonts.inter(
                                    color: subtextColor,
                                    fontSize: 15,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _controller.start(),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: visibles.length,
                                  itemBuilder: (context, i) =>
                                      AlertTile(alert: visibles[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
