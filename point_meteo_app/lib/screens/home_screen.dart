import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../services/favorite_weather_widget_service.dart';
import 'search_not_found_screen.dart';
import '../widgets/state_views.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static final ValueNotifier<bool> forceResetNotifier = ValueNotifier(false);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _cityController = TextEditingController();
  final WeatherService _weatherService = WeatherService();
  late final VoidCallback _forceResetListener;

  bool _isLoading = false;
  Map<String, dynamic>? _bestWeather;
  String? _bestSourceName;

  List<dynamic> _hourlyForecast = [];
  List<dynamic> _dailyForecast = [];
  List<Map<String, dynamic>> _apiComparisonRows = [];
  bool _showAllApiRows = false;
  String? _notFoundQuery;
  String? _homeErrorMessage;
  bool _isBackendUnavailable = false;

  bool _isFavorite = false;
  List<String> _favoriteCities = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _forceResetListener = () {
      if (!mounted) return;
      setState(() {
        _favoriteCities.clear();
        _isFavorite = false;
        _bestWeather = null;
        _cityController.clear();
        _notFoundQuery = null;
        _homeErrorMessage = null;
        _isBackendUnavailable = false;
        _apiComparisonRows = [];
        _showAllApiRows = false;
      });
    };

    HomeScreen.forceResetNotifier.addListener(_forceResetListener);
  }

  @override
  void dispose() {
    HomeScreen.forceResetNotifier.removeListener(_forceResetListener);
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoriteCities = prefs.getStringList('favorites') ?? [];
    });
  }

  String _buildUpdatedAtLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return 'MAJ $hour:$minute';
  }

  Future<void> _syncFavoriteWidgetSnapshot() async {
    final cityName = _cityController.text.trim();
    if (cityName.isEmpty || _bestWeather == null || _bestSourceName == null) {
      return;
    }

    final rawTemp = _hourlyForecast.isNotEmpty
        ? _hourlyForecast[0]['temp']
        : _bestWeather!['temp'];
    final tempValue = _convertTemp(rawTemp, isCelsiusNotifier.value);
    final unit = isCelsiusNotifier.value ? 'C' : 'F';
    final displayTemp = '$tempValue°$unit';
    final weatherCode = _asInt(
      _bestWeather!['weathercode'] ?? _bestWeather!['code_meteo'],
    );

    await FavoriteWeatherWidgetService.saveFavoriteSnapshot(
      cityName: cityName,
      displayTemp: displayTemp,
      weatherCode: weatherCode,
      sourceName: _bestSourceName!,
      updatedAtLabel: _buildUpdatedAtLabel(),
    );
  }

  Future<void> _syncLocationWidgetSnapshot() async {
    final cityName = _cityController.text.trim();
    if (cityName.isEmpty || _bestWeather == null || _bestSourceName == null) {
      return;
    }

    final rawTemp = _hourlyForecast.isNotEmpty
        ? _hourlyForecast[0]['temp']
        : _bestWeather!['temp'];
    final tempValue = _convertTemp(rawTemp, isCelsiusNotifier.value);
    final unit = isCelsiusNotifier.value ? 'C' : 'F';
    final displayTemp = '$tempValue°$unit';
    final weatherCode = _asInt(
      _bestWeather!['weathercode'] ?? _bestWeather!['code_meteo'],
    );

    await FavoriteWeatherWidgetService.saveLocationSnapshot(
      cityName: cityName,
      displayTemp: displayTemp,
      weatherCode: weatherCode,
      sourceName: _bestSourceName!,
      updatedAtLabel: _buildUpdatedAtLabel(),
    );
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final cityName = _cityController.text.trim();

    if (cityName.isEmpty) return;

    final willBeFavorite = !_favoriteCities.contains(cityName);

    setState(() {
      if (_favoriteCities.contains(cityName)) {
        _favoriteCities.remove(cityName);
        _isFavorite = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$cityName retiré des favoris")));
      } else {
        _favoriteCities.add(cityName);
        _isFavorite = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$cityName ajouté aux favoris ❤️")),
        );
      }
    });
    await prefs.setStringList('favorites', _favoriteCities);

    if (willBeFavorite) {
      await _syncFavoriteWidgetSnapshot();
    } else {
      await FavoriteWeatherWidgetService.clearSnapshotIfCurrentCity(cityName);
    }
  }

  Future<void> _removeFavoriteFromList(String city) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoriteCities.remove(city);
      if (_cityController.text == city) _isFavorite = false;
    });
    await prefs.setStringList('favorites', _favoriteCities);
  }

  void _checkIfFavorite(String cityName) {
    setState(() {
      _isFavorite = _favoriteCities.contains(cityName);
    });
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _clearSearch() {
    setState(() {
      _cityController.clear();
      _bestWeather = null;
      _isFavorite = false;
      _notFoundQuery = null;
      _homeErrorMessage = null;
      _isBackendUnavailable = false;
      _apiComparisonRows = [];
      _showAllApiRows = false;
    });
  }

  Future<void> _geolocaliserEtChercher() async {
    setState(() {
      _isLoading = true;
      _homeErrorMessage = null;
      _isBackendUnavailable = false;
      _notFoundQuery = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permissions refusées");
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Permissions bloquées définitivement");
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final response = await _weatherService.searchByCoords(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _cityController.text = response['ville'];
      });
      _rechercherLeMeilleur(
        widgetSnapshotMode: FavoriteWeatherWidgetService.widgetSourceLocation,
      );
    } catch (e) {
      if (!mounted) return;
      if (e is BackendUnavailableException) {
        setState(() {
          _isLoading = false;
          _isBackendUnavailable = true;
          _homeErrorMessage = null;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _homeErrorMessage = "Géolocalisation impossible : $e";
      });
    }
  }

  Future<void> _rechercherLeMeilleur({String? widgetSnapshotMode}) async {
    if (_cityController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _notFoundQuery = null;
      _homeErrorMessage = null;
      _isBackendUnavailable = false;
    });

    try {
      final city = await _weatherService.searchCity(_cityController.text);
      final int cityId = _asInt(city['id']);
      final scores = await _weatherService.getScores(cityId);
      final weather = await _weatherService.getWeather(cityId);

      String gagnant;
      if (scores.isNotEmpty) {
        var bestSource = scores.reduce(
          (a, b) =>
              (double.parse(a['score_fiabilite'].toString()) >
                  double.parse(b['score_fiabilite'].toString()))
              ? a
              : b,
        );
        gagnant = bestSource['source'];
      } else {
        gagnant = weather.isNotEmpty ? weather[0]['source'] : "Aucune donnée";
      }

      double lat = double.parse(city['coords']['latitude'].toString());
      double lon = double.parse(city['coords']['longitude'].toString());
      final hourly = await _weatherService.getHourlyWeather(lat, lon, gagnant);

      if (!mounted) return;

      setState(() {
        _bestSourceName = gagnant;
        _hourlyForecast = hourly;
        _notFoundQuery = null;
        _homeErrorMessage = null;
        _isBackendUnavailable = false;

        Map<String, dynamic> uniqueDays = {};
        for (var w in weather) {
          if (w['source'] == _bestSourceName) {
            String date = w['date_concernee'].toString().substring(0, 10);
            if (!uniqueDays.containsKey(date)) {
              uniqueDays[date] = w;
            }
          }
        }

        _dailyForecast = uniqueDays.values.toList();
        _dailyForecast.sort(
          (a, b) => a['date_concernee'].compareTo(b['date_concernee']),
        );

        final Map<String, Map<String, dynamic>> byDate = {};
        for (final item in weather) {
          if (item['type'] != 'prevision') continue;
          final String source = item['source'].toString();
          if (!['Open-Meteo', 'WeatherAPI', 'Meteo-Concept'].contains(source)) {
            continue;
          }

          final String date = item['date_concernee'].toString().substring(
            0,
            10,
          );
          byDate.putIfAbsent(date, () => {'date': date});
          byDate[date]![source] = item;
        }

        _apiComparisonRows = byDate.values.toList()
          ..sort(
            (a, b) => a['date'].toString().compareTo(b['date'].toString()),
          );
        _showAllApiRows = false;

        String todayStr = DateTime.now().toString().substring(0, 10);
        _bestWeather = weather.firstWhere(
          (w) =>
              w['source'] == _bestSourceName &&
              w['date_concernee'].toString().contains(todayStr),
          orElse: () => weather.firstWhere(
            (w) => w['source'] == _bestSourceName,
            orElse: () => null,
          ),
        );

        _checkIfFavorite(city['ville']);
        _cityController.text = city['ville'];
        _isLoading = false;
      });

      if (widgetSnapshotMode ==
          FavoriteWeatherWidgetService.widgetSourceLocation) {
        await _syncLocationWidgetSnapshot();
      } else if (_isFavorite) {
        await _syncFavoriteWidgetSnapshot();
      }
    } catch (e) {
      if (!mounted) return;
      if (e is CityNotFoundException) {
        setState(() {
          _isLoading = false;
          _notFoundQuery = e.cityName;
          _bestWeather = null;
          _bestSourceName = null;
          _hourlyForecast = [];
          _dailyForecast = [];
          _apiComparisonRows = [];
          _showAllApiRows = false;
          _isFavorite = false;
        });
        return;
      }

      if (e is BackendUnavailableException) {
        setState(() {
          _isLoading = false;
          _isBackendUnavailable = true;
          _homeErrorMessage = null;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _homeErrorMessage = "Erreur de recherche : $e";
      });
    }
  }

  int _convertTemp(dynamic tempC, bool isCelsius) {
    double c = double.parse(tempC.toString());
    if (isCelsius) return c.round();
    return ((c * 9 / 5) + 32).round();
  }

  String _formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      List<String> jours = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];
      String nomJour = jours[date.weekday - 1];
      return "$nomJour ${date.day}/${date.month}";
    } catch (e) {
      return dateStr.substring(5, 10);
    }
  }

  IconData _getWeatherIcon(int weatherCode, {bool isNight = false}) {
    if (weatherCode == 0) {
      return isNight ? Icons.nightlight_round : Icons.wb_sunny;
    }
    if (weatherCode == 1 || weatherCode == 2) {
      return isNight ? Icons.nights_stay : Icons.cloud_queue;
    }
    if (weatherCode == 3) return Icons.cloud;
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.umbrella;
    if (weatherCode >= 95 && weatherCode <= 99) return Icons.flash_on;
    return Icons.wb_cloudy;
  }

  String _describeWeatherCode(int weatherCode, {bool isNight = false}) {
    if (weatherCode == 0) {
      return isNight ? 'ciel dégagé la nuit' : 'ensoleillé';
    }
    if (weatherCode == 1 || weatherCode == 2) {
      return isNight ? 'nuages et éclaircies la nuit' : 'partiellement nuageux';
    }
    if (weatherCode == 3) return 'nuageux';
    if (weatherCode == 45 || weatherCode == 48) return 'brouillard';
    if (weatherCode >= 51 && weatherCode <= 67) return 'pluie';
    if (weatherCode >= 71 && weatherCode <= 77) return 'neige';
    if (weatherCode >= 80 && weatherCode <= 82) return 'averses';
    if (weatherCode >= 95 && weatherCode <= 99) return 'orage';
    return 'conditions météo inconnues';
  }

  Color _getWeatherIconColor(int weatherCode, {bool isNight = false}) {
    if (weatherCode == 0) {
      return isNight ? Colors.indigo.shade200 : Colors.orangeAccent;
    }
    if (weatherCode == 1 || weatherCode == 2) {
      return isNight ? Colors.indigo.shade200 : Colors.white;
    }
    if (weatherCode >= 51 && weatherCode <= 67) return Colors.lightBlueAccent;
    if (weatherCode >= 71 && weatherCode <= 77) return Colors.white;
    if (weatherCode >= 95 && weatherCode <= 99) return Colors.yellowAccent;
    return Colors.white70;
  }

  double? _getTempTrendNext3Hours() {
    if (_hourlyForecast.length < 2) return null;

    final int targetIndex = _hourlyForecast.length > 3
        ? 3
        : _hourlyForecast.length - 1;

    final double startTemp =
        double.tryParse(_hourlyForecast[0]['temp'].toString()) ?? 0;
    final double targetTemp =
        double.tryParse(_hourlyForecast[targetIndex]['temp'].toString()) ?? 0;

    return targetTemp - startTemp;
  }

  IconData _getTrendIcon(double delta) {
    if (delta > 0.1) return Icons.north_east;
    if (delta < -0.1) return Icons.south_east;
    return Icons.trending_flat;
  }

  String _describeTrend(double delta, bool isCelsius) {
    final formattedDelta = _formatTrendDelta(delta, isCelsius);
    if (delta > 0.1) return 'température en hausse de $formattedDelta';
    if (delta < -0.1) return 'température en baisse de $formattedDelta';
    return 'température stable sur les 3 prochaines heures';
  }

  Color _getTrendColor(double delta) {
    if (delta > 0.1) return Colors.greenAccent;
    if (delta < -0.1) return Colors.redAccent;
    return Colors.white70;
  }

  String _formatTrendDelta(double delta, bool isCelsius) {
    final double displayDelta = isCelsius ? delta : (delta * 9 / 5);
    final String sign = displayDelta > 0 ? '+' : '';
    final String unit = isCelsius ? 'C' : 'F';
    return '$sign${displayDelta.toStringAsFixed(1)}°$unit';
  }

  String _formatComparisonTemp(
    Map<String, dynamic>? dayBySource,
    String source,
    bool isCelsius,
    String unit,
  ) {
    final item = dayBySource?[source];
    if (item == null) return '--';
    final value = _convertTemp(item['temp'], isCelsius);
    return '$value°$unit';
  }

  void _showHowItWorksDialog() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber),
              SizedBox(width: 10),
              Text("Le concept & Sources", style: TextStyle(fontSize: 18)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Point Météo croise les données pour vous offrir la meilleure prévision.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),
                Text("1️⃣ L'application interroge 3 sources :"),
                Text(
                  "   • Open-Meteo\n   • WeatherAPI\n   • Meteo-Concept",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "2️⃣ Notre algorithme Python compare leurs prévisions passées avec la réalité.",
                ),
                SizedBox(height: 10),
                Text(
                  "3️⃣ Vous voyez uniquement les données du fournisseur le plus fiable pour la ville demandée !",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "J'ai compris",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    bool isDark = Theme.of(context).brightness == Brightness.dark;

    int weatherCode = 0;
    if (_bestWeather != null) {
      weatherCode = _asInt(
        _bestWeather!['weathercode'] ?? _bestWeather!['code_meteo'],
      );
    }

    int currentHour = DateTime.now().hour;
    bool isCurrentlyNight = currentHour >= 20 || currentHour <= 5;

    return ValueListenableBuilder<bool>(
      valueListenable: is24HourNotifier,
      builder: (context, is24Hour, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isCelsiusNotifier,
          builder: (context, isCelsius, _) {
            String unit = isCelsius ? "C" : "F";

            String formatTime(String timeStr) {
              if (is24Hour) return timeStr;
              try {
                int h = int.parse(timeStr.substring(0, 2));
                String m = timeStr.substring(3, 5);
                String p = h >= 12 ? "PM" : "AM";
                int displayH = h % 12;
                if (displayH == 0) displayH = 12;
                return "$displayH:$m $p";
              } catch (_) {
                return timeStr;
              }
            }

            return Scaffold(
              body: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _bestWeather != null
                        ? (isDark
                              ? [Colors.blueGrey.shade900, Colors.black]
                              : [Colors.blue.shade900, Colors.blue.shade400])
                        : (isDark
                              ? [Colors.grey.shade900, Colors.black]
                              : [Colors.grey.shade300, Colors.grey.shade100]),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _cityController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.9),
                            hintText: "Rechercher une ville...",
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            prefixIcon: Semantics(
                              label: 'Rechercher la météo pour ma position actuelle',
                              button: true,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.my_location,
                                  color: Colors.blueAccent,
                                ),
                                tooltip: 'Ma position',
                                onPressed: _geolocaliserEtChercher,
                              ),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_bestWeather != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey,
                                    ),
                                    tooltip: 'Effacer la recherche',
                                    onPressed: _clearSearch,
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.search,
                                    color: Colors.blueAccent,
                                  ),
                                  tooltip: 'Rechercher',
                                  onPressed: _rechercherLeMeilleur,
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _rechercherLeMeilleur(),
                        ),

                        const SizedBox(height: 20),

                        if (_isLoading)
                          const Expanded(
                            child: LoadingSkeletonView(itemCount: 4),
                          ),

                        if (_bestWeather != null && !_isLoading)
                          Expanded(
                            child: RefreshIndicator(
                              color: Colors.blueAccent,
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.white,
                              onRefresh: () async {
                                await _rechercherLeMeilleur();
                              },
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    Semantics(
                                          label:
                                              'Icône météo: ${_describeWeatherCode(weatherCode, isNight: isCurrentlyNight)}',
                                          image: true,
                                          child: ExcludeSemantics(
                                            child: Icon(
                                              _getWeatherIcon(
                                                weatherCode,
                                                isNight: isCurrentlyNight,
                                              ),
                                              size: 100,
                                              color: _getWeatherIconColor(
                                                weatherCode,
                                                isNight: isCurrentlyNight,
                                              ),
                                            ),
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(duration: 600.ms)
                                        .scale(curve: Curves.easeOutBack),

                                    Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.location_on,
                                                    size: 18,
                                                    color: Colors.white70,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      _cityController.text
                                                          .toUpperCase(),
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 1.2,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Semantics(
                                                    label: _isFavorite
                                                        ? 'Retirer des favoris'
                                                        : 'Ajouter aux favoris',
                                                    button: true,
                                                    child: IconButton(
                                                      constraints:
                                                          const BoxConstraints(),
                                                      padding:
                                                          const EdgeInsets.all(4),
                                                      icon: Icon(
                                                        _isFavorite
                                                            ? Icons.favorite
                                                            : Icons
                                                                  .favorite_border,
                                                        color: _isFavorite
                                                            ? Colors.redAccent
                                                            : Colors.white,
                                                        size: 22,
                                                      ),
                                                      tooltip: _isFavorite
                                                          ? 'Retirer des favoris'
                                                          : 'Ajouter aux favoris',
                                                      onPressed: _toggleFavorite,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Semantics(
                                                label: 'Température actuelle : ${_convertTemp(_hourlyForecast.isNotEmpty ? _hourlyForecast[0]['temp'] : _bestWeather!['temp'], isCelsius)} degrés $unit',
                                                child: ExcludeSemantics(
                                                  child: Text(
                                                    "${_convertTemp(_hourlyForecast.isNotEmpty ? _hourlyForecast[0]['temp'] : _bestWeather!['temp'], isCelsius)}°$unit",
                                                    style: const TextStyle(
                                                      fontSize: 74,
                                                      fontWeight: FontWeight.w900,
                                                      height: 0.95,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Semantics(
                                                label: 'Source météo la plus fiable : $_bestSourceName',
                                                child: ExcludeSemantics(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.14),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      _bestSourceName!
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white70,
                                                        letterSpacing: 1.8,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(delay: 220.ms)
                                        .slideY(begin: 0.15),

                                    const SizedBox(height: 30),

                                    if (_hourlyForecast.isNotEmpty) ...[
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Heure par Heure",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ).animate().fadeIn(delay: 500.ms),
                                      Builder(
                                        builder: (context) {
                                          final double? trend3h =
                                              _getTempTrendNext3Hours();
                                          if (trend3h == null) {
                                            return const SizedBox.shrink();
                                          }

                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Semantics(
                                                    label: _describeTrend(
                                                      trend3h,
                                                      isCelsius,
                                                    ),
                                                    image: true,
                                                    child: ExcludeSemantics(
                                                      child: Icon(
                                                        _getTrendIcon(trend3h),
                                                        color: _getTrendColor(
                                                          trend3h,
                                                        ),
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Tendance 3h: ${_formatTrendDelta(trend3h, isCelsius)}',
                                                    style: TextStyle(
                                                      color: _getTrendColor(
                                                        trend3h,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ).animate().fadeIn(delay: 520.ms);
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 130,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _hourlyForecast.length,
                                          itemBuilder: (context, index) {
                                            final hourData =
                                                _hourlyForecast[index];
                                            final code = _asInt(
                                              hourData['weathercode'] ??
                                                  hourData['code_meteo'],
                                            );

                                            int h = 12;
                                            try {
                                              h = int.parse(
                                                hourData['time'].substring(
                                                  0,
                                                  2,
                                                ),
                                              );
                                            } catch (_) {}
                                            bool isNightHour =
                                                h >= 20 || h <= 5;

                                            return Container(
                                                  width: 80,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        formatTime(
                                                          hourData['time'],
                                                        ),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Semantics(
                                                        label:
                                                            'Prévision horaire: ${_describeWeatherCode(code, isNight: isNightHour)} à ${formatTime(hourData['time'])}',
                                                        image: true,
                                                        child: ExcludeSemantics(
                                                          child: Icon(
                                                            _getWeatherIcon(
                                                              code,
                                                              isNight:
                                                                  isNightHour,
                                                            ),
                                                            color:
                                                                _getWeatherIconColor(
                                                                  code,
                                                                  isNight:
                                                                      isNightHour,
                                                                ),
                                                            size: 30,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Semantics(
                                                        label: 'Température prévue : ${_convertTemp(hourData['temp'], isCelsius)} degrés $unit',
                                                        child: ExcludeSemantics(
                                                          child: Text(
                                                            "${_convertTemp(hourData['temp'], isCelsius)}°$unit",
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                                .animate()
                                                .fadeIn(
                                                  delay:
                                                      (500 + (index * 50)).ms,
                                                )
                                                .slideX(
                                                  begin: 0.5,
                                                  curve: Curves.easeOut,
                                                );
                                          },
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 30),

                                    if (_dailyForecast.isNotEmpty) ...[
                                      const Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Prochains jours",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ).animate().fadeIn(delay: 700.ms),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Column(
                                          children: _dailyForecast
                                              .map((dayData) {
                                                final dCode = _asInt(
                                                  dayData['weathercode'] ??
                                                      dayData['code_meteo'],
                                                );
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12.0,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      SizedBox(
                                                        width: 80,
                                                        child: Text(
                                                          _formatDate(
                                                            dayData['date_concernee']
                                                                .toString(),
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ),
                                                      Semantics(
                                                        label:
                                                            'Prévision journalière: ${_describeWeatherCode(dCode)} pour ${_formatDate(dayData['date_concernee'].toString())}',
                                                        image: true,
                                                        child: ExcludeSemantics(
                                                          child: Icon(
                                                            _getWeatherIcon(
                                                              dCode,
                                                              isNight: false,
                                                            ),
                                                            color:
                                                                _getWeatherIconColor(
                                                                  dCode,
                                                                  isNight:
                                                                      false,
                                                                ),
                                                            size: 28,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 50,
                                                        child: Text(
                                                          "${_convertTemp(dayData['temp'], isCelsius)}°$unit",
                                                          textAlign:
                                                              TextAlign.right,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              })
                                              .toList()
                                              .animate(interval: 100.ms)
                                              .fadeIn(delay: 800.ms)
                                              .slideY(
                                                begin: 0.2,
                                                curve: Curves.easeOut,
                                              ),
                                        ),
                                      ),
                                    ],

                                    if (_apiComparisonRows.isNotEmpty) ...[
                                      const SizedBox(height: 26),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Comparatif des APIs',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _showAllApiRows =
                                                    !_showAllApiRows;
                                              });
                                            },
                                            child: Text(
                                              _showAllApiRows
                                                  ? 'View less'
                                                  : 'View all',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ).animate().fadeIn(delay: 860.ms),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingTextStyle: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            dataTextStyle: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            columns: const [
                                              DataColumn(label: Text('Date')),
                                              DataColumn(
                                                label: Text('Open-Meteo'),
                                              ),
                                              DataColumn(
                                                label: Text('WeatherAPI'),
                                              ),
                                              DataColumn(
                                                label: Text('Meteo-Concept'),
                                              ),
                                            ],
                                            rows:
                                                (_showAllApiRows
                                                        ? _apiComparisonRows
                                                        : _apiComparisonRows
                                                              .take(3))
                                                    .map((day) {
                                                      return DataRow(
                                                        cells: [
                                                          DataCell(
                                                            Text(
                                                              _formatDate(
                                                                day['date']
                                                                    .toString(),
                                                              ),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              _formatComparisonTemp(
                                                                day,
                                                                'Open-Meteo',
                                                                isCelsius,
                                                                unit,
                                                              ),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              _formatComparisonTemp(
                                                                day,
                                                                'WeatherAPI',
                                                                isCelsius,
                                                                unit,
                                                              ),
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Text(
                                                              _formatComparisonTemp(
                                                                day,
                                                                'Meteo-Concept',
                                                                isCelsius,
                                                                unit,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    })
                                                    .toList(),
                                          ),
                                        ),
                                      ).animate().fadeIn(delay: 900.ms),
                                    ],
                                    const SizedBox(height: 20),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "Source sélectionnée pour sa fiabilité",
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.info_outline,
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                          onPressed: _showHowItWorksDialog,
                                        ),
                                      ],
                                    ).animate().fadeIn(delay: 1000.ms),

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (!_isLoading && _notFoundQuery != null)
                          Expanded(
                            child: SearchNotFoundScreen(
                              query: _notFoundQuery!,
                              onTryAgain: _rechercherLeMeilleur,
                            ),
                          )
                        else if (!_isLoading && _isBackendUnavailable)
                          Expanded(
                            child: ServerUnavailableStateView(
                              onRetry: _cityController.text.trim().isNotEmpty
                                  ? _rechercherLeMeilleur
                                  : _geolocaliserEtChercher,
                            ),
                          )
                        else if (!_isLoading && _homeErrorMessage != null)
                          Expanded(
                            child: ErrorStateView(
                              title: 'Erreur',
                              message: _homeErrorMessage!,
                              onRetry: _cityController.text.trim().isNotEmpty
                                  ? _rechercherLeMeilleur
                                  : _geolocaliserEtChercher,
                            ),
                          )
                        else if (!_isLoading)
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: RefreshIndicator(
                                    color: Colors.blueAccent,
                                    backgroundColor: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    onRefresh: () async {
                                      await _loadFavorites();
                                    },
                                    child: _favoriteCities.isEmpty
                                        ? ListView(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(
                                                  parent:
                                                      BouncingScrollPhysics(),
                                                ),
                                            children: [
                                              SizedBox(
                                                height:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.3,
                                              ),
                                              Center(
                                                child: Text(
                                                  "Entrez une ville pour commencer\nou utilisez le GPS",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ).animate().fadeIn(),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 15,
                                                    ),
                                                child: Text(
                                                  "Vos villes favorites",
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ).animate().fadeIn(),
                                              Expanded(
                                                child: ListView.builder(
                                                  physics:
                                                      const AlwaysScrollableScrollPhysics(
                                                        parent:
                                                            BouncingScrollPhysics(),
                                                      ),
                                                  itemCount:
                                                      _favoriteCities.length,
                                                  itemBuilder: (context, index) {
                                                    final city =
                                                        _favoriteCities[index];
                                                    return Card(
                                                          color: Colors
                                                              .transparent,
                                                          elevation: 2,
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 12,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  15,
                                                                ),
                                                          ),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                                colors: isDark
                                                                    ? [
                                                                        Colors
                                                                            .blueGrey
                                                                            .shade800,
                                                                        Colors
                                                                            .blueGrey
                                                                            .shade900,
                                                                      ]
                                                                    : [
                                                                        Colors
                                                                            .blue
                                                                            .shade50,
                                                                        Colors
                                                                            .white,
                                                                      ],
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    15,
                                                                  ),
                                                              border: Border.all(
                                                                color: isDark
                                                                    ? Colors
                                                                          .white
                                                                          .withValues(
                                                                            alpha:
                                                                                0.08,
                                                                          )
                                                                    : Colors
                                                                          .blueGrey
                                                                          .withValues(
                                                                            alpha:
                                                                                0.12,
                                                                          ),
                                                              ),
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    15,
                                                                  ),
                                                              child: Stack(
                                                                children: [
                                                                  Positioned(
                                                                    right: -22,
                                                                    top: -18,
                                                                    child: Container(
                                                                      width: 74,
                                                                      height:
                                                                          74,
                                                                      decoration: BoxDecoration(
                                                                        shape: BoxShape
                                                                            .circle,
                                                                        color: Colors.white.withValues(
                                                                          alpha:
                                                                              isDark
                                                                              ? 0.05
                                                                              : 0.35,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Positioned(
                                                                    left: -12,
                                                                    bottom: -20,
                                                                    child: Container(
                                                                      width: 56,
                                                                      height:
                                                                          56,
                                                                      decoration: BoxDecoration(
                                                                        shape: BoxShape
                                                                            .circle,
                                                                        color: Colors.white.withValues(
                                                                          alpha:
                                                                              isDark
                                                                              ? 0.04
                                                                              : 0.25,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  ListTile(
                                                                    contentPadding:
                                                                        const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              20,
                                                                          vertical:
                                                                              5,
                                                                        ),
                                                                    leading: ExcludeSemantics(
                                                                      child: const Icon(
                                                                        Icons.star,
                                                                        color: Colors.orangeAccent,
                                                                        size: 30,
                                                                      ),
                                                                    ),
                                                                    title: Text(
                                                                      city.toUpperCase(),
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        fontSize:
                                                                            16,
                                                                        color:
                                                                            isDark
                                                                            ? Colors.white
                                                                            : Colors.black,
                                                                      ),
                                                                    ),
                                                                    trailing: IconButton(
                                                                      icon: Icon(
                                                                        Icons.delete_outline,
                                                                        color: isDark
                                                                            ? Colors.white54
                                                                            : Colors.grey,
                                                                      ),
                                                                      tooltip: 'Retirer $city des favoris',
                                                                      onPressed: () =>
                                                                          _removeFavoriteFromList(city),
                                                                    ),
                                                                    onTap: () {
                                                                      _cityController
                                                                              .text =
                                                                          city;
                                                                      _rechercherLeMeilleur();
                                                                    },
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .animate()
                                                        .fadeIn(
                                                          delay:
                                                              (index * 100).ms,
                                                        )
                                                        .slideX(
                                                          begin: -0.2,
                                                          curve: Curves.easeOut,
                                                        );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 5,
                                    bottom: 5,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Découvrez le fonctionnement de l'algorithme",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.info_outline,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.blueAccent,
                                          size: 20,
                                        ),
                                        onPressed: _showHowItWorksDialog,
                                      ),
                                    ],
                                  ).animate().fadeIn(delay: 500.ms),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
