import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../services/sensor_data_controller.dart';
import '../utils/colors.dart';
import '../utils/neumorphism.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SensorDataController _controller = SensorDataController.instance;

  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image');
    if (path == null) return;
    if (await File(path).exists()) {
      setState(() => _imagePath = path);
    } else {
      prefs.remove('profile_image');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_image.jpg');
    await File(picked.path).copy(dest.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image', dest.path);
    if (!mounted) return;
    setState(() => _imagePath = dest.path);
  }

  Future<void> _removeImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image');
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await prefs.remove('profile_image');
    if (!mounted) return;
    setState(() => _imagePath = null);
  }

  Future<void> _signOut() async {
    await FirebaseService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email =
        FirebaseService.instance.currentUserEmail ?? 'usuario@greentech.com';

    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Perfil de Usuario',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: () => AppThemeController.toggleTheme(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: NeumorphismDecoration.extruded(
                  context: context,
                  isDark: isDark,
                  borderRadius: 20,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.mintAccent.withValues(alpha: isDark ? 0.3 : 0.4),
                            backgroundImage: _imagePath != null
                                ? FileImage(File(_imagePath!))
                                : null,
                            child: _imagePath == null
                                ? const Icon(
                                    Icons.person,
                                    color: AppColors.secondary,
                                    size: 52,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.photo_camera, size: 18),
                                    color: AppColors.secondary,
                                    onPressed: _pickImage,
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  if (_imagePath != null)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      color: AppColors.critico,
                                      onPressed: _removeImage,
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        email,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Productor agrícola · Green Tech',
                        style: GoogleFonts.inter(
                          color: subtextColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Preferencias de la Aplicación',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: NeumorphismDecoration.extruded(
                  context: context,
                  isDark: isDark,
                  borderRadius: 18,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Modo Oscuro Neumórfico',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      secondary: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppColors.primary,
                      ),
                      value: isDark,
                      activeThumbColor: AppColors.primary,
                      onChanged: (_) => AppThemeController.toggleTheme(),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(
                        'Alertas de temperatura',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                      ),
                      value: _controller.notifTemp,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setState(() => _controller.setNotifPref('temp', v)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(
                        'Alertas de humedad ambiental',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                      ),
                      value: _controller.notifHumedadAire,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setState(() => _controller.setNotifPref('humedad_aire', v)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text(
                        'Alertas de humedad del suelo',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                      ),
                      value: _controller.notifHumedadSuelo,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) => setState(() => _controller.setNotifPref('humedad_suelo', v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: AppColors.critico),
                label: Text(
                  'Cerrar sesión',
                  style: GoogleFonts.inter(
                    color: AppColors.critico,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.critico),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
