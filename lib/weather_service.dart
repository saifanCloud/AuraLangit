// lib/weather_service.dart
//
// Service untuk mengambil data cuaca dari OpenWeatherMap API.
// Menyediakan MOCK DATA sebagai fallback jika API Key belum diisi,
// sehingga UI tetap dapat menampilkan data cuaca simulasi.

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// ============================================================
// DATA MODELS
// ============================================================

/// Model untuk data cuaca saat ini.
class CurrentWeather {
  final String cityName;
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final String weatherMain;
  final String weatherDescription;
  final String weatherIcon;
  final int humidity;
  final double windSpeed;
  final int visibility;
  final double lat;
  final double lon;
  final int timezone;

  const CurrentWeather({
    required this.cityName,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.humidity,
    required this.windSpeed,
    required this.visibility,
    required this.lat,
    required this.lon,
    required this.timezone,
  });

  /// Factory dari JSON OpenWeatherMap API.
  factory CurrentWeather.fromJson(Map<String, dynamic> json, String cityName) {
    return CurrentWeather(
      cityName: cityName.isNotEmpty
          ? cityName
          : (json['name'] ?? 'Unknown City'),
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      tempMin: (json['main']['temp_min'] as num).toDouble(),
      tempMax: (json['main']['temp_max'] as num).toDouble(),
      weatherMain: json['weather'][0]['main'] ?? 'Clear',
      weatherDescription: json['weather'][0]['description'] ?? 'clear sky',
      weatherIcon: json['weather'][0]['icon'] ?? '01d',
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      visibility: json['visibility'] as int? ?? 10000,
      lat: (json['coord']['lat'] as num).toDouble(),
      lon: (json['coord']['lon'] as num).toDouble(),
      timezone: json['timezone'] as int? ?? 25200,
    );
  }

  // ── Helper: Deteksi Siang/Malam dari Kode Ikon ──────────────
  // OpenWeatherMap icon codes selalu berakhiran 'd' (day) atau 'n' (night).
  // Contoh: '01d' = cerah siang, '01n' = cerah malam.

  /// Apakah data cuaca ini pada waktu siang (ikon berakhiran 'd').
  bool get isDayTime => weatherIcon.endsWith('d');

  /// Apakah data cuaca ini pada waktu malam (ikon berakhiran 'n').
  bool get isNightTime => weatherIcon.endsWith('n');
}

/// Model untuk satu hari prediksi cuaca.
class ForecastDay {
  final DateTime date;
  final String weatherMain;
  final String weatherDescription;
  final String weatherIcon;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final double windSpeed;

  const ForecastDay({
    required this.date,
    required this.weatherMain,
    required this.weatherDescription,
    required this.weatherIcon,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
  });
}

// ============================================================
// MOCK DATA (Digunakan jika API Key belum diisi)
// ============================================================

/// Mock data cuaca untuk kota default simulasi.
const String _kMockCity = 'Jakarta';
const double _kMockLat = -6.2088;
const double _kMockLon = 106.8456;

CurrentWeather _buildMockCurrentWeather({String cityName = _kMockCity}) {
  return CurrentWeather(
    cityName: cityName,
    temperature: 29.5,
    feelsLike: 33.2,
    tempMin: 25.0,
    tempMax: 33.0,
    weatherMain: 'Clouds',
    weatherDescription: 'scattered clouds',
    weatherIcon: '03d',
    humidity: 78,
    windSpeed: 14.4,
    visibility: 10000,
    lat: _kMockLat,
    lon: _kMockLon,
    timezone: 25200,
  );
}

