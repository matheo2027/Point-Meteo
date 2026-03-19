import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _cityController = TextEditingController();
  final WeatherService _weatherService = WeatherService();

  bool _isLoading = false;
  Map<String, dynamic>? _bestWeather;
  String? _bestSourceName;

  List<dynamic> _hourlyForecast = [];
  List<dynamic> _dailyForecast = [];

  bool _isFavorite = false;
  List<String> _favoriteCities = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteCities = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final cityName = _cityController.text.trim();

    if (cityName.isEmpty) return;

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
  }

  Future<void> _removeFavoriteFromList(String city) async {
    final prefs = await SharedPreferences.getInstance();
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

  void _clearSearch() {
    setState(() {
      _cityController.clear();
      _bestWeather = null;
      _isFavorite = false;
    });
  }

  Future<void> _geolocaliserEtChercher() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception("Permissions refusées");
      }

      if (permission == LocationPermission.deniedForever)
        throw Exception("Permissions bloquées définitivement");

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

      setState(() {
        _cityController.text = response['ville'];
      });

      _rechercherLeMeilleur();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Géolocalisation impossible : $e")),
      );
    }
  }

  void _rechercherLeMeilleur() async {
    if (_cityController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final city = await _weatherService.searchCity(_cityController.text);
      final scores = await _weatherService.getScores(city['id']);
      final weather = await _weatherService.getWeather(city['id']);

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

      setState(() {
        _bestSourceName = gagnant;
        _hourlyForecast = hourly;

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
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erreur: $e");
    }
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
    if (weatherCode >= 51 && weatherCode <= 67) return Colors.lightBlueAccent;
    if (weatherCode >= 71 && weatherCode <= 77) return Colors.white;
    if (weatherCode >= 95 && weatherCode <= 99) return Colors.yellowAccent;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    int weatherCode = 0;
    if (_bestWeather != null) {
      weatherCode =
          _bestWeather!['weathercode'] ?? _bestWeather!['code_meteo'] ?? 0;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _bestWeather != null
                ? [Colors.blue.shade900, Colors.blue.shade400]
                : [Colors.grey.shade300, Colors.grey.shade100],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // --- BARRE DE RECHERCHE ---
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
                    hintText: "Rechercher une ville...",
                    prefixIcon: IconButton(
                      icon: const Icon(
                        Icons.my_location,
                        color: Colors.blueAccent,
                      ),
                      onPressed: _geolocaliserEtChercher,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_bestWeather != null)
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: _clearSearch,
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Colors.blueAccent,
                          ),
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
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                // --- MÉTÉO DE LA VILLE ---
                if (_bestWeather != null && !_isLoading)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          // ANIMATION ICONE
                          Icon(
                                _getWeatherIcon(weatherCode),
                                size: 100,
                                color: _getWeatherIconColor(weatherCode),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(curve: Curves.easeOutBack),

                          // ANIMATION VILLE + COEUR
                          Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _cityController.text.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _isFavorite
                                          ? Colors.redAccent
                                          : Colors.white,
                                    ),
                                    onPressed: _toggleFavorite,
                                  ),
                                ],
                              )
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .slideY(begin: 0.2, curve: Curves.easeOut),

                          // ANIMATION TEMPERATURE
                          Text(
                                "${_bestWeather!['temp']}°C",
                                style: const TextStyle(
                                  fontSize: 70,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideY(begin: 0.2, curve: Curves.easeOut),

                          Text(
                            _bestSourceName!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(delay: 400.ms),

                          const SizedBox(height: 30),

                          // --- TIMELINE HEURE PAR HEURE ---
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
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 130,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _hourlyForecast.length,
                                itemBuilder: (context, index) {
                                  final hourData = _hourlyForecast[index];
                                  final code = hourData['code_meteo'] ?? 0;
                                  return Container(
                                        width: 80,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              hourData['time'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Icon(
                                              _getWeatherIcon(code),
                                              color: _getWeatherIconColor(code),
                                              size: 30,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              "${hourData['temp']}°C",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      // ANIMATION EN CASCADE HORIZONTALE
                                      .animate()
                                      .fadeIn(delay: (500 + (index * 50)).ms)
                                      .slideX(
                                        begin: 0.5,
                                        curve: Curves.easeOut,
                                      );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 30),

                          // --- LISTE DES PROCHAINS JOURS ---
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
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: _dailyForecast
                                    .map((dayData) {
                                      int dCode = dayData['code_meteo'] ?? 0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                _formatDate(
                                                  dayData['date_concernee']
                                                      .toString(),
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _getWeatherIcon(dCode),
                                              color: _getWeatherIconColor(
                                                dCode,
                                              ),
                                              size: 28,
                                            ),
                                            SizedBox(
                                              width: 50,
                                              child: Text(
                                                "${dayData['temp']}°C",
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList()
                                    // ANIMATION EN CASCADE VERTICALE
                                    .animate(interval: 100.ms)
                                    .fadeIn(delay: 800.ms)
                                    .slideY(begin: 0.2, curve: Curves.easeOut),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  )
                // --- LISTE DES FAVORIS ---
                else if (!_isLoading)
                  Expanded(
                    child: _favoriteCities.isEmpty
                        ? const Center(
                            child: Text(
                              "Entrez une ville pour commencer\nou utilisez le GPS",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                              ),
                            ),
                          ).animate().fadeIn()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                child: Text(
                                  "Vos villes favorites",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ).animate().fadeIn(),
                              Expanded(
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _favoriteCities.length,
                                  itemBuilder: (context, index) {
                                    final city = _favoriteCities[index];
                                    return Card(
                                          color: Colors.white,
                                          elevation: 2,
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 5,
                                                ),
                                            leading: const Icon(
                                              Icons.star,
                                              color: Colors.orangeAccent,
                                              size: 30,
                                            ),
                                            title: Text(
                                              city.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () =>
                                                  _removeFavoriteFromList(city),
                                            ),
                                            onTap: () {
                                              _cityController.text = city;
                                              _rechercherLeMeilleur();
                                            },
                                          ),
                                        )
                                        // ANIMATION DES FAVORIS AU DEMARRAGE
                                        .animate()
                                        .fadeIn(delay: (index * 100).ms)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
