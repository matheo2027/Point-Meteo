import 'package:flutter/material.dart';
import 'services/weather_service.dart';

void main() => runApp(const PointMeteoApp());

class PointMeteoApp extends StatelessWidget {
  const PointMeteoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Point Météo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cityController = TextEditingController();
  final WeatherService _weatherService = WeatherService();

  bool _isLoading = false;
  int? _villeId;
  String? _message;
  List<Map<String, dynamic>> _weatherList = [];
  List<dynamic> _scores = [];

  void _rechercherVille() async {
    if (_cityController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _message = null;
      _villeId = null;
    });

    try {
      final result = await _weatherService.searchCity(_cityController.text);
      final int id = result['id'];

      final weatherData = await _weatherService.getWeather(id);
      final scoresData = await _weatherService.getScores(id);

      // Regroupement des données par date pour éviter les doublons visuels
      Map<String, Map<String, dynamic>> grouped = {};
      for (var item in weatherData) {
        String date = item['date_concernee'].substring(0, 10);
        if (!grouped.containsKey(date)) {
          grouped[date] = {'date': date};
        }
        grouped[date]![item['source']] = item['temp'];
      }

      setState(() {
        _villeId = id;
        _scores = scoresData;
        _weatherList = grouped.values.toList();
        _weatherList.sort((a, b) => a['date'].compareTo(b['date']));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _message = "Erreur : Serveur injoignable";
        _isLoading = false;
      });
    }
  }

  // Nouveau Widget de badge pour une comparaison claire
  Widget _sourceBadge(String source, dynamic temp, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            source.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            temp != null ? "$temp°C" : "--",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String sourceName, Color color) {
    final sourceScore = _scores.firstWhere(
      (s) => s['source'] == sourceName,
      orElse: () => {'score_fiabilite': '0'},
    );

    double scoreValue =
        double.tryParse(sourceScore['score_fiabilite'].toString()) ?? 0;
    Color statusColor = scoreValue >= 80
        ? Colors.green
        : (scoreValue >= 60 ? Colors.orange : Colors.red);

    return Expanded(
      child: Card(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sourceName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "${scoreValue.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 26,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "FIABILITÉ",
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("POINT MÉTÉO"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: "Ville (ex: Lyon)",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _rechercherVille(),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const LinearProgressIndicator(),
            if (_message != null)
              Text(_message!, style: const TextStyle(color: Colors.red)),

            if (_villeId != null && !_isLoading) ...[
              Row(
                children: [
                  _buildScoreCard("Open-Meteo", Colors.blue),
                  _buildScoreCard("WeatherAPI", Colors.orange),
                ],
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "  COMPARAISON DES PRÉVISIONS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _weatherList.length,
                  itemBuilder: (context, index) {
                    final day = _weatherList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                day['date'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _sourceBadge(
                              "Open-Meteo",
                              day['Open-Meteo'],
                              Colors.blue,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "vs",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            _sourceBadge(
                              "WeatherAPI",
                              day['WeatherAPI'],
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
