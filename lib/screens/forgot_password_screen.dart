import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../utils/colors.dart';
import '../utils/validators.dart';

/// Pantalla de recuperación de contraseña (HU-M01 / Task 1.1).
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail ?? '');

  bool _loading = false;
  bool _sent = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
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
      await FirebaseService.instance
          .sendPasswordResetEmail(email: _emailCtrl.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      // Por seguridad no revelamos si el correo existe o no.
      if (e.code == 'user-not-found') {
        setState(() => _sent = true);
      } else {
        setState(() => _errorMsg = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _sent ? _buildSent(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 24),
          const Icon(Icons.lock_reset, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          Text('¿Olvidaste tu contraseña?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Ingresa tu email y te enviaremos un enlace para restablecerla.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          TextFormField(
            key: const Key('forgot_email'),
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: Validators.email,
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(_errorMsg!,
                style: const TextStyle(color: AppColors.critico, fontSize: 13)),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.mark_email_read_outlined,
            color: AppColors.normal, size: 64),
        const SizedBox(height: 20),
        Text('Revisa tu correo',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Si existe una cuenta con ${_emailCtrl.text.trim()}, recibirás un '
          'enlace para restablecer tu contraseña. Revisa también la carpeta de spam.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}
