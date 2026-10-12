import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_status.dart';
import '../services/firebase_service.dart';
import '../services/session_storage.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import '../utils/validators.dart';
import 'dashboard_screen.dart';
import 'forgot_password_screen.dart';

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
  void initState() {
    super.initState();
    _prefillLastEmail();
  }

  /// Prellena el email con el último usado en este dispositivo (Task 1.3).
  Future<void> _prefillLastEmail() async {
    final last = await SessionStorage.getLastEmail();
    if (!mounted || last == null || _emailCtrl.text.isNotEmpty) return;
    _emailCtrl.text = last;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
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
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMsg = 'Ocurrió un error inesperado. Inténtalo de nuevo');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final ok = await FirebaseService.instance.signInWithGoogle();
      if (!ok || !mounted) return; // el usuario cerró el selector de cuentas
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMsg = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg =
            'No se pudo iniciar sesión con Google. Inténtalo de nuevo');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ForgotPasswordScreen(initialEmail: _emailCtrl.text.trim()),
    ));
  }

  void _continueWithoutAccount() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
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
                            if (!firebaseReady) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange
                                      .withValues(alpha: isDark ? 0.18 : 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.accentOrange
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: AppColors.accentOrange, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Firebase aún no está conectado en este proyecto. '
                                        'Usa "Continuar sin cuenta" para probar la app '
                                        'mientras tanto.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            TextFormField(
                              key: const Key('login_email'),
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
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
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('login_password'),
                              controller: _passCtrl,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!_loading) _submit();
                              },
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
                              validator: Validators.password,
                            ),
                            if (!_isRegisterMode)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed:
                                      _loading ? null : _openForgotPassword,
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
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
                              key: const Key('login_google'),
                              onPressed: _loading ? null : _signInWithGoogle,
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
                                  : () => setState(() {
                                        _isRegisterMode = !_isRegisterMode;
                                        _errorMsg = null;
                                      }),
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
                            // Acceso directo solo cuando Firebase no está
                            // disponible (ver `firebaseReady` en main.dart).
                            if (!firebaseReady) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _loading ? null : _continueWithoutAccount,
                              child: Text(
                                'Continuar sin cuenta (modo desarrollo)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: subtextColor,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            ],
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
