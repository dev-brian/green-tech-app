import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sensor_model.dart';
import '../services/firebase_service.dart';
import '../services/greenhouse_repository.dart';
import '../services/greenhouse_session.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// El usuario aún no pertenece a ningún invernadero: se une con el código
/// de invitación que genera el administrador en la PWA. Crear invernaderos
/// y administrar miembros se queda en la PWA.
class JoinGreenhouseScreen extends StatefulWidget {
  const JoinGreenhouseScreen({super.key, this.session});

  final GreenhouseSession? session;

  @override
  State<JoinGreenhouseScreen> createState() => _JoinGreenhouseScreenState();
}

class _JoinGreenhouseScreenState extends State<JoinGreenhouseScreen> {
  GreenhouseSession get _session => widget.session ?? GreenhouseSession.instance;
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final user = FirebaseService.instance.currentUser;
    if (user == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await _session.join(
        uid: user.uid,
        code: _codeCtrl.text,
        email: user.email,
        name: user.displayName,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
    } on GreenhouseException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = 'No se pudo unir. Inténtalo de nuevo');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseService.instance.signOut();
    await _session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: NeumorphismDecoration.extruded(
                  context: context,
                  isDark: isDark,
                  borderRadius: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(color: AppColors.primary),
                      ),
                    const Icon(Icons.home_work_outlined,
                        size: 44, color: AppColors.secondary),
                    const SizedBox(height: 16),
                    Text(
                      'Únete a tu invernadero',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu cuenta todavía no está en ningún invernadero. '
                      'Pídele el código de invitación a tu administrador '
                      '(lo encuentra en la web, en Ajustes del invernadero).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 14, color: subtextColor),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('join_code'),
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_loading) _join();
                      },
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Código de invitación',
                        labelStyle:
                            GoogleFonts.inter(fontSize: 14, color: subtextColor),
                        prefixIcon:
                            const Icon(Icons.vpn_key_outlined, color: AppColors.secondary),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurface
                            : const Color(0xFFE2E8F0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMsg!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.estadoTexto(EstadoNivel.critico,
                              isDark: isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      key: const Key('join_submit'),
                      onPressed: _loading ? null : _join,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Unirme',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : _signOut,
                      child: const Text('Usar otra cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
