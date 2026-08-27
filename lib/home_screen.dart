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
/// Siang → gradasi terang & vibran, Malam → gradasi gelap & elegan.
List<Color> _getWeatherGradient(String weatherMain, bool isNight) {
  if (isNight) {
    return const [
      Color(0xFF090D24),
      Color(0xFF141944),
      Color(0xFF221650),
      Color(0xFF2E1A47),
    ];
  }
  // ── Gradasi Siang (lebih terang & kontras) ──
  switch (weatherMain.toLowerCase()) {
    case 'clear':
      return const [
        Color(0xFF0288D1), // Sky Blue
        Color(0xFF29B6F6),
        Color(0xFF4FC3F7),
        Color(0xFFFFD54F), // Sun Warmth
      ];
    case 'rain':
    case 'drizzle':
      return const [
        Color(0xFF37474F), // Deep Slate
        Color(0xFF546E7A),
        Color(0xFF78909C),
        Color(0xFFB0BEC5),
      ];
    case 'thunderstorm':
      return const [
        Color(0xFF263238), // Dark Charcoal
        Color(0xFF37474F),
        Color(0xFF455A64),
        Color(0xFF5E35B1), // Storm Purple
      ];
    case 'snow':
      return const [
        Color(0xFF81D4FA),
        Color(0xFFB3E5FC),
        Color(0xFFE1F5FE),
        Color(0xFFFFFFFF),
      ];
    case 'clouds':
    default:
      return const [
        Color(0xFF455A64), // Slate Sky
        Color(0xFF607D8B),
        Color(0xFF90A4AE),
        Color(0xFFCFD8DC),
      ];
  }
}

