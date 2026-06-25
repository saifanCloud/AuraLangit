// lib/home_screen.dart
//
// Halaman Utama What-Her Weather:
// - Search Bar & GPS Button berdampingan di bagian atas.
// - Jam & Tanggal real-time berdetik setiap detik menggunakan Timer.
// - Info cuaca saat ini (Nama Kota, Suhu Celsius, Status Cuaca).
// - Dynamic Background berubah berdasarkan status cuaca.
// - Dynamic Theming (siang/malam) otomatis dari data API cuaca.
// - Weather Details Card (Kelembapan, Angin, Rentang Suhu).
// - Weekly Forecast Section (7 hari ke depan).
// - Menyimpan kota ke SharedPreferences setiap kali pencarian berhasil.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'weather_service.dart';
import 'theme_notifier.dart';

// ============================================================
// KONSTANTA WARNA TEMA CUACA
// ============================================================

/// Mengembalikan gradasi warna latar berdasarkan cuaca dan waktu.
/// Siang → gradasi terang, Malam → gradasi gelap.
List<Color> _getWeatherGradient(String weatherMain, bool isNight) {
  if (isNight) {
    return const [
      Color(0xFF0A0E2A),
      Color(0xFF1A1F5E),
      Color(0xFF2D1B69),
    ];
  }
  // ── Gradasi Siang (lebih terang agar kontras dengan teks gelap) ──
  switch (weatherMain.toLowerCase()) {
    case 'clear':
      return const [
        Color(0xFF4FC3F7), // Biru langit cerah
        Color(0xFF81D4FA),
        Color(0xFFB3E5FC),
        Color(0xFFFFE082), // Kuning hangat
      ];
    case 'rain':
    case 'drizzle':
      return const [
        Color(0xFF78909C), // Abu-biru medium
        Color(0xFF90A4AE),
        Color(0xFFB0BEC5),
        Color(0xFFCFD8DC), // Abu-biru terang
      ];
    case 'thunderstorm':
      return const [
        Color(0xFF8D6E63), // Coklat abu
        Color(0xFF90A4AE),
        Color(0xFFB0BEC5),
        Color(0xFFBCAAA4), // Coklat muda
      ];
    case 'snow':
      return const [
        Color(0xFFB3E5FC), // Biru sangat muda
        Color(0xFFE1F5FE),
        Color(0xFFFFFFFF), // Putih
        Color(0xFFE0F7FA),
      ];
    case 'clouds':
    default:
      return const [
        Color(0xFF90A4AE), // Abu-biru medium
        Color(0xFFB0BEC5),
        Color(0xFFCFD8DC),
        Color(0xFFECEFF1), // Abu sangat terang
      ];
  }
}

Color _getWeatherAccentColor(String weatherMain) {
  switch (weatherMain.toLowerCase()) {
    case 'clear':
      return const Color(0xFFFFD54F);
    case 'rain':
    case 'drizzle':
      return const Color(0xFF4FC3F7);
    case 'thunderstorm':
      return const Color(0xFFCE93D8);
    case 'snow':
      return const Color(0xFFE1F5FE);
    default:
      return const Color(0xFFB0BEC5);
  }
}

// ============================================================
// HOME SCREEN WIDGET
// ============================================================

class HomeScreen extends StatefulWidget {
  /// Kota awal yang dibawa dari SplashScreen (bisa null).
  final String? initialCity;

  const HomeScreen({super.key, this.initialCity});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // ── Service ───────────────────────────────────────────────
  final WeatherService _weatherService = WeatherService();

