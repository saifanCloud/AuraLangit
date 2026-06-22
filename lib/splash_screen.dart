// lib/splash_screen.dart
//
// Halaman Splash Screen:
// - Menampilkan nama aplikasi "WHAT-HER WEATHER" dan ikon cuaca di tengah.
// - Durasi: 3 detik dengan animasi fade & scale.
// - Di balik layar, membaca SharedPreferences untuk kota terakhir.
// - Mengarahkan ke HomeScreen dengan membawa nama kota yang tersimpan.

import 'package:flutter/material.dart';
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // ── Latar Belakang Gradasi Malam ──────────────────────
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E2A), // Biru sangat gelap
              Color(0xFF1A1F5E), // Biru tua
              Color(0xFF2D1B69), // Ungu tua
              Color(0xFF1A0A3A), // Ungu gelap
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Partikel Bintang Dekoratif ─────────────────────
            ..._buildStarParticles(),

            // ── Konten Utama ───────────────────────────────────
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Ikon / Emoji Cuaca ─────────────────────
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0x40FFFFFF), Color(0x10FFFFFF)],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('⛅', style: TextStyle(fontSize: 56)),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Nama Aplikasi ──────────────────────────
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFFFFFF),
                            Color(0xFFADD8E6),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'WHAT-HER',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 8,
                            height: 1.1,
                          ),
                        ),
                      ),

                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFADD8E6), Color(0xFF87CEEB)],
                        ).createShader(bounds),
                        child: const Text(
                          'WEATHER',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            letterSpacing: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Tagline ────────────────────────────────
                      Text(
                        'Your weather, beautifully presented',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // ── Loading Indicator ──────────────────────
                      SizedBox(
                        width: 40,
                        height: 2,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membuat partikel bintang dekoratif di latar belakang.
  List<Widget> _buildStarParticles() {
    const stars = [
      (0.08, 0.12, 2.0),
      (0.92, 0.08, 1.5),
      (0.55, 0.05, 1.0),
      (0.25, 0.20, 1.8),
      (0.78, 0.18, 1.2),
      (0.15, 0.35, 1.0),
      (0.88, 0.30, 2.5),
      (0.45, 0.15, 1.5),
      (0.65, 0.25, 1.0),
      (0.35, 0.08, 2.0),
      (0.05, 0.55, 1.5),
      (0.95, 0.60, 1.0),
      (0.70, 0.88, 1.8),
      (0.20, 0.78, 1.2),
      (0.50, 0.92, 2.0),
      (0.82, 0.75, 1.5),
      (0.10, 0.90, 1.0),
      (0.40, 0.70, 1.8),
    ];

    return stars.map((s) {
      return Positioned(
        left: MediaQuery.of(context).size.width * s.$1,
        top: MediaQuery.of(context).size.height * s.$2,
        child: Container(
          width: s.$3 * 2,
          height: s.$3 * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.7),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