Color _getWeatherAccentColor(String weatherMain) {
  switch (weatherMain.toLowerCase()) {
    case 'clear':
      return const Color(0xFFFFD54F);
    case 'rain':
    case 'drizzle':
      return const Color(0xFF81D4FA);
    case 'thunderstorm':
      return const Color(0xFFE040FB);
    case 'snow':
      return const Color(0xFFE1F5FE);
    default:
      return const Color(0xFFE0F7FA); // Ice Cyan yang terang & jernih untuk berawan
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
  String _gpsCityName = 'Finding Location...';
  DateTime _gpsTime = DateTime.now();
  DateTime _targetTime = DateTime.now();
  Timer? _clockTimer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ── State Sugesti & Riwayat Pencarian ──────────────────────
  List<CitySuggestion> _citySuggestions = [];
  List<String> _searchHistory = [];
  bool _isFetchingSuggestions = false;
  Timer? _suggestionDebounceTimer;

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

    // Listeners untuk pencarian dan sugesti
    _searchController.addListener(_onSearchQueryChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadSearchHistory();

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
            _gpsCityName = 'GPS Denied';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsCityName = 'GPS Disabled';
        });
      }
    }
  }

  // ── Weather Loading ──────────────────────────────────────

  /// Muat data cuaca: bisa berdasarkan kota, koordinat Geocoding, atau koordinat GPS.
  Future<void> _loadWeather({
    String? city,
    Position? position,
    double? lat,
    double? lon,
    String? locationDisplayName,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _contentAnimController.reset();

    try {
      CurrentWeather weather;
      List<ForecastDay> forecast;

      if (lat != null && lon != null) {
        // 1. Berdasarkan koordinat persis dari hasil Geocoding API (misal: Teras, Jawa Tengah)
        weather = await _weatherService.fetchWeatherByCoordinates(
          lat,
          lon,
          fallbackName: locationDisplayName ?? city,
        );
        forecast = await _weatherService.fetchForecastByCoordinates(
          lat,
          lon,
        );
      } else if (position != null) {
        // 2. Berdasarkan GPS Perangkat
        weather = await _weatherService.fetchWeatherByCoordinates(
          position.latitude,
          position.longitude,
        );
        forecast = await _weatherService.fetchForecastByCoordinates(
          position.latitude,
          position.longitude,
        );
        _gpsCityName = weather.cityName;
      } else {
        // 3. Berdasarkan pencarian nama kota
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

  // ── Helper Sugesti & Riwayat Pencarian ────────────────────

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchQueryChanged() {
    if (mounted) setState(() {});
    _suggestionDebounceTimer?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _citySuggestions = [];
          _isFetchingSuggestions = false;
        });
      }
      return;
    }

    _suggestionDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _isFetchingSuggestions = true;
      });

      final results = await _weatherService.fetchCitySuggestions(query);

      if (!mounted) return;
      setState(() {
        _citySuggestions = results;
        _isFetchingSuggestions = false;
      });
    });
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToSearchHistory(String cityName) async {
    try {
      final trimmed = cityName.trim();
      if (trimmed.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      history.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      history.insert(0, trimmed);
      if (history.length > 8) {
        history.removeRange(8, history.length);
      }
      await prefs.setStringList('search_history', history);
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (_) {}
  }

  Future<void> _removeFromSearchHistory(String cityName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      history.removeWhere((item) => item.toLowerCase() == cityName.toLowerCase());
      await prefs.setStringList('search_history', history);
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (_) {}
  }

  Future<void> _clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
      if (mounted) {
        setState(() {
          _searchHistory = [];
        });
      }
    } catch (_) {}
  }

  void _selectCitySuggestion(CitySuggestion suggestion) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    if (mounted) {
      setState(() {
        _citySuggestions = [];
      });
    }

    String cleanState = (suggestion.state ?? '').trim();
    cleanState = cleanState
        .replaceAll('Special Region of ', '')
        .replaceAll('Kab. ', '')
        .replaceAll('DI ', '');

    final displayName = cleanState.isNotEmpty
        ? '${suggestion.name}, $cleanState'
        : suggestion.name;

    if (suggestion.lat != null && suggestion.lon != null) {
      // Panggil muat cuaca berdasarkan koordinat persis hasil Geocoding
      _loadWeather(
        lat: suggestion.lat,
        lon: suggestion.lon,
        city: suggestion.name,
        locationDisplayName: displayName,
      );
    } else {
      _loadWeather(city: displayName);
    }
    _saveToSearchHistory(suggestion.name);
  }

  /// Handler pencarian kota dari Search Bar.
  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _searchController.clear();
    _searchFocusNode.unfocus();
    if (mounted) {
      setState(() {
        _citySuggestions = [];
      });
    }
    _loadWeather(city: query);
    _saveToSearchHistory(query);
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

  /// Mendapatkan URL gambar latar belakang cuaca atmosferis dinamis.
  String _getWeatherBackgroundImage(String weatherMain, bool isNight) {
    if (isNight) {
      return 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?q=80&w=1000&auto=format&fit=crop';
    }
    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return 'https://images.unsplash.com/photo-1601297183305-6df142704ea2?q=80&w=1000&auto=format&fit=crop';
      case 'rain':
      case 'drizzle':
        return 'https://images.unsplash.com/photo-1519692933481-e162a57d6721?q=80&w=1000&auto=format&fit=crop';
      case 'thunderstorm':
        return 'https://images.unsplash.com/photo-1605727216801-e27ce1d0cc28?q=80&w=1000&auto=format&fit=crop';
      case 'snow':
        return 'https://images.unsplash.com/photo-1517299321529-639f8c26d4a1?q=80&w=1000&auto=format&fit=crop';
      case 'clouds':
      default:
        // Gambar awan mendung sesuai desain SkyCast
        return 'https://lh3.googleusercontent.com/aida-public/AB6AXuAH0fbKJ7fnYFZ3QoEZ97eteyUODzYZWoSIsEZ5wWQclT62Ewfyt65WrShFkmTcz9A_DViUJf7tfb_Th7W97yEVaG2thpuc1urIdO9CvE5DKBJ-CgktYHs-LYJgkQ26ouFNpIDgeIX4Dj9RKKE5IGDNzy2zRTfLT6RHSPc4XjaGiWbE6G9fHOUG8NZLV9_ZOGPcg8GzWTW9OjUsPpEKG_NvvM9tLd7za0QI_K26utoeTadJ3WEO7HkO';
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

  // ── Glassmorphism Theme Colors ─────────────────────────────

  /// Warna teks utama (selalu putih bersih untuk kontras tinggi di atas gambar latar belakang).
  Color get _onSurface => Colors.white;

  /// Background glassmorphism card (frosted slate-cloud grey tint untuk nuansa awan mendung alami).
  Color get _glassBackground => _isNight
      ? Colors.black.withOpacity(0.40)
      : const Color(0xFF334155).withOpacity(0.35);

  /// Background glassmorphism yang lebih subtle.
  Color get _glassBackgroundSubtle => _isNight
      ? Colors.black.withOpacity(0.28)
      : const Color(0xFF334155).withOpacity(0.22);

  /// Border glassmorphism card (sangat halus & smooth di malam hari, jernih di siang hari).
  Color get _glassBorder => _isNight
      ? Colors.white.withOpacity(0.08)
      : Colors.white.withOpacity(0.25);

  /// Border glassmorphism yang lebih subtle (seamless blend).
  Color get _glassBorderSubtle => _isNight
      ? Colors.white.withOpacity(0.05)
      : Colors.white.withOpacity(0.15);

  // ── Dispose ──────────────────────────────────────────────

  @override
  void dispose() {
    _clockTimer?.cancel();
    _suggestionDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchQueryChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
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
    final bgUrl = _getWeatherBackgroundImage(
      _currentWeather?.weatherMain ?? 'clouds',
      _isNight,
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Gambar Latar Belakang Atmosferis Dinamis ──
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1000),
              child: Image.network(
                bgUrl,
                key: ValueKey(bgUrl),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _backgroundGradient,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── 2. Gradient Atmospheric Overlay (Slate Cloud Tint saat berawan/siang) ──
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _isNight
                        ? Colors.black.withOpacity(0.65)
                        : const Color(0xFF1E293B).withOpacity(0.12),
                    _isNight
                        ? Colors.black.withOpacity(0.85)
                        : const Color(0xFF0F172A).withOpacity(0.28),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Konten Utama Aplikasi ──
          SafeArea(
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
        ],
      ),
    );
  }

  // ============================================================
  // WIDGETS SECTION
  // ============================================================

  // ── Search Bar ────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                    hintText: 'Search city...',
                    hintStyle: TextStyle(
                      color: _onSurface.withOpacity(0.45),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _onSurface.withOpacity(0.6),
                      size: 22,
                    ),
                    suffixIcon: _isFetchingSuggestions
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _accentColor,
                              ),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: _onSurface.withOpacity(0.5),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
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
        ),

        // ── List Sugesti (muncul saat kueri terisi & ada sugesti / sedang mencari) ──
        if (_searchController.text.trim().isNotEmpty &&
            (_searchFocusNode.hasFocus ||
                _citySuggestions.isNotEmpty ||
                _isFetchingSuggestions)) ...[
          const SizedBox(height: 10),
          _buildSuggestionsDropdown(),
        ],
      ],
    );
  }

  /// Menampilkan dropdown melayang berisi Rekomendasi Lokasi (Kota/Kabupaten/Kecamatan).
  Widget _buildSuggestionsDropdown() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    // Skenario 1: Sedang fetching
    if (_isFetchingSuggestions && _citySuggestions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _glassBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _glassBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Searching location suggestions...',
              style: TextStyle(
                color: _onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Skenario 2: Tidak ditemukan
    if (_citySuggestions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _glassBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _glassBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded,
                color: _onSurface.withOpacity(0.5), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No locations found matching "$query"',
                style: TextStyle(
                  color: _onSurface.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Skenario 3: Ada hasil sugesti
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _glassBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isNight ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: _accentColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Suggested Locations',
                    style: TextStyle(
                      color: _onSurface.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: _glassBorderSubtle),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _citySuggestions.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, thickness: 0.3, color: _glassBorderSubtle),
              itemBuilder: (context, index) {
                final suggestion = _citySuggestions[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _selectCitySuggestion(suggestion),
                  onTap: () => _selectCitySuggestion(suggestion),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_city_rounded,
                              color: _accentColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.name,
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((suggestion.state != null &&
                                        suggestion.state!.isNotEmpty) ||
                                    suggestion.country.isNotEmpty)
                                  Text(
                                    [
                                      if (suggestion.state != null &&
                                          suggestion.state!.isNotEmpty)
                                        suggestion.state,
                                      if (suggestion.country.isNotEmpty)
                                        suggestion.country
                                    ].join(', '),
                                    style: TextStyle(
                                      color: _onSurface.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.north_west_rounded,
                            color: _onSurface.withOpacity(0.35),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Clock & Date ──────────────────────────────────────────

  Widget _buildClockSection() {
    final gpsTimeStr = DateFormat('HH:mm:ss').format(_gpsTime);
    final targetTimeStr = DateFormat('HH:mm:ss').format(_targetTime);
    final dateFormatted = DateFormat('EEEE, d MMMM yyyy', 'en_US').format(_targetTime);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _glassBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isNight ? 0.2 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Jam GPS asli (kiri)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _glassBackgroundSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _glassBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.8),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.my_location_rounded,
                            color: _accentColor,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            gpsTimeStr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _gpsCityName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Pemisah "/"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '⚡',
                  style: TextStyle(
                    fontSize: 16,
                    color: _accentColor,
                  ),
                ),
              ),

              // Jam cuaca kota yang dilihat (kanan)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _glassBackgroundSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _glassBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            targetTimeStr,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _onSurface,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.public_rounded,
                            color: _accentColor,
                            size: 13,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentWeather?.cityName ?? 'Loading...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Tanggal Lengkap Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _glassBackgroundSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _glassBorderSubtle),
          ),
          child: Text(
            dateFormatted,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _onSurface.withOpacity(0.75),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
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
              'Fetching weather data...',
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
            label: const Text('Try Again'),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _glassBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _glassBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isNight ? 0.25 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _accentColor.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Nama Kota Badge (Responsif & Multi-line jika nama lokasi panjang)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _glassBackgroundSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _glassBorderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: _accentColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    weather.cityName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                      letterSpacing: 0.3,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Emoji Cuaca Besar dengan Glowing Radial Halo
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentColor.withOpacity(0.35),
                      _accentColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _glassBackgroundSubtle,
                  border: Border.all(color: _glassBorderSubtle, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 60)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Suhu Utama (Tajam & Berkontras Tinggi dengan Text Shadow)
          Text(
            '${weather.temperature.round()}°C',
            style: TextStyle(
              fontSize: 68,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Deskripsi Status Cuaca Badge (Kontras Tinggi & Tajam)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.28),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accentColor.withOpacity(0.6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _capitalize(weather.weatherDescription),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Rentang Suhu & Terasa Seperti Pill (Kontras Tinggi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _glassBackgroundSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _glassBorderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded,
                    size: 13, color: Color(0xFF64B5F6)),
                const SizedBox(width: 2),
                Text(
                  '${weather.tempMin.round()}°',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '  •  ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const Icon(Icons.arrow_upward_rounded,
                    size: 13, color: Color(0xFFFFB74D)),
                const SizedBox(width: 2),
                Text(
                  '${weather.tempMax.round()}°',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '  •  ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                Text(
                  'Feels like ${weather.feelsLike.round()}°C',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
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
    final visibilityKm = (weather.visibility / 1000).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isNight ? 0.2 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_rounded,
                  color: _accentColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'WEATHER DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _onSurface.withOpacity(0.75),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: '💧',
                  label: 'Humidity',
                  value: '${weather.humidity}%',
                  subtitle: weather.humidity > 70 ? 'High' : 'Normal',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDetailItem(
                  icon: '💨',
                  label: 'Wind Speed',
                  value: '$windKmh km/h',
                  subtitle: weather.windSpeed > 10 ? 'High' : 'Gentle',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: '👁️',
                  label: 'Visibility',
                  value: '$visibilityKm km',
                  subtitle: 'Clear',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDetailItem(
                  icon: '🌡️',
                  label: 'Feels Like',
                  value: '${weather.feelsLike.round()}°C',
                  subtitle: 'Normal',
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
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _glassBackgroundSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorderSubtle),
      ),
      child: Row(
        children: [
          // Kiri: Icon Container yang solid & agak besar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accentColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
          ),

          const SizedBox(width: 10),

          // Kanan: Tulisan Label (Atas) & Angka Nilai (Bawah)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _onSurface.withOpacity(0.7),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
                '7-DAY FORECAST',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _onSurface.withOpacity(0.85),
                  letterSpacing: 1.2,
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
    final dayName = DateFormat('EEEE', 'en_US').format(day.date);
    final dateStr = DateFormat('d MMM', 'en_US').format(day.date);
    final emoji = WeatherService.getWeatherEmoji(day.weatherMain);
    final windKmh = (day.windSpeed * 3.6).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _glassBackgroundSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorderSubtle),
      ),
      child: Row(
        children: [
          // Hari & Tanggal
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: _onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),

          // Emoji Cuaca
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),

          const SizedBox(width: 10),

          // Deskripsi Cuaca
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(day.weatherDescription),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _onSurface.withOpacity(0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      size: 11,
                      color: _accentColor,
                    ),
                    Text(
                      ' ${day.humidity}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: _onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.air_rounded,
                      size: 11,
                      color: _accentColor,
                    ),
                    Text(
                      ' $windKmh km/h',
                      style: TextStyle(
                        fontSize: 11,
                        color: _onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Visual Suhu (Min & Max)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '${day.tempMin.round()}°',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _onSurface.withOpacity(0.6),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent,
                          _accentColor,
                          Colors.orangeAccent,
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${day.tempMax.round()}°',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _accentColor,
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
