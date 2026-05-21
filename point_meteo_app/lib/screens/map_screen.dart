import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/weather_service.dart';
import '../widgets/state_views.dart';

// ─── Design tokens ────────────────────────────────────────────
const Color _kBg      = Color(0xFF060D1A);
const Color _kGlass   = Color(0xC8070E1C);
const Color _kBorder  = Color(0xFF182840);
const Color _kAccent  = Color(0xFF38BDF8);
const Color _kAmber   = Color(0xFFF59E0B);
const Color _kPri     = Color(0xFFE2E8F0);
const Color _kSec     = Color(0xFF4E6380);
const Color _kDivider = Color(0xFF0F2235);
// ─────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final Map<String, List<dynamic>> _forecastCache = {};
  final TextEditingController _citySearchController = TextEditingController();
  final ScrollController _timelineScrollCtrl = ScrollController();

  final List<String> _providers = const [
    'Open-Meteo',
    'WeatherAPI',
    'Meteo-Concept',
  ];

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  String _selectedProvider = 'Open-Meteo';
  LatLng? _center;
  String? _cityName;
  final List<String> _recentCities = [];
  List<String> _favoriteCities = [];
  bool _isFavorite = false;
  List<dynamic> _hourlyForecast = [];
  int _selectedHourIndex = 0;
  bool _isInitializing = true;
  bool _isFetchingForecast = false;
  bool _isSearchingCity = false;
  bool _isControlsExpanded = true;
  bool _isTimelineExpanded = true;
  String? _errorMessage;
  bool _isBackendUnavailable = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.linear),
    );
    _loadFavorites();
    _initializeMap();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _citySearchController.dispose();
    _timelineScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Logic (unchanged) ────────────────────────────────────

  Future<Position> _getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permissions refusées');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissions bloquées définitivement');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  String _cacheKeyFor(LatLng center, String provider) =>
      '$provider|${center.latitude.toStringAsFixed(4)}|${center.longitude.toStringAsFixed(4)}';

  Map<String, dynamic>? _selectedHourData() {
    if (_hourlyForecast.isEmpty) return null;
    final index = _selectedHourIndex.clamp(0, _hourlyForecast.length - 1);
    return Map<String, dynamic>.from(_hourlyForecast[index]);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoriteCities = prefs.getStringList('favorites') ?? [];
      if (_cityName != null) {
        _isFavorite = _favoriteCities.contains(_cityName);
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final cityName = _cityName ?? _citySearchController.text.trim();
    if (cityName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (_favoriteCities.contains(cityName)) {
        _favoriteCities.remove(cityName);
        _isFavorite = false;
      } else {
        _favoriteCities.add(cityName);
        _isFavorite = true;
      }
    });
    await prefs.setStringList('favorites', _favoriteCities);
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  IconData _getWeatherIcon(int weatherCode) {
    if (weatherCode == 0) return Icons.wb_sunny_rounded;
    if (weatherCode == 1 || weatherCode == 2) return Icons.cloud_queue_rounded;
    if (weatherCode == 3) return Icons.cloud_rounded;
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop_rounded;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit_rounded;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.umbrella_rounded;
    if (weatherCode >= 95 && weatherCode <= 99) return Icons.flash_on_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Color _getWeatherIconColor(int weatherCode) {
    if (weatherCode == 0) return _kAmber;
    if (weatherCode == 1 || weatherCode == 2) return const Color(0xFFCDD5DF);
    if (weatherCode >= 51 && weatherCode <= 67) return _kAccent;
    if (weatherCode >= 71 && weatherCode <= 77) return const Color(0xFFE0F2FE);
    if (weatherCode >= 95 && weatherCode <= 99) return const Color(0xFFFACC15);
    return _kPri;
  }

  String _describeWeatherCode(int weatherCode) {
    if (weatherCode == 0) return 'ensoleillé';
    if (weatherCode == 1 || weatherCode == 2) return 'partiellement nuageux';
    if (weatherCode == 3) return 'nuageux';
    if (weatherCode == 45 || weatherCode == 48) return 'brouillard';
    if (weatherCode >= 51 && weatherCode <= 67) return 'pluie';
    if (weatherCode >= 71 && weatherCode <= 77) return 'neige';
    if (weatherCode >= 80 && weatherCode <= 82) return 'averses';
    if (weatherCode >= 95 && weatherCode <= 99) return 'orage';
    return 'conditions météo inconnues';
  }

  String _formatHourLabel(String timeValue) {
    try {
      final dt = DateTime.parse(timeValue.replaceFirst(' ', 'T'));
      return '${dt.hour.toString().padLeft(2, '0')}h';
    } catch (_) {
      if (timeValue.length >= 16) return '${timeValue.substring(11, 13)}h';
      return timeValue;
    }
  }

  String _formatSelectedTitle(String timeValue) {
    try {
      final dt = DateTime.parse(timeValue.replaceFirst(' ', 'T'));
      final days = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
      final day = days[dt.weekday - 1];
      return '$day ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} · ${dt.hour.toString().padLeft(2, '0')}:00';
    } catch (_) {
      return timeValue;
    }
  }

  int _findCurrentHourIndex(List<dynamic> forecast) {
    if (forecast.isEmpty) return 0;
    final now = DateTime.now();
    for (var i = 0; i < forecast.length; i++) {
      final timeValue = forecast[i]['time']?.toString();
      if (timeValue == null) continue;
      try {
        final dt = DateTime.parse(timeValue.replaceFirst(' ', 'T'));
        if (!dt.isBefore(now)) return i;
      } catch (_) {
        continue;
      }
    }
    return 0;
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _isBackendUnavailable = false;
    });
    try {
      final position = await _getCurrentPosition();
      final center = LatLng(position.latitude, position.longitude);
      final locationInfo = await _weatherService.searchByCoords(
        position.latitude,
        position.longitude,
      );
      final forecast = await _loadForecast(center);
      if (!mounted) return;
      setState(() {
        _center = center;
        _cityName = locationInfo['ville']?.toString();
        _citySearchController.text = _cityName ?? '';
        _registerRecentCity(_cityName ?? 'Position actuelle');
        _isFavorite = _cityName != null && _favoriteCities.contains(_cityName);
        _hourlyForecast = forecast;
        _selectedHourIndex = _findCurrentHourIndex(forecast);
        _isInitializing = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
    } on BackendUnavailableException {
      if (!mounted) return;
      setState(() {
        _isBackendUnavailable = true;
        _errorMessage = null;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _searchCity() async {
    final query = _citySearchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _isSearchingCity = true;
      _errorMessage = null;
      _isBackendUnavailable = false;
    });
    try {
      final city = await _weatherService.searchCity(query);
      final lat = double.parse(city['coords']['latitude'].toString());
      final lon = double.parse(city['coords']['longitude'].toString());
      final center = LatLng(lat, lon);
      final forecast = await _loadForecast(center);
      if (!mounted) return;
      setState(() {
        _center = center;
        _cityName = city['ville']?.toString() ?? query;
        _citySearchController.text = _cityName ?? query;
        _registerRecentCity(_cityName ?? query);
        _isFavorite = _cityName != null && _favoriteCities.contains(_cityName);
        _hourlyForecast = forecast;
        _selectedHourIndex = _findCurrentHourIndex(forecast);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
    } on BackendUnavailableException {
      if (!mounted) return;
      setState(() {
        _isBackendUnavailable = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isSearchingCity = false);
    }
  }

  Future<List<dynamic>> _loadForecast(LatLng center) async {
    final cacheKey = _cacheKeyFor(center, _selectedProvider);
    final cached = _forecastCache[cacheKey];
    if (cached != null) return cached;
    setState(() => _isFetchingForecast = true);
    try {
      final forecast = await _weatherService.getHourlyWeather(
        center.latitude,
        center.longitude,
        _selectedProvider,
      );
      _forecastCache[cacheKey] = forecast;
      return forecast;
    } finally {
      if (mounted) setState(() => _isFetchingForecast = false);
    }
  }

  void _registerRecentCity(String city) {
    final normalized = city.trim();
    if (normalized.isEmpty) return;
    _recentCities.removeWhere((c) => c.toLowerCase() == normalized.toLowerCase());
    _recentCities.insert(0, normalized);
    if (_recentCities.length > 5) _recentCities.removeLast();
  }

  Future<void> _reloadForecast() async {
    if (_center == null) return;
    setState(() {
      _isFetchingForecast = true;
      _errorMessage = null;
      _isBackendUnavailable = false;
    });
    try {
      final forecast = await _loadForecast(_center!);
      if (!mounted) return;
      setState(() {
        _hourlyForecast = forecast;
        _selectedHourIndex = _findCurrentHourIndex(forecast);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
    } on BackendUnavailableException {
      if (!mounted) return;
      setState(() {
        _isBackendUnavailable = true;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _onProviderChanged(String? provider) async {
    if (provider == null || provider == _selectedProvider) return;
    setState(() => _selectedProvider = provider);
    await _reloadForecast();
  }

  Future<void> _retry() async {
    if (_center == null) {
      await _initializeMap();
      return;
    }
    await _reloadForecast();
  }

  void _scrollToCurrentHour() {
    if (!_timelineScrollCtrl.hasClients) return;
    const cardWidth = 68.0;
    final offset = (_selectedHourIndex * cardWidth)
        .clamp(0.0, _timelineScrollCtrl.position.maxScrollExtent);
    _timelineScrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  // ─── UI helpers ───────────────────────────────────────────

  Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(16), BorderRadius? radius}) {
    final br = radius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kGlass,
            borderRadius: br,
            border: Border.all(color: _kBorder),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: _kSec,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      );

  // ─── Map marker ───────────────────────────────────────────

  Widget _buildMapMarker(Map<String, dynamic> hourData) {
    final code = _asInt(hourData['weathercode'] ?? hourData['code_meteo']);
    final temp = hourData['temp']?.toString() ?? '--';

    return Semantics(
      label: 'Repère météo ${_describeWeatherCode(code)}, $temp degrés',
      image: true,
      child: SizedBox(
        width: 160,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse rings
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => CustomPaint(
                  painter: _PulsePainter(
                    progress: _pulseAnim.value,
                    color: _kAccent,
                  ),
                ),
              ),
            ),
            // Weather pill — plain container (BackdropFilter unsupported in flutter_map layers)
            Positioned(
              top: 8,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xF0070E1C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _kAccent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.3),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getWeatherIcon(code),
                        color: _getWeatherIconColor(code),
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$temp°',
                        style: const TextStyle(
                          color: _kPri,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Center dot (map point)
            Positioned(
              bottom: 22,
              child: ExcludeSemantics(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kAccent,
                    boxShadow: [
                      BoxShadow(
                        color: _kAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
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

  // ─── Top overlay ──────────────────────────────────────────

  Widget _buildTopOverlay() {
    return _glass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _citySearchController,
                    enabled: !_isSearchingCity && !_isInitializing,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchCity(),
                    style: const TextStyle(
                      color: _kPri,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une ville…',
                      hintStyle: const TextStyle(color: _kSec, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: _kSec, size: 18),
                      suffixIcon: _isSearchingCity
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _kAccent,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: _searchCity,
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: _kAccent,
                                size: 18,
                              ),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                icon: Icons.gps_fixed_rounded,
                tooltip: 'Ma position',
                onTap: _isInitializing ? null : _initializeMap,
                active: false,
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                onTap: _isInitializing ? null : _toggleFavorite,
                active: _isFavorite,
                activeColor: const Color(0xFFF43F5E),
              ),
              const SizedBox(width: 6),
              _iconBtn(
                icon: Icons.refresh_rounded,
                tooltip: 'Actualiser',
                onTap: _isFetchingForecast ? null : _reloadForecast,
                active: false,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _isControlsExpanded = !_isControlsExpanded),
                child: AnimatedRotation(
                  turns: _isControlsExpanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_up_rounded, color: _kSec, size: 22),
                ),
              ),
            ],
          ),

          if (_isControlsExpanded) ...[
            const SizedBox(height: 14),

            // Provider selector
            _label('SOURCE'),
            const SizedBox(height: 8),
            Row(
              children: _providers.map((p) {
                final selected = p == _selectedProvider;
                final busy = _isFetchingForecast;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: busy ? null : () => _onProviderChanged(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kAccent.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? _kAccent : _kBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          color: selected ? _kAccent : _kSec,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // City info
            if (_cityName != null) ...[
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kAccent,
                      boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.5), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cityName!.toUpperCase(),
                      style: const TextStyle(
                        color: _kPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_center != null)
                    Text(
                      '${_center!.latitude.toStringAsFixed(3)}, ${_center!.longitude.toStringAsFixed(3)}',
                      style: const TextStyle(
                        color: _kSec,
                        fontSize: 10,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ] else if (_center == null) ...[
              Text(
                'Localisation en cours…',
                style: const TextStyle(color: _kSec, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],

            // Recent cities
            if (_recentCities.isNotEmpty) ...[
              _label('RÉCENTS'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _recentCities.map((city) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          _citySearchController.text = city;
                          _searchCity();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kDivider,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Text(
                            city,
                            style: const TextStyle(
                              color: _kPri,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Favorites
            if (_favoriteCities.isNotEmpty) ...[
              const SizedBox(height: 8),
              _label('FAVORIS'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _favoriteCities.map((city) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          _citySearchController.text = city;
                          _searchCity();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A0B1A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF3D1535),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 11,
                                color: Color(0xFFF43F5E),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                city,
                                style: const TextStyle(
                                  color: _kPri,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    required bool active,
    Color activeColor = _kAccent,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.15)
                : _kBorder.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? activeColor.withValues(alpha: 0.5) : _kBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? _kSec.withValues(alpha: 0.4)
                : active
                    ? activeColor
                    : _kSec,
          ),
        ),
      ),
    );
  }

  // ─── Bottom overlay ───────────────────────────────────────

  Widget _buildBottomOverlay() {
    final selectedHour = _selectedHourData();
    final selectedTime = selectedHour == null
        ? '--'
        : _formatSelectedTitle(selectedHour['time']?.toString() ?? '--');
    final code = selectedHour == null
        ? 0
        : _asInt(selectedHour['weathercode'] ?? selectedHour['code_meteo']);
    final temp = selectedHour?['temp']?.toString() ?? '--';

    return _glass(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle visual
          Center(
            child: Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Summary row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getWeatherIconColor(code).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getWeatherIcon(code),
                  color: _getWeatherIconColor(code),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedTime,
                      style: const TextStyle(
                        color: _kPri,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (selectedHour != null)
                      Text(
                        _describeWeatherCode(code),
                        style: const TextStyle(
                          color: _kSec,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              if (selectedHour != null) ...[
                Text(
                  '$temp°',
                  style: const TextStyle(
                    color: _kPri,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: [ui.FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: () => setState(() {
                  _isTimelineExpanded = !_isTimelineExpanded;
                }),
                child: AnimatedRotation(
                  turns: _isTimelineExpanded ? 0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _kSec,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          if (_isTimelineExpanded && _hourlyForecast.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: _kDivider,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.builder(
                controller: _timelineScrollCtrl,
                scrollDirection: Axis.horizontal,
                itemCount: _hourlyForecast.length,
                itemBuilder: (context, index) => _buildHourCard(index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHourCard(int index) {
    final hourData = _hourlyForecast[index];
    final code = _asInt(hourData['weathercode'] ?? hourData['code_meteo']);
    final temp = hourData['temp']?.toString() ?? '--';
    final timeLabel = _formatHourLabel(hourData['time']?.toString() ?? '--');
    final isSelected = index == _selectedHourIndex;

    return Semantics(
      label: '$timeLabel, ${_describeWeatherCode(code)}, $temp degrés',
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _selectedHourIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? _kAccent.withValues(alpha: 0.12)
                : _kDivider.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _kAccent : _kBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  color: isSelected ? _kAccent : _kSec,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 7),
              Icon(
                _getWeatherIcon(code),
                color: isSelected
                    ? _getWeatherIconColor(code)
                    : _getWeatherIconColor(code).withValues(alpha: 0.6),
                size: 19,
              ),
              const SizedBox(height: 7),
              Text(
                '$temp°',
                style: TextStyle(
                  color: isSelected ? _kPri : _kSec,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text(
          'CARTE MÉTÉO',
          style: TextStyle(
            color: _kPri,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        backgroundColor: _kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(color: _kBg),

          // Map
          if (_center != null)
            FlutterMap(
              key: ValueKey(
                '${_center!.latitude.toStringAsFixed(4)}_${_center!.longitude.toStringAsFixed(4)}',
              ),
              options: MapOptions(
                initialCenter: _center!,
                initialZoom: 12.8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pointmeteo.app',
                ),
                if (_hourlyForecast.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center!,
                        width: 160,
                        height: 120,
                        child: _buildMapMarker(_selectedHourData()!),
                      ),
                    ],
                  ),
              ],
            )
          else
            const SizedBox.expand(),

          // Top overlay
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: SafeArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                child: _buildTopOverlay(),
              ),
            ),
          ),

          // Bottom overlay
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                child: _buildBottomOverlay(),
              ),
            ),
          ),

          // Initializing overlay
          if (_isInitializing)
            Positioned.fill(
              child: Container(
                color: _kBg.withValues(alpha: 0.85),
                child: Center(
                  child: Semantics(
                    label: 'Chargement de la carte',
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ExcludeSemantics(
                          child: Text(
                            'LOCALISATION…',
                            style: TextStyle(
                              color: _kSec,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Fetching indicator (non-blocking)
          if (_isFetchingForecast && !_isInitializing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Semantics(
                  label: 'Mise à jour des données en cours',
                  liveRegion: true,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    color: _kAccent.withValues(alpha: 0.7),
                    minHeight: 2,
                  ),
                ),
              ),
            ),

          // Error / server unavailable overlay
          if (_isBackendUnavailable || _errorMessage != null)
            Positioned.fill(
              child: Container(
                color: _kBg.withValues(alpha: 0.75),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _isBackendUnavailable
                        ? ServerUnavailableStateView(onRetry: _retry)
                        : ErrorStateView(
                            title: 'Carte indisponible',
                            message: _errorMessage!,
                            onRetry: _retry,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Pulse painter ────────────────────────────────────────────

class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _PulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    const ringCount = 3;
    const maxRadius = 40.0;

    for (var i = 0; i < ringCount; i++) {
      final phase = ((progress - i / ringCount) % 1.0 + 1.0) % 1.0;
      final radius = phase * maxRadius;
      final opacity = (1.0 - phase) * 0.35;
      if (opacity <= 0) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.progress != progress;
}
