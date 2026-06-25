# ⛅ AuraLangit

Aplikasi cuaca premium dengan desain modern yang menyajikan informasi cuaca real-time dan prediktif. Dibangun menggunakan **Flutter** dengan sentuhan estetika **Glassmorphic UI**, transisi warna dinamis, penentuan tema adaptif otomatis (siang/malam), serta integrasi GPS dan penyimpanan lokal.

---

## ✨ Fitur Utama

- **Dynamic Theme & Background (Siang/Malam)**: 
  Latar belakang gradasi dan tema aplikasi berubah secara adaptif berdasarkan status cuaca (cerah, mendung, hujan, badai, bersalju) dan waktu siang/malam dari kota yang dicari.
- **Premium Glassmorphism UI**: 
  Tampilan kartu transparan dengan efek blur kaca halus, border semi-transparan, serta bayangan dinamis yang memberikan kesan elegan dan modern.
- **Real-time Clock & Date**: 
  Jam digital presisi detik berjalan beserta format tanggal lengkap menggunakan Bahasa Indonesia (`id_ID`) yang diperbarui setiap detik.
- **Pencarian Kota & Deteksi GPS**: 
  - Cari kondisi cuaca di kota mana saja di seluruh dunia melalui kolom pencarian.
  - Ketuk tombol lokasi untuk mencari cuaca terkini di lokasi GPS Anda berada menggunakan package `geolocator` dan `geocoding` untuk memetakan koordinat ke nama kota.
- **Detail Cuaca Komprehensif**: 
  Menampilkan informasi suhu aktual, suhu terasa (*feels like*), kelembapan, kecepatan angin (dikonversi ke km/jam), dan visibilitas.
- **Prakiraan Cuaca 7 Hari**: 
  Menyajikan rincian cuaca harian selama 7 hari ke depan lengkap dengan status, emoji cuaca, dan kisaran suhu minimum/maksimum.
- **Penyimpanan Kota Terakhir**: 
  Menggunakan `shared_preferences` untuk menyimpan kota terakhir yang sukses dicari secara otomatis, sehingga langsung dimuat kembali ketika aplikasi dibuka.
- **Mock Data Fallback**: 
  Jika API key belum diatur, aplikasi secara otomatis masuk ke mode simulasi (menggunakan Mock Data dinamis) agar seluruh UI dan animasi tetap dapat dieksplorasi secara instan tanpa hambatan.

---

## 🛠️ Teknologi & Library yang Digunakan

Aplikasi ini menggunakan beberapa paket Flutter berikut untuk mendukung fungsionalitasnya:

