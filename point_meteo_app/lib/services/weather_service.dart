import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Adresse IP spécifique pour l'émulateur Android vers ton PC
  final String baseUrl = "http://10.0.2.2:3000";

  Future<Map<String, dynamic>> searchCity(String cityName) async {
    final response = await http.get(Uri.parse('$baseUrl/search/$cityName'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur recherche');
    }
  }

  Future<List<dynamic>> getWeather(int villeId) async {
    final response = await http.get(Uri.parse('$baseUrl/weather/$villeId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getScores(int villeId) async {
    final response = await http.get(Uri.parse('$baseUrl/scores/$villeId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }
}
