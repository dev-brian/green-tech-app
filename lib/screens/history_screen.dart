import 'package:flutter/material.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/chart_widget.dart';

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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final temp = await _api.getHistorico(metric: 'temperatura', rango: _rango);
    final hum = await _api.getHistorico(metric: 'humedad_suelo', rango: _rango);
    if (!mounted) return;
    setState(() {
      _temp = temp;
      _humedad = hum;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 720;
          final padding = wide ? 24.0 : 16.0;

          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Histórico de cultivo',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      const Text(
                        'Revisa el comportamiento de la temperatura y la humedad del suelo.',
                        style: TextStyle(color: AppColors.textSecondary),
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
                            labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600),
                            backgroundColor: AppColors.surfaceVariant,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
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
                const Center(child: CircularProgressIndicator()),
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
                            ? _avg(_temp).toStringAsFixed(1) + '°C'
                            : '-'),
                    _statCard(
                        'Temp. max',
                        _temp.isNotEmpty
                            ? _max(_temp).toStringAsFixed(1) + '°C'
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
                        Text('Temperatura (°C)',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        ChartWidget(
                          points: _temp,
                          color: AppColors.critico,
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
                            ? _avg(_humedad).toStringAsFixed(0) + '%'
                            : '-'),
                    _statCard(
                        'Humed. min',
                        _humedad.isNotEmpty
                            ? _min(_humedad).toStringAsFixed(0) + '%'
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
                        Text('Humedad del suelo (%)',
                            style: Theme.of(context).textTheme.titleLarge),
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
    );
  }
}
