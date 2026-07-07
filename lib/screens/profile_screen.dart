import 'package:flutter/material.dart';
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
    final email = FirebaseService.instance.currentUserEmail ?? 'usuario@greentech.com';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 12),
                Text(email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Productor agrícola', style: TextStyle(color: AppColors.textSecondary)),
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
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifTemp = v),
                ),
                SwitchListTile(
                  title: const Text('Alertas de humedad ambiental'),
                  value: _notifHumedad,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifHumedad = v),
                ),
                SwitchListTile(
                  title: const Text('Alertas de humedad del suelo'),
                  value: _notifSuelo,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifSuelo = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: AppColors.critico),
            label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.critico)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.critico),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
