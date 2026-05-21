import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/weather_service.dart';
import '../widgets/state_views.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final WeatherService _weatherService = WeatherService();
  final Map<String, List<dynamic>> _forecastCache = {};
  final TextEditingController _citySearchController = TextEditingController();

  final List<String> _providers = const [
    'Open-Meteo',
    'WeatherAPI',
    'Meteo-Concept',
  ];

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
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _initializeMap();
  }

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

  String _cacheKeyFor(LatLng center, String provider) {
    return '$provider|${center.latitude.toStringAsFixed(4)}|${center.longitude.toStringAsFixed(4)}';
  }

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
    if (weatherCode == 0) return Icons.wb_sunny;
    if (weatherCode == 1 || weatherCode == 2) return Icons.cloud_queue;
    if (weatherCode == 3) return Icons.cloud;
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.umbrella;
    if (weatherCode >= 95 && weatherCode <= 99) return Icons.flash_on;
    return Icons.wb_cloudy;
  }

  Color _getWeatherIconColor(int weatherCode) {
    if (weatherCode == 0) return Colors.orangeAccent;
    if (weatherCode == 1 || weatherCode == 2) return Colors.white;
    if (weatherCode >= 51 && weatherCode <= 67) return Colors.lightBlueAccent;
    if (weatherCode >= 71 && weatherCode <= 77) return Colors.white;
    if (weatherCode >= 95 && weatherCode <= 99) return Colors.yellowAccent;
    return Colors.white70;
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
      final dateTime = DateTime.parse(timeValue.replaceFirst(' ', 'T'));
      final hour = dateTime.hour.toString().padLeft(2, '0');
      return '$hour:00';
    } catch (_) {
      if (timeValue.length >= 16) {
        return timeValue.substring(11, 16);
      }
      return timeValue;
    }
  }

  String _formatSelectedTitle(String timeValue) {
    try {
      final dateTime = DateTime.parse(timeValue.replaceFirst(' ', 'T'));
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} • ${dateTime.hour.toString().padLeft(2, '0')}:00';
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
        final dateTime = DateTime.parse(timeValue.replaceFirst(' ', 'T'));
        if (!dateTime.isBefore(now)) {
          return i;
        }
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
      if (mounted) {
        setState(() {
          _isSearchingCity = false;
        });
      }
    }
  }

  Future<List<dynamic>> _loadForecast(LatLng center) async {
    final cacheKey = _cacheKeyFor(center, _selectedProvider);
    final cached = _forecastCache[cacheKey];
    if (cached != null) return cached;

    setState(() {
      _isFetchingForecast = true;
    });

    try {
      final forecast = await _weatherService.getHourlyWeather(
        center.latitude,
        center.longitude,
        _selectedProvider,
      );
      _forecastCache[cacheKey] = forecast;
      return forecast;
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingForecast = false;
        });
      }
    }
  }

  void _registerRecentCity(String city) {
    final normalized = city.trim();
    if (normalized.isEmpty) return;

    _recentCities.removeWhere(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    _recentCities.insert(0, normalized);
    if (_recentCities.length > 5) {
      _recentCities.removeLast();
    }
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
    }
  }

  Future<void> _onProviderChanged(String? provider) async {
    if (provider == null || provider == _selectedProvider) return;
    setState(() {
      _selectedProvider = provider;
    });
    await _reloadForecast();
  }

  Future<void> _retry() async {
    if (_center == null) {
      await _initializeMap();
      return;
    }
    await _reloadForecast();
  }

  Widget _buildMapMarker(Map<String, dynamic> hourData) {
    final code = _asInt(hourData['weathercode'] ?? hourData['code_meteo']);
    final temp = hourData['temp']?.toString() ?? '--';

    return Semantics(
      label: 'Repère météo ${_describeWeatherCode(code)}, $temp degrés',
      image: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getWeatherIcon(code),
                    color: _getWeatherIconColor(code),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$temp°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ExcludeSemantics(
            child: Icon(Icons.location_pin, color: Colors.redAccent, size: 42),
          ),
        ],
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Contrôles',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isControlsExpanded = !_isControlsExpanded;
                  });
                },
                icon: Icon(
                  _isControlsExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
                tooltip: _isControlsExpanded ? 'Réduire' : 'Déployer',
              ),
            ],
          ),
          if (_isControlsExpanded) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _citySearchController,
              enabled: !_isSearchingCity && !_isInitializing,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchCity(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une ville',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _isSearchingCity
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _searchCity,
                        icon: const Icon(Icons.arrow_forward),
                        color: Colors.white,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    dropdownColor: Colors.grey.shade900,
                    decoration: InputDecoration(
                      labelText: 'Provider',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: _providers
                        .map(
                          (provider) => DropdownMenuItem<String>(
                            value: provider,
                            child: Text(provider),
                          ),
                        )
                        .toList(),
                    onChanged: _isFetchingForecast ? null : _onProviderChanged,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _isFetchingForecast ? null : _reloadForecast,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _isInitializing ? null : _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _isInitializing ? null : _initializeMap,
                  icon: const Icon(Icons.gps_fixed),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _cityName == null
                  ? 'Position actuelle'
                  : 'Position actuelle • $_cityName',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_recentCities.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _recentCities
                      .map(
                        (city) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(city),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.10,
                            ),
                            labelStyle: const TextStyle(color: Colors.white),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            onPressed: () {
                              _citySearchController.text = city;
                              _searchCity();
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (_favoriteCities.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _favoriteCities
                      .map(
                        (city) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: const Icon(Icons.favorite, size: 16),
                            backgroundColor: Colors.pink.withValues(
                              alpha: 0.22,
                            ),
                            side: BorderSide(
                              color: Colors.pinkAccent.withValues(alpha: 0.35),
                            ),
                            onPressed: () {
                              _citySearchController.text = city;
                              _searchCity();
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _center == null
                  ? 'Chargement de la carte...'
                  : '${_center!.latitude.toStringAsFixed(4)}, ${_center!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomOverlay() {
    final selectedHour = _selectedHourData();
    final canSlide = _hourlyForecast.length > 1;
    final selectedTime = selectedHour == null
        ? '--'
        : _formatSelectedTitle(selectedHour['time']?.toString() ?? '--');
    final code = selectedHour == null
        ? 0
        : _asInt(selectedHour['weathercode'] ?? selectedHour['code_meteo']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _getWeatherIcon(code),
                color: _getWeatherIconColor(code),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selectedHour != null)
                Text(
                  '${selectedHour['temp']}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isTimelineExpanded = !_isTimelineExpanded;
                  });
                },
                icon: Icon(
                  _isTimelineExpanded ? Icons.expand_more : Icons.expand_less,
                  color: Colors.white,
                ),
                tooltip: _isTimelineExpanded ? 'Réduire' : 'Déployer',
              ),
            ],
          ),
          if (_isTimelineExpanded) ...[
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.lightBlueAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.lightBlueAccent.withValues(alpha: 0.18),
                trackHeight: 4,
              ),
              child: Slider(
                value: _hourlyForecast.isEmpty
                    ? 0
                    : _selectedHourIndex.toDouble(),
                min: 0,
                max: _hourlyForecast.isEmpty
                    ? 0
                    : (_hourlyForecast.length - 1).toDouble(),
                divisions: canSlide ? _hourlyForecast.length - 1 : null,
                label: selectedTime,
                onChanged: _hourlyForecast.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedHourIndex = value.round();
                        });
                      },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _hourlyForecast.isNotEmpty
                      ? _formatHourLabel(
                          _hourlyForecast.first['time']?.toString() ?? '--',
                        )
                      : '--',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _hourlyForecast.isNotEmpty
                      ? _formatHourLabel(
                          _hourlyForecast.last['time']?.toString() ?? '--',
                        )
                      : '--',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Carte interactive')),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [Colors.blueGrey.shade900, Colors.black]
                    : [Colors.blue.shade900, Colors.blue.shade300],
              ),
            ),
          ),
          if (_center != null)
            FlutterMap(
              key: ValueKey(
                '${_center!.latitude.toStringAsFixed(4)}_${_center!.longitude.toStringAsFixed(4)}',
              ),
              options: MapOptions(initialCenter: _center!, initialZoom: 12.8),
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
                        height: 110,
                        child: _buildMapMarker(_selectedHourData()!),
                      ),
                    ],
                  ),
              ],
            )
          else
            const SizedBox.expand(),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _buildTopOverlay(),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _buildBottomOverlay(),
              ),
            ),
          ),
          if (_isInitializing)
            Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Semantics(
                    label: 'Chargement de la carte',
                    liveRegion: true,
                    child: ExcludeSemantics(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
          if (_isFetchingForecast && !_isInitializing)
            Positioned(
              top: 92,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Semantics(
                    label: 'Mise à jour des données en cours',
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mise à jour des données...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isBackendUnavailable || _errorMessage != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
