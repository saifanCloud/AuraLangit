// lib/main.dart
//
// Entry point aplikasi AuraLangit.
// Menginisialisasi localization (intl), mengatur orientasi,
// dan menerapkan Dynamic Theming (siang/malam) via ValueNotifier.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'splash_screen.dart';
import 'theme_notifier.dart';

Future<void> main() async {
  // Pastikan Flutter engine sudah siap sebelum memanggil platform API
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi data lokal Bahasa Inggris (en_US) untuk intl (hari, bulan, dll.)
  await initializeDateFormatting('en_US', null);

  // Paksa orientasi portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AuraLangitApp());
}

class AuraLangitApp extends StatelessWidget {
  const AuraLangitApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── ValueListenableBuilder: rebuild MaterialApp saat tema berubah ──
    return ValueListenableBuilder<bool>(
      valueListenable: isNightNotifier,
      builder: (context, isNight, _) {
        // Update status bar & navigation bar sesuai brightness tema
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isNight ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isNight ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          // ── Identitas Aplikasi ──────────────────────────────────
          title: 'AuraLangit',
          debugShowCheckedModeBanner: false,

          // ── Tema Dinamis ─────────────────────────────────────────
          // Flutter secara otomatis mengatur warna teks (onSurface)
          // berdasarkan brightness: putih untuk dark, hitam untuk light.
          theme: isNight ? _buildDarkTheme() : _buildLightTheme(),

          // Animasi transisi antar tema
          themeAnimationDuration: const Duration(milliseconds: 500),
          themeAnimationCurve: Curves.easeInOut,

          // ── Halaman Awal: SplashScreen ──────────────────────────
          home: const SplashScreen(),
        );
      },
    );
  }

  // ── Tema Gelap (Malam) ──────────────────────────────────────
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A1F5E),
        brightness: Brightness.dark,
      ),
      // Font default Material
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.transparent,

      // Hapus ripple pada InkWell agar tidak mengganggu animasi custom
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  // ── Tema Terang (Siang) ─────────────────────────────────────
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Colors.transparent,

      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
