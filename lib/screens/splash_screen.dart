import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/colors.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final loggedIn = FirebaseService.instance.isLoggedIn;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => loggedIn ? const DashboardScreen() : const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.eco, color: AppColors.primary, size: 60),
                ),
                const SizedBox(height: 24),
                const Text(
                  'GREEN TECH',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitoreo inteligente de cultivos',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
