import 'package:flutter/material.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/alert_tile.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiService _api = ApiService();
  List<AlertItem> _alerts = [];
  bool _loading = true;
  bool _soloActivas = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _api.getAlertas();
    if (!mounted) return;
    setState(() {
      _alerts = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibles =
        _soloActivas ? _alerts.where((a) => a.activa).toList() : _alerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Solo activas'),
                        selected: _soloActivas,
                        onSelected: (v) => setState(() => _soloActivas = v),
                        selectedColor:
                            AppColors.critico.withValues(alpha: 0.15),
                        showCheckmark: false,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visibles.isEmpty
                      ? const Center(child: Text('No hay alertas para mostrar'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: visibles.length,
                            itemBuilder: (context, i) =>
                                AlertTile(alert: visibles[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
