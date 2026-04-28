import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class CityNotFoundException implements Exception {
  final String cityName;
  CityNotFoundException(this.cityName);

  @override
  String toString() => 'Ville introuvable: $cityName';
}

class BackendUnavailableException implements Exception {
  final String message;

  BackendUnavailableException([
    this.message =
        'Le serveur météo est indisponible pour le moment. Réessaie dans quelques instants.',
  ]);

  @override
  String toString() => message;
}

class WeatherService {
  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<http.Response> _get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode >= 500) {
        throw BackendUnavailableException();
      }
      return response;
    } on TimeoutException catch (_) {
      throw BackendUnavailableException();
    } on http.ClientException catch (_) {
      throw BackendUnavailableException();
    } catch (_) {
      throw BackendUnavailableException();
    }
  }

  String get baseUrl {
    return 'https://point-meteo.onrender.com';
  }

  static int? lastCityId;
  static String? lastCityName;

  Future<Map<String, dynamic>> searchByCoords(double lat, double lon) async {
    final String urlString = '$baseUrl/search-coords?lat=$lat&lon=$lon';
    try {
      final response = await _get(
        Uri.parse(urlString),
        timeout: const Duration(seconds: 5),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ON MÉMORISE L'ID
        lastCityId = _asInt(data['id']);
        lastCityName = data['ville'];
        return data;
      }
      throw Exception('Erreur géoloc');
    } on BackendUnavailableException {
      rethrow;
    } catch (e) {
      throw Exception('Erreur réseau');
    }
  }

  Future<Map<String, dynamic>> searchCity(String cityName) async {
    final response = await _get(
      Uri.parse('$baseUrl/search/${Uri.encodeComponent(cityName)}'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // ON MÉMORISE L'ID
      lastCityId = _asInt(data['id']);
      lastCityName = data['ville'];
      return data;
    } else if (response.statusCode == 404) {
      throw CityNotFoundException(cityName);
    } else {
      throw Exception('Erreur recherche');
    }
  }

  Future<List<dynamic>> getWeather(int villeId) async {
    final response = await _get(Uri.parse('$baseUrl/weather/$villeId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur recuperation meteo');
  }

  Future<List<dynamic>> getScores(int villeId) async {
    final response = await _get(Uri.parse('$baseUrl/scores/$villeId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur recuperation scores');
  }

  Future<List<dynamic>> getGlobalScores() async {
    final response = await _get(Uri.parse('$baseUrl/scores/global'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur recuperation scores globaux');
  }

  Future<List<dynamic>> getHourlyWeather(
    double lat,
    double lon,
    String source,
  ) async {
    final response = await _get(
      Uri.parse('$baseUrl/hourly?lat=$lat&lon=$lon&source=$source'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération des données horaires');
    }
  }

  Future<Map<String, dynamic>> getProviderKpi(String source) async {
    final encodedSource = Uri.encodeComponent(source);
    final response = await _get(
      Uri.parse('$baseUrl/provider-kpi/$encodedSource'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur recuperation KPI provider');
  }

  Future<Map<String, dynamic>> getRainfallStudy(int villeId) async {
    final response = await _get(
      Uri.parse('$baseUrl/rainfall-study/$villeId'),
      timeout: const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur recuperation etude pluie');
  }
}
