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

/// Model untuk rekomendasi / sugesti kota.
class CitySuggestion {
  final String name;
  final String? state;
  final String country;
  final double? lat;
  final double? lon;

  const CitySuggestion({
    required this.name,
    this.state,
    required this.country,
    this.lat,
    this.lon,
  });

  /// Mengembalikan nama tampilan seperti "Jakarta (DKI Jakarta, ID)" atau "Tokyo (JP)".
  String get displayName {
    final statePart = (state != null && state!.isNotEmpty) ? '$state, ' : '';
    final countryPart = country.isNotEmpty ? country : '';
    final info = '$statePart$countryPart';
    return info.isNotEmpty ? '$name ($info)' : name;
  }

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      name: json['name'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// List preset kota, kabupaten, dan kecamatan populer Indonesia & Dunia untuk pencarian offline / fallback.
const List<CitySuggestion> _popularCities = [
  // ── Indonesia (Kota, Kabupaten, & Kecamatan Populer) ──
  CitySuggestion(name: 'Jakarta', state: 'DKI Jakarta', country: 'ID'),
  CitySuggestion(name: 'Surabaya', state: 'Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Bandung', state: 'Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Medan', state: 'Sumatera Utara', country: 'ID'),
  CitySuggestion(name: 'Semarang', state: 'Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Makassar', state: 'Sulawesi Selatan', country: 'ID'),
  CitySuggestion(name: 'Palembang', state: 'Sumatera Selatan', country: 'ID'),
  CitySuggestion(name: 'Tangerang', state: 'Banten', country: 'ID'),
  CitySuggestion(name: 'Tangerang Selatan', state: 'Banten', country: 'ID'),
  CitySuggestion(name: 'Depok', state: 'Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Bekasi', state: 'Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Bogor', state: 'Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Batam', state: 'Kepulauan Riau', country: 'ID'),
  CitySuggestion(name: 'Pekanbaru', state: 'Riau', country: 'ID'),
  CitySuggestion(name: 'Bandar Lampung', state: 'Lampung', country: 'ID'),
  CitySuggestion(name: 'Malang', state: 'Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Padang', state: 'Sumatera Barat', country: 'ID'),
  CitySuggestion(name: 'Denpasar', state: 'Bali', country: 'ID'),
  CitySuggestion(name: 'Samarinda', state: 'Kalimantan Timur', country: 'ID'),
  CitySuggestion(name: 'Tasikmalaya', state: 'Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Serang', state: 'Banten', country: 'ID'),
  CitySuggestion(name: 'Banjarmasin', state: 'Kalimantan Selatan', country: 'ID'),
  CitySuggestion(name: 'Pontianak', state: 'Kalimantan Barat', country: 'ID'),
  CitySuggestion(name: 'Cimahi', state: 'Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Balikpapan', state: 'Kalimantan Timur', country: 'ID'),
  CitySuggestion(name: 'Jambi', state: 'Jambi', country: 'ID'),
  CitySuggestion(name: 'Surakarta', state: 'Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Yogyakarta', state: 'DI Yogyakarta', country: 'ID'),
  CitySuggestion(name: 'Sleman', state: 'Kab. Sleman, DI Yogyakarta', country: 'ID'),
  CitySuggestion(name: 'Bantul', state: 'Kab. Bantul, DI Yogyakarta', country: 'ID'),
  CitySuggestion(name: 'Gunungkidul', state: 'Kab. Gunungkidul, DI Yogyakarta', country: 'ID'),
  CitySuggestion(name: 'Kulon Progo', state: 'Kab. Kulon Progo, DI Yogyakarta', country: 'ID'),
  CitySuggestion(name: 'Purwokerto', state: 'Kab. Banyumas, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Cilacap', state: 'Kab. Cilacap, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Purbalingga', state: 'Kab. Purbalingga, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Banjarnegara', state: 'Kab. Banjarnegara, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Kebumen', state: 'Kab. Kebumen, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Purworejo', state: 'Kab. Purworejo, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Wonosobo', state: 'Kab. Wonosobo, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Temanggung', state: 'Kab. Temanggung, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Klaten', state: 'Kab. Klaten, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Boyolali', state: 'Kab. Boyolali, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Sragen', state: 'Kab. Sragen, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Karanganyar', state: 'Kab. Karanganyar, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Sukoharjo', state: 'Kab. Sukoharjo, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Wonogiri', state: 'Kab. Wonogiri, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Kudus', state: 'Kab. Kudus, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Jepara', state: 'Kab. Jepara, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Pati', state: 'Kab. Pati, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Rembang', state: 'Kab. Rembang, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Blora', state: 'Kab. Blora, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Demak', state: 'Kab. Demak, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Kendal', state: 'Kab. Kendal, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Batang', state: 'Kab. Batang, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Pemalang', state: 'Kab. Pemalang, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Brebes', state: 'Kab. Brebes, Jawa Tengah', country: 'ID'),
  CitySuggestion(name: 'Cibinong', state: 'Kab. Bogor, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Cikarang', state: 'Kab. Bekasi, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Subang', state: 'Kab. Subang, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Sumedang', state: 'Kab. Sumedang, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Garut', state: 'Kab. Garut, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Ciamis', state: 'Kab. Ciamis, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Kuningan', state: 'Kab. Kuningan, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Majalengka', state: 'Kab. Majalengka, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Indramayu', state: 'Kab. Indramayu, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Karawang', state: 'Kab. Karawang, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Purwakarta', state: 'Kab. Purwakarta, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Cianjur', state: 'Kab. Cianjur, Jawa Barat', country: 'ID'),
  CitySuggestion(name: 'Sidoarjo', state: 'Kab. Sidoarjo, Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Gresik', state: 'Kab. Gresik, Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Mojokerto', state: 'Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Jombang', state: 'Kab. Jombang, Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Batu', state: 'Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Pasuruan', state: 'Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Probolinggo', state: 'Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Lumajang', state: 'Kab. Lumajang, Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Jember', state: 'Kab. Jember, Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Banyuwangi', state: 'Kab. Banyuwangi, Jawa Timur', country: 'ID'),
  CitySuggestion(name: 'Ubud', state: 'Gianyar, Bali', country: 'ID'),
  CitySuggestion(name: 'Kuta', state: 'Badung, Bali', country: 'ID'),
  CitySuggestion(name: 'Canggu', state: 'Badung, Bali', country: 'ID'),
  CitySuggestion(name: 'Sanur', state: 'Denpasar, Bali', country: 'ID'),
  CitySuggestion(name: 'Jimbaran', state: 'Badung, Bali', country: 'ID'),
  CitySuggestion(name: 'Manado', state: 'Sulawesi Utara', country: 'ID'),
  CitySuggestion(name: 'Mataram', state: 'Nusa Tenggara Barat', country: 'ID'),
  CitySuggestion(name: 'Kupang', state: 'Nusa Tenggara Timur', country: 'ID'),
  CitySuggestion(name: 'Jayapura', state: 'Papua', country: 'ID'),
  CitySuggestion(name: 'Ambon', state: 'Maluku', country: 'ID'),
  CitySuggestion(name: 'Banda Aceh', state: 'Aceh', country: 'ID'),
  CitySuggestion(name: 'Bengkulu', state: 'Bengkulu', country: 'ID'),

  // ── Internasional ──
  CitySuggestion(name: 'Tokyo', country: 'JP'),
  CitySuggestion(name: 'Singapore', country: 'SG'),
  CitySuggestion(name: 'Kuala Lumpur', country: 'MY'),
  CitySuggestion(name: 'Bangkok', country: 'TH'),
  CitySuggestion(name: 'London', country: 'GB'),
  CitySuggestion(name: 'New York', country: 'US'),
  CitySuggestion(name: 'Paris', country: 'FR'),
  CitySuggestion(name: 'Sydney', country: 'AU'),
  CitySuggestion(name: 'Seoul', country: 'KR'),
  CitySuggestion(name: 'Dubai', country: 'AE'),
  CitySuggestion(name: 'Berlin', country: 'DE'),
  CitySuggestion(name: 'Rome', country: 'IT'),
  CitySuggestion(name: 'Istanbul', country: 'TR'),
  CitySuggestion(name: 'Amsterdam', country: 'NL'),
];

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
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable in app settings.',
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
      '&appid=$_apiKey&units=metric&lang=en',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CurrentWeather.fromJson(json, city);
    } else if (response.statusCode == 404) {
      throw Exception('City "$city" not found.');
    } else if (response.statusCode == 401) {
      throw Exception('Invalid API Key. Please enter a valid API Key.');
    } else {
      throw Exception(
        'Failed to fetch weather data (code: ${response.statusCode}).',
      );
    }
  }

  /// Mengambil cuaca berdasarkan koordinat GPS atau hasil Geocoding API.
  /// Otomatis menggunakan mock data jika API Key belum diisi.
  Future<CurrentWeather> fetchWeatherByCoordinates(
    double lat,
    double lon, {
    String? fallbackName,
  }) async {
    if (!_hasValidApiKey) {
      await Future.delayed(const Duration(milliseconds: 800));
      final cityName = (fallbackName != null && fallbackName.isNotEmpty)
          ? fallbackName
          : await getCityNameFromCoordinates(
              lat,
              lon,
            ).catchError((_) => _kMockCity);
      return _buildMockCurrentWeather(cityName: cityName);
    }

    final uri = Uri.parse(
      '$_baseUrl/weather?lat=$lat&lon=$lon'
      '&appid=$_apiKey&units=metric&lang=en',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final apiName = json['name'] as String?;
      final cityName = (fallbackName != null && fallbackName.isNotEmpty)
          ? fallbackName
          : ((apiName != null && apiName.isNotEmpty)
              ? apiName
              : await getCityNameFromCoordinates(lat, lon)
                  .catchError((_) => 'Unknown'));
      return CurrentWeather.fromJson(json, cityName);
    } else {
      throw Exception('Failed to fetch weather data for selected location.');
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
      '&appid=$_apiKey&units=metric&lang=en&cnt=40',
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
      '&appid=$_apiKey&units=metric&lang=en&cnt=40',
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

  // ----------------------------------------------------------
  // SUGESTI LOKASI DYNAMIS (GEOCODING API)
  // ----------------------------------------------------------

  /// Mengambil rekomendasi/sugesti lokasi secara otomatis menggunakan:
  /// 1. OpenWeatherMap Direct Geocoding API (`/geo/1.0/direct`)
  /// 2. Photon OpenStreetMap Geocoding API (`photon.komoot.io`) - 100% Gratis & tanpa API Key (Mencakup Kecamatan, Kabupaten, Desa, Kota seluruh dunia)
  /// 3. Preset lokal sebagai fallback offline
  Future<List<CitySuggestion>> fetchCitySuggestions(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    List<CitySuggestion> results = [];

    // 1. Coba OpenWeatherMap Direct Geocoding API jika API Key valid
    if (_hasValidApiKey) {
      try {
        final uri = Uri.parse(
          'https://api.openweathermap.org/geo/1.0/direct?q=${Uri.encodeComponent(q)}'
          '&limit=10&appid=$_apiKey',
        );
        final response =
            await http.get(uri).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final jsonList = jsonDecode(response.body) as List<dynamic>;
          results = jsonList
              .map((item) =>
                  CitySuggestion.fromJson(item as Map<String, dynamic>))
              .where((s) => s.name.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    // 2. Jika hasil masih kurang dari 5, gabungkan dengan Photon (OpenStreetMap Geocoding API - Gratis & Seluruh Dunia)
    if (results.length < 5) {
      try {
        final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&limit=10',
        );
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'AuraLangitWeatherApp/1.0'},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? [];
          for (final feature in features) {
            final props = feature['properties'] as Map<String, dynamic>? ?? {};
            final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geometry['coordinates'] as List<dynamic>? ?? [];

            final name = props['name'] as String? ??
                props['city'] as String? ??
                props['district'] as String? ??
                '';
            final state = props['state'] as String? ??
                props['county'] as String? ??
                props['district'] as String?;
            final country = props['countrycode'] as String? ??
                props['country'] as String? ??
                'ID';

            if (name.isNotEmpty) {
              results.add(
                CitySuggestion(
                  name: name,
                  state: state,
                  country: country.toUpperCase(),
                  lat: coords.length >= 2
                      ? (coords[1] as num).toDouble()
                      : null,
                  lon: coords.length >= 2
                      ? (coords[0] as num).toDouble()
                      : null,
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback ke preset lokal jika offline
    if (results.isEmpty) {
      final localMatches = _popularCities.where((c) {
        final nameMatch = c.name.toLowerCase().contains(q);
        final stateMatch = c.state?.toLowerCase().contains(q) ?? false;
        return nameMatch || stateMatch;
      }).toList();
      results.addAll(localMatches);
    }

    // Deduplikasi hasil
    final Map<String, CitySuggestion> uniqueMap = {};
    for (final s in results) {
      final key =
          '${s.name.toLowerCase()}_${s.state?.toLowerCase() ?? ''}_${s.country.toLowerCase()}';
      uniqueMap[key] = s;
    }

    return uniqueMap.values.take(10).toList();
  }
}

