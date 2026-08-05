import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../utils/colors.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifTemp = true;
  bool _notifHumedad = true;
  bool _notifSuelo = true;

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
    final email =
        FirebaseService.instance.currentUserEmail ?? 'usuario@greentech.com';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primary,
                      backgroundImage: _imagePath != null
                          ? FileImage(File(_imagePath!))
                          : null,
                      child: _imagePath == null
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 42)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            color: AppColors.primaryDark,
                            onPressed: _pickImage,
                          ),
                          if (_imagePath != null)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: AppColors.critico,
                              onPressed: _removeImage,
                            ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(email,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Productor agrícola',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Notificaciones', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Alertas de temperatura'),
                  value: _notifTemp,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifTemp = v),
                ),
                SwitchListTile(
                  title: const Text('Alertas de humedad ambiental'),
                  value: _notifHumedad,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifHumedad = v),
                ),
                SwitchListTile(
                  title: const Text('Alertas de humedad del suelo'),
                  value: _notifSuelo,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifSuelo = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: AppColors.critico),
            label: const Text('Cerrar sesión',
                style: TextStyle(color: AppColors.critico)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.critico),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
