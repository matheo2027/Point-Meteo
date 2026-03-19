import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import 'package:geolocator/geolocator.dart';

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

  Future<void> _geolocaliserEtChercher() async {
    setState(() => _isLoading = true);

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

      setState(() {
        _cityController.text = response['ville'];
      });

      _rechercherLeMeilleur();
    } catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = e.toString().contains("TimeOutException")
          ? "Le GPS ne répond pas. Fixez une position dans l'émulateur."
          : "Géolocalisation impossible : $e";

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  }

  void _rechercherLeMeilleur() async {
    if (_cityController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final city = await _weatherService.searchCity(_cityController.text);
      final scores = await _weatherService.getScores(city['id']);
      final weather = await _weatherService.getWeather(city['id']);

      // Variables pour la source gagnante
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

      // --- NOUVEAUTÉ : On va chercher le Heure par Heure de la source gagnante ! ---
      double lat = double.parse(city['coords']['latitude'].toString());
      double lon = double.parse(city['coords']['longitude'].toString());
      final hourly = await _weatherService.getHourlyWeather(lat, lon, gagnant);

      // On met à jour l'écran avec TOUT
      setState(() {
        _bestSourceName = gagnant;
        _hourlyForecast = hourly; // On stocke les 24h

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

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erreur: $e");
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
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _rechercherLeMeilleur,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _rechercherLeMeilleur(),
                ),

                const SizedBox(height: 30),

                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white),

                if (_bestWeather != null && !_isLoading) ...[
                  // Bloc Principal
                  Icon(
                    _getWeatherIcon(weatherCode),
                    size: 80,
                    color: _getWeatherIconColor(weatherCode),
                  ),
                  Text(
                    "${_bestWeather!['temp']}°C",
                    style: const TextStyle(
                      fontSize: 70,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _bestSourceName!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- LA NOUVELLE TIMELINE HEURE PAR HEURE ---
                  if (_hourlyForecast.isNotEmpty)
                    SizedBox(
                      height: 130, // Hauteur de la bande
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _hourlyForecast.length,
                        itemBuilder: (context, index) {
                          final hourData = _hourlyForecast[index];
                          final code = hourData['code_meteo'] ?? 0;

                          return Container(
                            width: 80, // Largeur de chaque carte
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                          );
                        },
                      ),
                    ),

                  const Spacer(),
                  const Text(
                    "Source sélectionnée pour sa fiabilité élevée",
                    style: TextStyle(
                      color: Colors.white60,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (!_isLoading)
                  const Expanded(
                    child: Center(
                      child: Text("Entrez une ville ou utilisez le GPS"),
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
