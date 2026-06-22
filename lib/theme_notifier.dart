// lib/theme_notifier.dart
//
// State management untuk Dynamic Theming (siang/malam).
// Menggunakan ValueNotifier agar efisien dan ringan tanpa dependency tambahan.
//
// Cara kerja:
// 1. isNightNotifier di-listen oleh MaterialApp via ValueListenableBuilder.
// 2. Setiap kali data cuaca di-fetch, nilai notifier diperbarui berdasarkan
//    kode ikon API (suffix 'd' = siang, 'n' = malam).
// 3. MaterialApp otomatis rebuild dengan ThemeData yang sesuai.

import 'package:flutter/foundation.dart';

/// ValueNotifier global untuk state tema siang/malam.
/// - `true`  → Malam (Dark Mode)
/// - `false` → Siang (Light Mode)
///
/// Nilai awal `true` agar splash screen selalu tampil dalam mode gelap.
final ValueNotifier<bool> isNightNotifier = ValueNotifier<bool>(true);

/// Mendeteksi apakah sedang malam dari kode ikon cuaca OpenWeatherMap.
///
/// Kode ikon selalu berakhiran 'd' (day) atau 'n' (night).
/// Contoh:
/// - `'01d'` → cerah siang → return `false`
/// - `'01n'` → cerah malam → return `true`
/// - `'10d'` → hujan siang → return `false`
/// - `'10n'` → hujan malam → return `true`
bool isNightFromIconCode(String iconCode) {
  return iconCode.endsWith('n');
}