List<ForecastDay> _buildMockForecast() {
  final rng = Random();
  final conditions = [
    ('Clear', 'clear sky', '01d'),
    ('Clouds', 'few clouds', '02d'),
    ('Rain', 'moderate rain', '10d'),
    ('Drizzle', 'light rain', '09d'),
    ('Clouds', 'overcast clouds', '04d'),
    ('Clear', 'sunny', '01d'),
    ('Thunderstorm', 'thunderstorm', '11d'),
  ];

  return List.generate(7, (i) {
    final cond = conditions[i % conditions.length];
    return ForecastDay(
      date: DateTime.now().add(Duration(days: i + 1)),
      weatherMain: cond.$1,
      weatherDescription: cond.$2,
      weatherIcon: cond.$3,
      tempMin: (22 + rng.nextDouble() * 4).roundToDouble(),
      tempMax: (28 + rng.nextDouble() * 6).roundToDouble(),
      humidity: 60 + rng.nextInt(30),
      windSpeed: (5 + rng.nextDouble() * 15).roundToDouble(),
    );
  });
}

// ============================================================
// WEATHER SERVICE
// ============================================================

class WeatherService {
  // ★ GANTI DENGAN API KEY ANDA DARI https://openweathermap.org/api
  // Jika dikosongkan, aplikasi akan menggunakan MOCK DATA secara otomatis.
  static const String _apiKey = 'db28dbd0c06f111415709eb02afac4d5';

  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Mengecek apakah API Key sudah diisi dan bukan placeholder bawaan.
  bool get _hasValidApiKey =>
      _apiKey.isNotEmpty &&
      _apiKey != 'YOUR_API_KEY_HERE' &&
      _apiKey.length > 10;

  // ----------------------------------------------------------
  // LOKASI
  // ----------------------------------------------------------