| Library | Kegunaan |
| :--- | :--- |
| [`http`](https://pub.dev/packages/http) | Melakukan HTTP request ke API OpenWeatherMap |
| [`geolocator`](https://pub.dev/packages/geolocator) | Mendapatkan koordinat GPS perangkat secara real-time |
| [`geocoding`](https://pub.dev/packages/geocoding) | Menerjemahkan koordinat GPS menjadi nama wilayah/kota (*Reverse Geocoding*) |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Menyimpan data lokasi terakhir secara lokal di perangkat |
| [`intl`](https://pub.dev/packages/intl) | Memformat tanggal dan waktu dalam format lokal Indonesia |

---

## 📁 Struktur Kode Utama (`lib/`)

Struktur direktori di bawah folder `lib` dirancang secara modular dan efisien:

```text
lib/
│
├── main.dart             # Titik masuk aplikasi, pengaturan status bar adaptif, inisialisasi local intl, dan konfigurasi tema MaterialApp.
├── splash_screen.dart    # Halaman intro dengan animasi fade & scale, partikel bintang dinamis, serta loading kota terakhir dari local storage.
├── home_screen.dart      # Layar utama yang menampung Search Bar, Jam real-time, kartu cuaca Glassmorphism, dan Prakiraan 7 Hari.
├── theme_notifier.dart   # State Management sederhana menggunakan ValueNotifier untuk memperbarui tema siang/malam secara instan global.
└── weather_service.dart  # Service API OpenWeatherMap, konfigurasi API Key, penanganan izin lokasi GPS, dan logika Mock Data Fallback.
```

---

## 🚀 Panduan Menjalankan Aplikasi

Ikuti langkah-langkah di bawah ini untuk menjalankan proyek ini di komputer lokal Anda:

### Prasyarat
- Pastikan Flutter SDK sudah terinstal dengan baik di sistem Anda (versi SDK minimal `^3.12.0`).
- Pastikan emulator Android/iOS aktif atau perangkat fisik sudah terhubung dengan USB Debugging diaktifkan.

### Langkah 1: Clone Repositori
```bash
git clone <repository-url>
cd auralangit
```

### Langkah 2: Mengambil Dependensi
Unduh semua library yang diperlukan oleh proyek dengan menjalankan perintah berikut di terminal:
```bash
flutter pub get
```

### Langkah 3: Konfigurasi API Key (Opsional)
Aplikasi ini menggunakan layanan API dari [OpenWeatherMap](https://openweathermap.org/).
1. Buat akun gratis dan dapatkan API Key Anda di portal OpenWeatherMap.
2. Buka file `lib/weather_service.dart`.
3. Temukan baris berikut dan masukkan API Key Anda:
   ```dart
   static const String _apiKey = 'YOUR_API_KEY_HERE';
   ```
   *Catatan: Jika Anda membiarkannya kosong atau menggunakan API key bawaan, aplikasi akan otomatis beralih ke mode **Simulasi (Mock Data)** sehingga Anda masih bisa mencoba aplikasinya.*

### Langkah 4: Jalankan Aplikasi
Jalankan aplikasi ke emulator atau perangkat fisik Anda:
```bash
flutter run
```

---

## 🎨 Detail Desain Premium

- **Glassmorphic Cards**: Dibuat menggunakan `Container` dengan gradasi warna putih semi-transparan, `BoxShadow` lembut, dan border tipis untuk memisahkan kartu dari latar belakang gradasi dinamis.
- **Custom Shader Mask**: Digunakan pada teks suhu utama di `home_screen.dart` untuk memberikan gradasi warna teks yang memikat (warna dasar putih ke warna aksen cuaca).
- **Theme Transitions**: Transisi perpindahan tema siang ke malam dirancang halus dengan durasi `500ms` menggunakan kurva `easeInOut` bawaan MaterialApp.
- **Partikel Bintang**: Di `splash_screen.dart`, terdapat partikel bintang dekoratif acak yang bersinar lembut di atas langit malam gradasi ungu-biru tua.

---

## 📱 LinkedIn Caption / Posting Share

If you want to share a preview/screenshot of this project on LinkedIn, you can use the following English template:

```text
🚀 AuraLangit: Elevating Weather App Design with Flutter & Glassmorphic UI! ⛅

Excited to share a sneak peek of my latest project: AuraLangit, a premium weather application featuring a sleek, modern aesthetic and interactive real-time forecasts. 

This app is built using Flutter, with a strong focus on high-fidelity design and a seamless user experience. Here is a breakdown of what went into it:

✨ Key Features & Implementation:
1️⃣ Glassmorphic UI – Created a clean, semi-transparent card layout with soft blur effects and subtle borders for a high-end, premium feel.
2️⃣ Dynamic Themes & Backgrounds – The UI adaptively changes gradients and themes based on the weather conditions (sunny, rainy, cloudy, stormy, snowy) and time of day (day/night) for the searched location.
3️⃣ Real-Time Clock & Date – Embedded a live running clock with local formatting to keep users contextually aware.
4️⃣ GPS Location Detection – Integrated geolocator and geocoding to automatically resolve local weather conditions instantly using the device's GPS coordinates.
5️⃣ 7-Day Interactive Forecast – Displays comprehensive weekly forecasts complete with custom weather icons and high/low temperature metrics.

Designing AuraLangit challenged me to push the boundaries of what is possible with Flutter's styling capabilities and state management to deliver an interface that is not only functional but visually captivating.

Would love to hear your feedback on the UI and features! Let me know your thoughts in the comments below. 👇

#Flutter #Dart #MobileDevelopment #UIUXDesign #Glassmorphism #AuraLangit #AppDevelopment #DeveloperShowcase
```

