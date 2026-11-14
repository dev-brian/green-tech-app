import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sensor_model.dart';
import '../services/firebase_service.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import 'dashboard_screen.dart';
import 'join_greenhouse_screen.dart';
import 'login_screen.dart';

/// Pantalla de paso después del login: busca los invernaderos del usuario
/// y lo lleva al Dashboard, o a unirse a uno si todavía no tiene.
class HomeGate extends StatefulWidget {
  const HomeGate({super.key, this.session});

  /// Para pruebas; por defecto, [GreenhouseSession.instance].
  final GreenhouseSession? session;

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  GreenhouseSession get _session => widget.session ?? GreenhouseSession.instance;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    final uid = FirebaseService.instance.currentUser?.uid;
    if (uid == null) {
      _go(const LoginScreen());
      return;
    }
    final result = await _session.load(uid);
    if (!mounted) return;
    switch (result) {
      case GreenhouseLoadResult.ready:
        _go(const DashboardScreen());
      case GreenhouseLoadResult.none:
        _go(const JoinGreenhouseScreen());
      case GreenhouseLoadResult.error:
        setState(() => _error = true);
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _signOut() async {
    await FirebaseService.instance.signOut();
    await _session.clear();
    if (mounted) _go(const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: !_error
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Buscando tus invernaderos…',
                        style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 42,
                          color: AppColors.estadoTexto(
                              EstadoNivel.alerta,
                              isDark: isDark)),
                      const SizedBox(height: 12),
                      Text(
                        'No se pudieron cargar tus invernaderos',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Revisa tu conexión a internet e inténtalo de nuevo.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: _signOut,
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
