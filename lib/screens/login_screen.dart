import 'package:flutter/material.dart';
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
        await FirebaseService.instance.signUp(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        await FirebaseService.instance.signIn(email: _emailCtrl.text.trim(), password: _passCtrl.text);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.eco, color: AppColors.primary, size: 38),
                ),
                const SizedBox(height: 20),
                Text(
                  _isRegisterMode ? 'Crear cuenta' : 'Bienvenido de nuevo',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode
                      ? 'Regístrate para monitorear tus cultivos'
                      : 'Inicia sesión para ver tus sensores',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
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
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
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
                  const SizedBox(height: 12),
                  Text(_errorMsg!, style: const TextStyle(color: AppColors.critico, fontSize: 13)),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isRegisterMode ? 'Registrarse' : 'Iniciar sesión'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(
                    _isRegisterMode
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿No tienes cuenta? Regístrate',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