  // ── State Data Cuaca ──────────────────────────────────────
  CurrentWeather? _currentWeather;
  List<ForecastDay> _forecast = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── State UI ──────────────────────────────────────────────
  String _gpsCityName = 'Mencari Lokasi...';
  DateTime _gpsTime = DateTime.now();
  DateTime _targetTime = DateTime.now();
  Timer? _clockTimer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ── Animasi ───────────────────────────────────────────────
  late final AnimationController _contentAnimController;
  late final Animation<double> _contentFadeAnimation;
  late final Animation<Offset> _contentSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animasi konten
    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentAnimController,
      curve: Curves.easeOut,
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimController,
      curve: Curves.easeOut,
    ));

    // Mulai jam real-time
    _startClock();

    // Muat cuaca awal
    final startCity = widget.initialCity;
    if (startCity != null && startCity.isNotEmpty) {
      _loadWeather(city: startCity);
    } else {
      _loadWeather(city: 'Jakarta');
    }

    // Inisialisasi lokasi GPS untuk jam kiri
    _initGpsLocation();
  }

  // ── Clock Timer ──────────────────────────────────────────

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _gpsTime = DateTime.now();
          if (_currentWeather != null) {
            _targetTime = DateTime.now().toUtc().add(Duration(seconds: _currentWeather!.timezone));
          } else {
            _targetTime = DateTime.now();
          }
        });
      }
    });
  }

  /// Menginisialisasi lokasi GPS perangkat secara asinkron.
  Future<void> _initGpsLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getLastKnownPosition().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        ) ?? await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        final cityName = await _weatherService.getCityNameFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          setState(() {
            _gpsCityName = cityName;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _gpsCityName = 'GPS Tidak Diizinkan';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsCityName = 'GPS Tidak Aktif';
        });
      }
    }
  }

  // ── Weather Loading ──────────────────────────────────────

  /// Muat data cuaca: bisa berdasarkan kota atau koordinat GPS.
  Future<void> _loadWeather({String? city, Position? position}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _contentAnimController.reset();

    try {
      CurrentWeather weather;
      List<ForecastDay> forecast;

      if (position != null) {
        // Berdasarkan GPS
        weather = await _weatherService.fetchWeatherByCoordinates(
          position.latitude,
          position.longitude,
        );
        forecast = await _weatherService.fetchForecastByCoordinates(
          position.latitude,
          position.longitude,
        );
        // Perbarui nama kota GPS/asli
        _gpsCityName = weather.cityName;
      } else {
        // Berdasarkan nama kota
        final targetCity = (city?.trim().isNotEmpty == true)
            ? city!
            : 'Jakarta';
        weather = await _weatherService.fetchWeatherByCity(targetCity);
        forecast = await _weatherService.fetchForecastByCity(targetCity);
      }

      if (!mounted) return;

      // Simpan kota ke SharedPreferences
      await _saveLastCity(weather.cityName);

      setState(() {
        _currentWeather = weather;
        _forecast = forecast;
        _isLoading = false;
        _errorMessage = null;
      });

      // ── UPDATE TEMA DINAMIS ──────────────────────────────
      // Perbarui ValueNotifier global berdasarkan kode ikon cuaca.
      // Ini akan memicu rebuild MaterialApp dengan ThemeData yang sesuai.
      isNightNotifier.value = _isNight;

      // Jalankan animasi konten masuk
      _contentAnimController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Simpan nama kota ke SharedPreferences.
  Future<void> _saveLastCity(String cityName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_city', cityName);
    } catch (_) {}
  }

  /// Handler pencarian kota dari Search Bar.
  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _searchFocusNode.unfocus();
    _loadWeather(city: query);
  }

  /// Handler tombol GPS.
  Future<void> _onGpsPressed() async {
    _searchFocusNode.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final position = await _weatherService.getCurrentPosition();
      await _loadWeather(position: position);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Computed Properties ──────────────────────────────────

  /// Deteksi siang/malam dari kode ikon API cuaca.
  /// Fallback ke waktu lokal jika data cuaca belum tersedia.
  bool get _isNight {
    if (_currentWeather != null) {
      // Gunakan kode ikon dari API (paling akurat untuk lokasi dicari)
      return isNightFromIconCode(_currentWeather!.weatherIcon);
    }
    // Fallback: waktu lokal perangkat
    final hour = _gpsTime.hour;
    return hour < 6 || hour >= 19;
  }

  List<Color> get _backgroundGradient {
    if (_currentWeather == null) {
      return _isNight
          ? const [Color(0xFF0A0E2A), Color(0xFF1A1F5E), Color(0xFF2D1B69)]
          : const [Color(0xFF546E7A), Color(0xFF78909C), Color(0xFF90A4AE)];
    }
    return _getWeatherGradient(_currentWeather!.weatherMain, _isNight);
  }

  Color get _accentColor {
    if (_currentWeather == null) return const Color(0xFFFFD700);
    return _isNight
        ? const Color(0xFFBBDEFB)
        : _getWeatherAccentColor(_currentWeather!.weatherMain);
  }

  // ── Adaptive Theme Colors ─────────────────────────────────
  // Warna-warna ini otomatis menyesuaikan berdasarkan ThemeData(brightness).
  // Siang: teks gelap, glass terang. Malam: teks putih, glass gelap.

  /// Warna teks utama dari tema aktif (putih saat gelap, hitam saat terang).
  Color get _onSurface => Theme.of(context).colorScheme.onSurface;

  /// Background glassmorphism card.
  Color get _glassBackground => _isNight
      ? Colors.white.withOpacity(0.10)
      : Colors.white.withOpacity(0.55);

  /// Background glassmorphism yang lebih subtle (untuk sub-item).
  Color get _glassBackgroundSubtle => _isNight
      ? Colors.white.withOpacity(0.08)
      : Colors.white.withOpacity(0.40);

  /// Border glassmorphism card.
  Color get _glassBorder => _isNight
      ? Colors.white.withOpacity(0.20)
      : Colors.white.withOpacity(0.70);

  /// Border glassmorphism yang lebih subtle.
  Color get _glassBorderSubtle => _isNight
      ? Colors.white.withOpacity(0.12)
      : Colors.white.withOpacity(0.50);

  // ── Dispose ──────────────────────────────────────────────

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _contentAnimController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => _searchFocusNode.unfocus(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Search Bar & GPS Button ──────────────
                        _buildSearchBar(),

                        const SizedBox(height: 20),

                        // ── Jam & Tanggal Real-time ──────────────
                        _buildClockSection(),

                        const SizedBox(height: 24),

                        // ── Konten Cuaca (Loading / Error / Data) ─
                        _buildWeatherContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS SECTION
  // ============================================================

  // ── Search Bar ────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Row(
      children: [
        // TextField pencarian kota
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _glassBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _glassBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isNight ? 0.15 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                color: _onSurface,
                fontSize: 15,
              ),
              cursorColor: _onSurface,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
              decoration: InputDecoration(
                hintText: 'Cari kota...',
                hintStyle: TextStyle(
                  color: _onSurface.withOpacity(0.45),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _onSurface.withOpacity(0.6),
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Tombol GPS (selalu kontras di atas accent color)
        GestureDetector(
          onTap: _onGpsPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentColor.withOpacity(0.8),
                  _accentColor.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.my_location_rounded,
              color: _isNight ? Colors.white : const Color(0xFF1A1A2E),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ── Clock & Date ──────────────────────────────────────────

  Widget _buildClockSection() {
    final gpsTimeStr = DateFormat('HH:mm:ss').format(_gpsTime);
    final targetTimeStr = DateFormat('HH:mm:ss').format(_targetTime);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _glassBackgroundSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Jam GPS asli (kiri)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      color: _accentColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gpsTimeStr,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: _accentColor.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _gpsCityName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Pemisah "/"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '/',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: _accentColor,
              ),
            ),
          ),

          // Jam cuaca kota yang dilihat (kanan)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      targetTimeStr,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: _accentColor.withOpacity(0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.public_rounded,
                      color: _accentColor,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentWeather?.cityName ?? 'Memuat...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.start,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Weather Content Router ────────────────────────────────

  Widget _buildWeatherContent() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();
    if (_currentWeather == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: SlideTransition(
        position: _contentSlideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentWeather(),
            const SizedBox(height: 20),
            _buildWeatherDetailsCard(),
            const SizedBox(height: 20),
            _buildForecastSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Loading State ─────────────────────────────────────────

  Widget _buildLoadingState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: _accentColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat data cuaca...',
              style: TextStyle(
                color: _onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: _onSurface,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadWeather(
              city: _currentWeather?.cityName ?? 'Jakarta',
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isNight
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.08),
              foregroundColor: _onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Current Weather ───────────────────────────────────────

  Widget _buildCurrentWeather() {
    final weather = _currentWeather!;
    final emoji = WeatherService.getWeatherEmoji(weather.weatherMain);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _glassBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isNight ? 0.15 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Nama Kota
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_rounded,
                color: _accentColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  weather.cityName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Emoji Cuaca Besar
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _glassBackgroundSubtle,
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 64)),
            ),
          ),

          const SizedBox(height: 20),

          // Suhu Utama (gradient text: onSurface → accent)
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_onSurface, _accentColor],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              '${weather.temperature.round()}°C',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: Colors.white, // Base untuk ShaderMask
                height: 1.0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Deskripsi Status Cuaca
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withOpacity(0.4)),
            ),
            child: Text(
              _capitalize(weather.weatherDescription),
              style: TextStyle(
                fontSize: 15,
                color: _accentColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Feels Like
          Text(
            'Terasa seperti ${weather.feelsLike.round()}°C',
            style: TextStyle(
              fontSize: 13,
              color: _onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weather Details Card ──────────────────────────────────

  Widget _buildWeatherDetailsCard() {
    final weather = _currentWeather!;
    final windKmh = (weather.windSpeed * 3.6).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Cuaca',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _onSurface.withOpacity(0.7),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: '💧',
                  label: 'Kelembapan',
                  value: '${weather.humidity}%',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: '💨',
                  label: 'Angin',
                  value: '$windKmh km/h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: '🌡️',
                  label: 'Maks',
                  value: '${weather.tempMax.round()}°C',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: '❄️',
                  label: 'Min',
                  value: '${weather.tempMin.round()}°C',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _glassBackgroundSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glassBorderSubtle),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _onSurface.withOpacity(0.55),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Forecast Section ───────────────────────────────

  Widget _buildForecastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Prakiraan 7 Hari',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _onSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        // Daftar vertikal forecast
        ..._forecast.take(7).map((day) => _buildForecastRow(day)),
      ],
    );
  }

  Widget _buildForecastRow(ForecastDay day) {
    final dayName = DateFormat('EEEE', 'id_ID').format(day.date);
    final dateStr = DateFormat('d MMM', 'id_ID').format(day.date);
    final emoji = WeatherService.getWeatherEmoji(day.weatherMain);
    final windKmh = (day.windSpeed * 3.6).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _glassBackgroundSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _glassBorderSubtle),
      ),
      child: Row(
        children: [
          // Tanggal
          SizedBox(
            width: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: _onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // Emoji Cuaca
          Text(emoji, style: const TextStyle(fontSize: 24)),

          const SizedBox(width: 8),

          // Deskripsi singkat
          Expanded(
            child: Text(
              _capitalize(day.weatherDescription),
              style: TextStyle(
                fontSize: 12,
                color: _onSurface.withOpacity(0.65),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Suhu min-max
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${day.tempMax.round()}° / ${day.tempMin.round()}°',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    size: 11,
                    color: _onSurface.withOpacity(0.5),
                  ),
                  Text(
                    ' ${day.humidity}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: _onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.air_rounded,
                    size: 11,
                    color: _onSurface.withOpacity(0.5),
                  ),
                  Text(
                    ' $windKmh',
                    style: TextStyle(
                      fontSize: 11,
                      color: _onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Utility ───────────────────────────────────────────────

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
