import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../utils/colors.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                color: AppColors.surface,
                elevation: 1,
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
                            child: LinearProgressIndicator(color: AppColors.primary),
                          ),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.mintAccent.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.eco,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isRegisterMode ? 'Crear cuenta' : 'Bienvenido de nuevo',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            labelStyle: GoogleFonts.inter(fontSize: 14),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.secondary,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa tu email';
                            if (!v.contains('@')) return 'Email inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            labelStyle: GoogleFonts.inter(fontSize: 14),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.secondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isRegisterMode ? 'Registrarse' : 'Iniciar sesión',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () =>
                                  setState(() => _isRegisterMode = !_isRegisterMode),
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
      ),
    );
  }
}
