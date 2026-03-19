class WeatherData {
  final String source;
  final double temp;
  final DateTime date;
  final String type;

  WeatherData({
    required this.source,
    required this.temp,
    required this.date,
    required this.type,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      source: json['source'] as String,
      temp: (json['temp'] as num).toDouble(),
      date: DateTime.parse(json['date_concernee']),
      type: json['type'] as String,
    );
  }
}
