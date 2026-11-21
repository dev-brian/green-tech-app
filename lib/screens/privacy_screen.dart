import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/colors.dart';

/// Aviso de privacidad de la app (checklist de servicios en la nube 02 y 18).
///
/// Describe qué datos personales guarda GreenTech en Firebase, para qué,
/// cuánto tiempo y cómo borrarlos. Se abre desde el inicio de sesión y
/// desde el Perfil.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const secciones = <(String, String)>[
    (
      'Quién es responsable',
      'GreenTech es un proyecto escolar de monitoreo de invernaderos '
          'hidropónicos. Los datos los administra el equipo del proyecto en '
          'Firebase (Google Cloud), proyecto green-tech-96bb2.',
    ),
    (
      'Qué datos guardamos',
      '• Tu correo y, si entras con Google, tu nombre: para iniciar sesión '
          '(Firebase Authentication).\n'
          '• Los invernaderos a los que perteneces y tu rol (administrador u '
          'operador).\n'
          '• El identificador de este teléfono para avisos push '
          '(users/{tu uid}/fcmTokens).\n'
          '• Quién atendió una alerta y cuándo.\n'
          'Las lecturas de los sensores son del invernadero, no tuyas. Tu foto '
          'de perfil se guarda solo en este teléfono y nunca se sube.',
    ),
    (
      'Para qué los usamos',
      'Solo para mostrarte el estado de tus invernaderos y avisarte de '
          'alertas críticas. No los vendemos, no los compartimos y no hay '
          'publicidad ni analítica de terceros.',
    ),
    (
      'Cuánto tiempo',
      '• Lecturas de sensores: 7 días; promedios por hora: 30 días.\n'
          '• El identificador push se borra al cerrar sesión.\n'
          '• Tu cuenta y tus membresías, hasta que borres tu cuenta.\n'
          'No hacemos respaldos aparte de los de Firebase.',
    ),
    (
      'Cómo borrar tus datos',
      'En Perfil → «Borrar mi cuenta». Se borran tu cuenta, tus membresías, '
          'tu identificador push y lo guardado en el teléfono. Si administras '
          'un invernadero, primero cede la administración o bórralo en la PWA.',
    ),
    (
      'Seguridad',
      'La conexión con Firebase va cifrada (HTTPS). Las reglas de Firestore '
          'solo dejan leer un invernadero a sus miembros, y la sesión se guarda '
          'cifrada en el teléfono.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(
          'Aviso de privacidad',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final (titulo, texto) in secciones) ...[
                Text(
                  titulo,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  texto,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Última actualización: 21 de noviembre de 2026.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: subtextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
