import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String baseUrl = "http://10.0.2.2:3000";

  static int? lastCityId;
  static String? lastCityName;

  Future<Map<String, dynamic>> searchByCoords(double lat, double lon) async {
    final String urlString = '$baseUrl/search-coords?lat=$lat&lon=$lon';
    try {
      final response = await http
          .get(Uri.parse(urlString))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ON MÉMORISE L'ID
        lastCityId = data['id'];
        lastCityName = data['ville'];
        return data;
      }
      throw Exception('Erreur géoloc');
    } catch (e) {
      throw Exception('Erreur réseau');
    }
  }

  Future<Map<String, dynamic>> searchCity(String cityName) async {
    final response = await http.get(Uri.parse('$baseUrl/search/$cityName'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // ON MÉMORISE L'ID
      lastCityId = data['id'];
      lastCityName = data['ville'];
      return data;
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
