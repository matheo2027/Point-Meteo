import 'dart:convert';

enum AlertType { rain, tempBelow, tempAbove, wind }

class AlertRule {
  final String id;
  final String cityName;
  final AlertType type;
  final double threshold;
  final int hoursAhead;
  bool isEnabled;

  AlertRule({
    required this.id,
    required this.cityName,
    required this.type,
    this.threshold = 0,
    this.hoursAhead = 3,
    this.isEnabled = true,
  });

  String get icon {
    switch (type) {
      case AlertType.rain:
        return '🌧️';
      case AlertType.tempBelow:
        return '🥶';
      case AlertType.tempAbove:
        return '🌡️';
      case AlertType.wind:
        return '💨';
    }
  }

  String get label {
    switch (type) {
      case AlertType.rain:
        return 'Pluie';
      case AlertType.tempBelow:
        return 'Température basse';
      case AlertType.tempAbove:
        return 'Température haute';
      case AlertType.wind:
        return 'Vent fort';
    }
  }

  String get description {
    switch (type) {
      case AlertType.rain:
        return 'Pluie prévue dans les ${hoursAhead}h';
      case AlertType.tempBelow:
        return 'Temp. sous ${threshold.toStringAsFixed(0)}°C';
      case AlertType.tempAbove:
        return 'Temp. au-dessus de ${threshold.toStringAsFixed(0)}°C';
      case AlertType.wind:
        return 'Vent > ${threshold.toStringAsFixed(0)} km/h';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cityName': cityName,
        'type': type.name,
        'threshold': threshold,
        'hoursAhead': hoursAhead,
        'isEnabled': isEnabled,
      };

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
        id: json['id'] as String,
        cityName: json['cityName'] as String,
        type: AlertType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AlertType.rain,
        ),
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
        hoursAhead: (json['hoursAhead'] as num?)?.toInt() ?? 3,
        isEnabled: json['isEnabled'] as bool? ?? true,
      );

  static List<AlertRule> listFromJson(String jsonStr) {
    final list = json.decode(jsonStr) as List;
    return list.map((e) => AlertRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<AlertRule> rules) =>
      json.encode(rules.map((r) => r.toJson()).toList());
}
