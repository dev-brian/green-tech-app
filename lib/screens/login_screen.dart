import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isRegisterMode = false;
  bool _loading = false;
  bool _obscure = true;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      if (_isRegisterMode) {
        await FirebaseService.instance
            .signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        await FirebaseService.instance
            .signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                onPressed: () => AppThemeController.toggleTheme(),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Container(
                    decoration: NeumorphismDecoration.extruded(
                      context: context,
                      isDark: isDark,
                      borderRadius: 24,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LinearProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            Center(
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: AppColors.mintAccent
                                      .withValues(alpha: isDark ? 0.2 : 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.eco,
                                  color: AppColors.primary,
                                  size: 44,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _isRegisterMode
                                  ? 'Crear cuenta'
                                  : 'Bienvenido de nuevo',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isRegisterMode
                                  ? 'Regístrate para monitorear tus cultivos'
                                  : 'Inicia sesión para ver tus sensores',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: subtextColor,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Correo electrónico',
                                labelStyle: GoogleFonts.inter(
                                    fontSize: 14, color: subtextColor),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: AppColors.secondary,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFE2E8F0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Ingresa tu email';
                                if (!v.contains('@')) return 'Email inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: GoogleFonts.inter(
                                    fontSize: 14, color: subtextColor),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: AppColors.secondary,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: subtextColor,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFE2E8F0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Ingresa tu contraseña';
                                if (v.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            if (_errorMsg != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorMsg!,
                                style: GoogleFonts.inter(
                                  color: AppColors.critico,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                _isRegisterMode
                                    ? 'Registrarse'
                                    : 'Iniciar sesión',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _loading = true;
                                        _errorMsg = null;
                                      });
                                      try {
                                        await FirebaseService.instance
                                            .signInWithGoogle();
                                        if (!mounted) return;
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const DashboardScreen()),
                                        );
                                      } catch (e) {
                                        setState(() => _errorMsg = e
                                            .toString()
                                            .replaceFirst('Exception: ', ''));
                                      } finally {
                                        if (mounted)
                                          setState(() => _loading = false);
                                      }
                                    },
                              icon: const Icon(Icons.login,
                                  color: AppColors.secondary),
                              label: Text(
                                'Iniciar sesión con Google',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.secondary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(
                                      () => _isRegisterMode = !_isRegisterMode),
                              child: Text(
                                _isRegisterMode
                                    ? '¿Ya tienes cuenta? Inicia sesión'
                                    : '¿No tienes cuenta? Regístrate',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
