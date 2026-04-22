import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CityNotFoundException implements Exception {
  final String cityName;
  CityNotFoundException(this.cityName);

  @override
  String toString() => 'Ville introuvable: $cityName';
}

class WeatherService {
  String get baseUrl {
    const overrideUrl = String.fromEnvironment('API_BASE_URL');
    if (overrideUrl.isNotEmpty) return overrideUrl;

    if (kIsWeb) return 'http://localhost:3000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://localhost:3000';
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000';
    }
  }

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
    final response = await http.get(
      Uri.parse('$baseUrl/search/${Uri.encodeComponent(cityName)}'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // ON MÉMORISE L'ID
      lastCityId = data['id'];
      lastCityName = data['ville'];
      return data;
    } else if (response.statusCode == 404) {
      throw CityNotFoundException(cityName);
    } else {
      throw Exception('Erreur recherche');
    }
  }

  Future<List<dynamic>> getWeather(int villeId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/weather/$villeId'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur recuperation meteo');
  }

  Future<List<dynamic>> getScores(int villeId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/scores/$villeId'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur recuperation scores');
  }

  Future<List<dynamic>> getGlobalScores() async {
    final response = await http
        .get(Uri.parse('$baseUrl/scores/global'))
        .timeout(const Duration(seconds: 8));
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
    final response = await http
        .get(Uri.parse('$baseUrl/hourly?lat=$lat&lon=$lon&source=$source'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération des données horaires');
    }
  }

  Future<Map<String, dynamic>> getProviderKpi(String source) async {
    final encodedSource = Uri.encodeComponent(source);
    final response = await http
        .get(Uri.parse('$baseUrl/provider-kpi/$encodedSource'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur recuperation KPI provider');
  }

  Future<Map<String, dynamic>> getRainfallStudy(int villeId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/rainfall-study/$villeId'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur recuperation etude pluie');
  }
}
