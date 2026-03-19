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

  Future<void> _geolocaliserEtChercher() async {
    setState(() => _isLoading = true);

    try {
      // 1. Vérifier les permissions
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

      // 2. Récupérer la position actuelle
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 3. Envoyer les coordonnées au Backend
      final response = await _weatherService.searchByCoords(
        position.latitude,
        position.longitude,
      );

      // 4. Mettre à jour l'UI avec la ville trouvée
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

      setState(() {
        if (scores.isNotEmpty) {
          var bestSource = scores.reduce(
            (a, b) =>
                (double.parse(a['score_fiabilite'].toString()) >
                    double.parse(b['score_fiabilite'].toString()))
                ? a
                : b,
          );
          _bestSourceName = bestSource['source'];
        } else {
          _bestSourceName = weather.isNotEmpty
              ? weather[0]['source']
              : "Aucune donnée";
        }

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

        print("MÉTÉO REÇUE POUR L'AFFICHAGE : $_bestWeather");
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erreur: $e");
    }
  }

  // Fonction qui traduit le code WMO en icône Flutter
  IconData _getWeatherIcon(int weatherCode) {
    if (weatherCode == 0) return Icons.wb_sunny;
    if (weatherCode == 1 || weatherCode == 2) return Icons.cloud_queue;
    if (weatherCode == 3) return Icons.cloud;
    if (weatherCode == 45 || weatherCode == 48) return Icons.foggy;
    if (weatherCode >= 51 && weatherCode <= 67) return Icons.water_drop;
    if (weatherCode >= 71 && weatherCode <= 77) return Icons.ac_unit;
    if (weatherCode >= 80 && weatherCode <= 82) return Icons.umbrella;
    if (weatherCode >= 95 && weatherCode <= 99) return Icons.flash_on;
    return Icons.wb_cloudy; // Par défaut
  }

  // Fonction pour donner une couleur sympa à l'icône selon la météo
  Color _getWeatherIconColor(int weatherCode) {
    if (weatherCode == 0) return Colors.orangeAccent; // Soleil
    if (weatherCode >= 51 && weatherCode <= 67)
      return Colors.lightBlueAccent; // Pluie
    if (weatherCode >= 71 && weatherCode <= 77) return Colors.white; // Neige
    if (weatherCode >= 95 && weatherCode <= 99)
      return Colors.yellowAccent; // Orage
    return Colors.white70; // Nuages/Gris par défaut
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Extraction du code météo (On gère les deux noms possibles de la BDD pour éviter un crash)
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
                    fillColor: Colors.white.withOpacity(0.9),
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
                const SizedBox(height: 60),
                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white),
                if (_bestWeather != null) ...[
                  // --- MODIFICATION ICI : L'ICÔNE DYNAMIQUE ---
                  Icon(
                    _getWeatherIcon(weatherCode),
                    size: 80,
                    color: _getWeatherIconColor(weatherCode),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "${_bestWeather!['temp']}°C",
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _bestSourceName!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Prévision pour le ${_bestWeather!['date_concernee'].toString().substring(0, 10)}",
                    style: const TextStyle(color: Colors.white54),
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
