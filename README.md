# ⛅ AuraLangit - Modern Atmospheric Weather App

**AuraLangit** is a state-of-the-art, modern weather application built with **Flutter** featuring dynamic atmospheric background imagery, real-time multi-engine geocoding location lookup, high-contrast **Glassmorphism UI**, and 100% English localization.

---

## 🌟 Overview & Key Features

- **🌤️ Dynamic Atmospheric Sky Backgrounds**:
  Real-time adaptive sky imagery layered with atmospheric dark slate gradient overlays according to live weather status (Clear, Clouds, Rain, Thunderstorm, Snow, Night).
- **🌍 Automated Multi-Engine Geocoding Search**:
  Powered by **OpenWeather Direct Geocoding API** + **Photon OpenStreetMap Geocoding API (`photon.komoot.io`)** to support real-time dynamic searches for cities, regencies, sub-districts (*kecamatan*), and villages globally.
- **🎯 Exact Coordinate Weather Resolution (`lat/lon`)**:
  Resolves weather data via exact GPS coordinates returned by geocoding services, guaranteeing 100% location accuracy for any sub-district or village.
- **✨ Ultra-Sharp High-Contrast Glassmorphism UI**:
  Frosted dark glass card tints (`#334155` Slate Cloud Grey) paired with subtle text drop shadows to deliver 100% crisp, readable typography across all background conditions.
- **📊 Responsive Bento Details Grid**:
  Solid 44x44px accent icon container on the left, with label text at top-right and bold numerical metrics centered below—preventing any text truncation (`...`).
- **📍 Smart Multi-line Location Name Formatting**:
  Cleans redundant administrative prefixes (*Special Region of*, *Kab.*, *DI*) and supports 2-line responsive text wrapping for long location names.
- **🕒 Dual Live Clock & Local Time Sync**:
  Displays device GPS time alongside destination city target time synced via OpenWeather UTC timezone offsets.
- **📅 7-Day Forecast Visual Bar**:
  Daily temperature range bars featuring smooth linear color gradients (blue to orange) to compare minimum and maximum temperatures at a glance.
- **🌐 100% English Localization**:
  Fully localized using `en_US` date formatting and OpenWeather `lang=en` API parameters.

---

## 🛠️ Tech Stack & Dependencies

| Library / Package | Version | Purpose |
| :--- | :--- | :--- |
| [`flutter`](https://flutter.dev) | SDK `^3.12.0` | Cross-platform UI Framework |
| [`http`](https://pub.dev/packages/http) | `^1.2.0` | Asynchronous HTTP requests to OpenWeatherMap & Photon APIs |
| [`geolocator`](https://pub.dev/packages/geolocator) | `^13.0.2` | Real-time device GPS positioning & permissions |
| [`geocoding`](https://pub.dev/packages/geocoding) | `^3.0.0` | Native reverse geocoding from GPS coordinates to location names |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | `^2.3.3` | Persistent local storage for recent searched city |
| [`intl`](https://pub.dev/packages/intl) | `^0.20.1` | Date and time formatting in `en_US` locale |

---

## 📁 Project Architecture (`lib/`)

```text
lib/
│
├── main.dart             # Application entry point, system overlay configuration, intl initialization, and MaterialApp theme builder.
├── splash_screen.dart    # Intro splash screen with animated scale/fade transitions and local storage pre-loading.
├── home_screen.dart      # Main dashboard containing Search Bar, Live Clocks, Glassmorphic Hero Weather Card, Bento Grid Details, and 7-Day Forecast.
├── theme_notifier.dart   # ValueNotifier state management for instant day/night dynamic theme switching.
└── weather_service.dart  # Data layer for OpenWeatherMap API, Photon Geocoding API, GPS permission handling, and Mock Data Fallback engine.
```

---

## 🚀 How to Run Locally

### Prerequisites
- Flutter SDK installed (`>= 3.12.0`).
- Android Emulator / Physical Device connected with USB Debugging enabled.

### 1. Clone Repository & Install Dependencies
```bash
git clone <repository-url>
cd auralangit
flutter pub get
```

### 2. Configure API Key (Optional)
The application includes an automatic **Mock Data Fallback** engine if no API Key is provided. To connect to live OpenWeatherMap servers:
1. Obtain an API Key from [OpenWeatherMap](https://openweathermap.org/api).
2. Open `lib/weather_service.dart`.
3. Set your API Key in line 315:
   ```dart
   static const String _apiKey = 'YOUR_API_KEY_HERE';
   ```

### 3. Run Development Build
```bash
flutter run
```

---

## 📦 Building Android APK Release

To generate the production Release APK for Android devices:

### Universal Release APK
```bash
flutter build apk --release
```
*Output File:* `build/app/outputs/flutter-apk/app-release.apk`

### Split ABI APKs (Smaller file size per CPU architecture)
```bash
flutter build apk --split-per-abi
```

---

## 📱 LinkedIn / Social Media Showcase

If you would like to share this project on LinkedIn or your developer portfolio, feel free to use the following post template:

```text
🚀 AuraLangit: Elevating Weather App Design with Flutter & Glassmorphic UI! ⛅

Excited to share AuraLangit, a modern weather application featuring dynamic atmospheric sky imagery, high-contrast Glassmorphic UI, and real-time multi-engine location geocoding!

Built using Flutter & Dart, the project focuses on delivering a seamless user experience with high-fidelity visuals. Key highlights include:

✨ Key Features:
1️⃣ Glassmorphic UI – Clean, semi-transparent frosted slate glass cards (#334155) with subtle text drop shadows for AAA contrast readability.
2️⃣ Automated Multi-Engine Geocoding – Integrated OpenWeather Direct Geo & Photon OpenStreetMap APIs (photon.komoot.io) for instant location search across sub-districts and cities worldwide.
3️⃣ Coordinates Weather Resolution – Fetches weather via exact lat/lon coordinates for 100% accuracy.
4️⃣ Live Dual Clocks – Displays local device GPS time alongside destination target time synced with UTC offsets.
5️⃣ Bento Details & 7-Day Forecast – Responsive 2x2 Bento grid metrics and 7-day temperature range visual gradient bars.

Technologies Used: Flutter, Dart, OpenWeatherMap API, Photon API, Geolocator, Shared Preferences, Intl.

Would love to hear your thoughts on the UI & architecture! 👇

#Flutter #Dart #MobileDevelopment #UIUX #Glassmorphism #AuraLangit #OpenSource #DeveloperShowcase
```

---

## 📄 License
This project is open-source and available under the MIT License.
