import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/chart_widget.dart';
import '../widgets/location_picker_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();

  String _rango = 'hoy';
  bool _loading = true;
  List<ChartPoint> _temp = [];
  List<ChartPoint> _humedad = [];

  final _rangos = const [
    ('hoy', 'Hoy'),
    ('semana', 'Semana'),
    ('mes', 'Mes'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _avg(List<ChartPoint> pts) =>
      pts.map((p) => p.value).reduce((a, b) => a + b) / pts.length;

  double _max(List<ChartPoint> pts) =>
      pts.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  double _min(List<ChartPoint> pts) =>
      pts.map((p) => p.value).reduce((a, b) => a < b ? a : b);

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final temp =
          await _api.getHistorico(metric: 'temperatura', rango: _rango);
      final hum =
          await _api.getHistorico(metric: 'humedad_suelo', rango: _rango);
      if (!mounted) return;
      setState(() {
        _temp = temp;
        _humedad = hum;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el historial: $e')),
      );
    }
  }

  Future<void> _changeLocation() async {
    final result = await showLocationPicker(
      context: context,
      api: _api,
      initialLocation: _api.currentLocation,
    );

    if (result != null && result.trim().isNotEmpty) {
      _api.setLocation(result.trim());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Histórico de Métricas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Cambiar ubicación',
            onPressed: _changeLocation,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 650;
              final padding = wide ? 24.0 : 16.0;

              return ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico de cultivo',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Revisa el comportamiento de la temperatura y la humedad del suelo.',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            runSpacing: 10,
                            spacing: 10,
                            children: _rangos.map((r) {
                              final selected = r.$1 == _rango;
                              return ChoiceChip(
                                label: Text(r.$2),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() => _rango = r.$1);
                                  _load();
                                },
                                selectedColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                labelStyle: GoogleFonts.inter(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: AppColors.surfaceVariant,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                showCheckmark: false,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loading) ...[
                    const SizedBox(height: 120),
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    const SizedBox(height: 120),
                  ] else ...[
                    // Estadísticas rápidas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statCard(
                            'Temp. última',
                            _temp.isNotEmpty
                                ? '${_temp.last.value.toStringAsFixed(1)}°C'
                                : '-'),
                        _statCard(
                            'Temp. avg',
                            _temp.isNotEmpty
                                ? '${_avg(_temp).toStringAsFixed(1)}°C'
                                : '-'),
                        _statCard(
                            'Temp. max',
                            _temp.isNotEmpty
                                ? '${_max(_temp).toStringAsFixed(1)}°C'
                                : '-'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temperatura (°C)',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ChartWidget(
                              points: _temp,
                              color: AppColors.accentOrange,
                              height: wide ? 280 : 220,
                              showLabels: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statCard(
                            'Humed. última',
                            _humedad.isNotEmpty
                                ? '${_humedad.last.value.toStringAsFixed(0)}%'
                                : '-'),
                        _statCard(
                            'Humed. avg',
                            _humedad.isNotEmpty
                                ? '${_avg(_humedad).toStringAsFixed(0)}%'
                                : '-'),
                        _statCard(
                            'Humed. min',
                            _humedad.isNotEmpty
                                ? '${_min(_humedad).toStringAsFixed(0)}%'
                                : '-'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Humedad del suelo (%)',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ChartWidget(
                              points: _humedad,
                              color: AppColors.primary,
                              height: wide ? 280 : 220,
                              showLabels: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
