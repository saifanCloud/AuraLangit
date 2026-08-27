// lib/splash_screen.dart
//
// Halaman Splash Screen:
// - Menampilkan nama aplikasi "AURA LANGIT" dan ikon cuaca di tengah.
// - Durasi: 3 detik dengan animasi fade & scale.
// - Di balik layar, membaca SharedPreferences untuk kota terakhir.
// - Mengarahkan ke HomeScreen dengan membawa nama kota yang tersimpan.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animasi ──────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  // Nama kota yang akan diteruskan ke HomeScreen
  String? _lastCity;

  @override
  void initState() {
    super.initState();

    // Controller fade-in: 1.2 detik
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Controller scale: 1.0 detik dengan efek "bounce"
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Jalankan animasi dan inisialisasi data secara bersamaan
    _fadeController.forward();
    _scaleController.forward();
    _initializeAndNavigate();
  }

  /// Membaca SharedPreferences dan berpindah ke HomeScreen setelah 3 detik.
  Future<void> _initializeAndNavigate() async {
    // Jalankan keduanya secara paralel
    await Future.wait([
      _loadLastCity(),
      Future.delayed(const Duration(seconds: 3)),
    ]);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeScreen(initialCity: _lastCity),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  /// Membaca kota terakhir dari SharedPreferences.
  Future<void> _loadLastCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastCity = prefs.getString('last_city');
    } catch (_) {
      _lastCity = null;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          // ── Latar Belakang Putih Minimalis & Profesional ──────────────────────
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF8FAFC),
              ],
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Ikon / Emoji Cuaca Minimalis ─────────────────────
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('⛅', style: TextStyle(fontSize: 48)),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Nama Aplikasi Bersih ──────────────────────────
                    const Text(
                      'AURA',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'LANGIT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF64748B),
                        letterSpacing: 10,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Tagline ────────────────────────────────
                    const Text(
                      'Precise & Elegant Weather App',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ── Loading Indicator Minimalis ──────────────────────
                    SizedBox(
                      width: 60,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          backgroundColor: Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB),
                          ),
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
    );
  }
}