  /// Meminta izin dan mendapatkan posisi GPS saat ini.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak aktif. Aktifkan GPS Anda.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Aktifkan di pengaturan aplikasi.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Mengubah koordinat GPS menjadi nama kota menggunakan geocoding.
  Future<String> getCityNameFromCoordinates(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return place.locality?.isNotEmpty == true
            ? place.locality!
            : place.subAdministrativeArea ??
                  place.administrativeArea ??
                  'Unknown';
      }
    } catch (_) {}
    return 'Unknown Location';
  }

  // ----------------------------------------------------------
  // CUACA SAAT INI
  // ----------------------------------------------------------

  /// Mengambil cuaca berdasarkan nama kota.
  /// Otomatis menggunakan mock data jika API Key belum diisi.
  Future<CurrentWeather> fetchWeatherByCity(String city) async {
    if (!_hasValidApiKey) {
      // Simulasi delay network
      await Future.delayed(const Duration(milliseconds: 800));
      return _buildMockCurrentWeather(cityName: city);
    }

    final uri = Uri.parse(
      '$_baseUrl/weather?q=${Uri.encodeComponent(city)}'
      '&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CurrentWeather.fromJson(json, city);
    } else if (response.statusCode == 404) {
      throw Exception('Kota "$city" tidak ditemukan.');
    } else if (response.statusCode == 401) {
      throw Exception('API Key tidak valid. Gunakan API Key yang benar.');
    } else {
      throw Exception(
        'Gagal mengambil data cuaca (kode: ${response.statusCode}).',
      );
    }
  }

  /// Mengambil cuaca berdasarkan koordinat GPS.
  /// Otomatis menggunakan mock data jika API Key belum diisi.
  Future<CurrentWeather> fetchWeatherByCoordinates(
    double lat,
    double lon,
  ) async {
    if (!_hasValidApiKey) {
      await Future.delayed(const Duration(milliseconds: 800));
      final cityName = await getCityNameFromCoordinates(
        lat,
        lon,
      ).catchError((_) => _kMockCity);
      return _buildMockCurrentWeather(cityName: cityName);
    }

    final uri = Uri.parse(
      '$_baseUrl/weather?lat=$lat&lon=$lon'
      '&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Dapatkan nama kota yang lebih akurat dari geocoding
      final cityName = await getCityNameFromCoordinates(
        lat,
        lon,
      ).catchError((_) => json['name'] as String? ?? 'Unknown');
      return CurrentWeather.fromJson(json, cityName);
    } else {
      throw Exception('Gagal mengambil data cuaca berdasarkan lokasi.');
    }
  }

  // ----------------------------------------------------------
  // PRAKIRAAN 7 HARI
  // ----------------------------------------------------------

  /// Mengambil prakiraan 7 hari ke depan berdasarkan nama kota.
  /// Menggunakan endpoint /forecast (5-hari / 3-jam) lalu dikelompokkan per hari.
  Future<List<ForecastDay>> fetchForecastByCity(String city) async {
    if (!_hasValidApiKey) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _buildMockForecast();
    }

    final uri = Uri.parse(
      '$_baseUrl/forecast?q=${Uri.encodeComponent(city)}'
      '&appid=$_apiKey&units=metric&lang=id&cnt=40',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseForecast(json);
    } else {
      // Fallback ke mock jika terjadi error
      return _buildMockForecast();
    }
  }

  /// Mengambil prakiraan 7 hari ke depan berdasarkan koordinat GPS.
  Future<List<ForecastDay>> fetchForecastByCoordinates(
    double lat,
    double lon,
  ) async {
    if (!_hasValidApiKey) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _buildMockForecast();
    }

    final uri = Uri.parse(
      '$_baseUrl/forecast?lat=$lat&lon=$lon'
      '&appid=$_apiKey&units=metric&lang=id&cnt=40',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseForecast(json);
    } else {
      return _buildMockForecast();
    }
  }

  /// Mem-parse respons JSON /forecast menjadi list [ForecastDay] per hari.
  List<ForecastDay> _parseForecast(Map<String, dynamic> json) {
    final list = json['list'] as List<dynamic>;

    // Kelompokkan data per tanggal (format: yyyy-MM-dd)
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in list) {
      final dtTxt = item['dt_txt'] as String;
      final dateKey = dtTxt.split(' ').first;
      grouped.putIfAbsent(dateKey, () => []).add(item as Map<String, dynamic>);
    }

    // Ambil data representatif per hari (siang hari / tengah hari)
    final today = DateTime.now();
    final List<ForecastDay> days = [];

    for (final entry in grouped.entries) {
      final date = DateTime.parse(entry.key);
      // Lewati hari ini
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        continue;
      }

      final items = entry.value;

      // Cari data paling siang (12:00 atau yang terdekat)
      Map<String, dynamic> representative = items.first;
      for (final item in items) {
        if ((item['dt_txt'] as String).contains('12:00:00')) {
          representative = item;
          break;
        }
      }

      final tempMin = items
          .map((e) => (e['main']['temp_min'] as num).toDouble())
          .reduce(min);
      final tempMax = items
          .map((e) => (e['main']['temp_max'] as num).toDouble())
          .reduce(max);
      final humidity = (representative['main']['humidity'] as int);
      final windSpeed = (representative['wind']['speed'] as num).toDouble();

      days.add(
        ForecastDay(
          date: date,
          weatherMain: representative['weather'][0]['main'] as String,
          weatherDescription:
              representative['weather'][0]['description'] as String,
          weatherIcon: representative['weather'][0]['icon'] as String,
          tempMin: tempMin,
          tempMax: tempMax,
          humidity: humidity,
          windSpeed: windSpeed,
        ),
      );

      if (days.length >= 7) break;
    }

    // Jika data kurang dari 7 hari, tambahkan mock untuk sisa hari
    if (days.length < 7) {
      final mock = _buildMockForecast();
      days.addAll(mock.take(7 - days.length));
    }

    return days;
  }

  // ----------------------------------------------------------
  // HELPER: URL IKON CUACA
  // ----------------------------------------------------------

  /// Mendapatkan URL gambar ikon cuaca dari OpenWeatherMap.
  static String getIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  /// Mendapatkan emoji cuaca berdasarkan weatherMain.
  static String getWeatherEmoji(String weatherMain) {
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  /// Mendapatkan IconData (MaterialIcon) berdasarkan weatherMain.
  static String getWeatherIconName(String weatherMain) {
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return 'wb_sunny';
      case 'clouds':
        return 'cloud';
      case 'rain':
        return 'umbrella';
      case 'drizzle':
        return 'grain';
      case 'thunderstorm':
        return 'thunderstorm';
      case 'snow':
        return 'ac_unit';
      default:
        return 'wb_cloudy';
    }
  }
}
