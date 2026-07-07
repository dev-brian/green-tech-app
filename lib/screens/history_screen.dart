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

  String _rango = 'hoy'; // hoy | semana | mes
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
      appBar: AppBar(title: const Text('Histórico de datos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: _rangos.map((r) {
                final selected = r.$1 == _rango;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(r.$2),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _rango = r.$1);
                        _load();
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary),
                      showCheckmark: false,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text('Temperatura (°C)', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 20, 8),
                          child: ChartWidget(points: _temp, color: AppColors.critico),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Humedad del suelo (%)', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 20, 8),
                          child: ChartWidget(points: _humedad, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
