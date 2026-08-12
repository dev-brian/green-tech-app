import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/alert_tile.dart';
import '../widgets/location_picker_dialog.dart';

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
    try {
      final data = await _api.getAlertas();
      if (!mounted) return;
      setState(() {
        _alerts = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar las alertas: $e')),
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
    final visibles =
        _soloActivas ? _alerts.where((a) => a.activa).toList() : _alerts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Alertas de Cultivo',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Center(
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
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: _soloActivas,
                            onSelected: (v) => setState(() => _soloActivas = v),
                            selectedColor: AppColors.accentOrange.withValues(alpha: 0.15),
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: _soloActivas
                                    ? AppColors.accentOrange
                                    : AppColors.border,
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
                                  color: AppColors.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            )
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
              ),
            ),
    );
  }
}
