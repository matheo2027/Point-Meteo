import 'package:home_widget/home_widget.dart';

class FavoriteWeatherWidgetService {
  static const String androidProviderName =
      'com.example.point_meteo_app.FavoriteWeatherWidgetProvider';

  static const String widgetSourceModeKey = 'favorite_widget_source_mode';
  static const String widgetSourceFavorite = 'favorite';
  static const String widgetSourceLocation = 'location';

  static const String cityKey = 'favorite_widget_city';
  static const String tempKey = 'favorite_widget_temp';
  static const String sourceKey = 'favorite_widget_source';
  static const String iconCodeKey = 'favorite_widget_icon_code';
  static const String updatedAtKey = 'favorite_widget_updated_at';

  static const String locationCityKey = 'location_widget_city';
  static const String locationTempKey = 'location_widget_temp';
  static const String locationSourceKey = 'location_widget_source';
  static const String locationIconCodeKey = 'location_widget_icon_code';
  static const String locationUpdatedAtKey = 'location_widget_updated_at';

  static Future<void> setWidgetSourceMode(String sourceMode) async {
    await HomeWidget.saveWidgetData<String>(widgetSourceModeKey, sourceMode);
    await HomeWidget.updateWidget(qualifiedAndroidName: androidProviderName);
  }

  static Future<String> getWidgetSourceMode() async {
    final mode = await HomeWidget.getWidgetData<String>(widgetSourceModeKey);
    return mode?.toString() ?? widgetSourceFavorite;
  }

  static Future<void> saveFavoriteSnapshot({
    required String cityName,
    required String displayTemp,
    required int weatherCode,
    required String sourceName,
    required String updatedAtLabel,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(cityKey, cityName),
      HomeWidget.saveWidgetData<String>(tempKey, displayTemp),
      HomeWidget.saveWidgetData<String>(sourceKey, sourceName),
      HomeWidget.saveWidgetData<String>(iconCodeKey, weatherCode.toString()),
      HomeWidget.saveWidgetData<String>(updatedAtKey, updatedAtLabel),
      HomeWidget.updateWidget(qualifiedAndroidName: androidProviderName),
    ]);
  }

  static Future<void> saveLocationSnapshot({
    required String cityName,
    required String displayTemp,
    required int weatherCode,
    required String sourceName,
    required String updatedAtLabel,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(locationCityKey, cityName),
      HomeWidget.saveWidgetData<String>(locationTempKey, displayTemp),
      HomeWidget.saveWidgetData<String>(locationSourceKey, sourceName),
      HomeWidget.saveWidgetData<String>(
        locationIconCodeKey,
        weatherCode.toString(),
      ),
      HomeWidget.saveWidgetData<String>(locationUpdatedAtKey, updatedAtLabel),
      HomeWidget.updateWidget(qualifiedAndroidName: androidProviderName),
    ]);
  }

  static Future<void> clearSnapshotIfCurrentCity(String cityName) async {
    final storedCity = await HomeWidget.getWidgetData<String>(cityKey);
    if (storedCity != cityName) {
      return;
    }

    await Future.wait([
      HomeWidget.saveWidgetData<String>(cityKey, null),
      HomeWidget.saveWidgetData<String>(tempKey, null),
      HomeWidget.saveWidgetData<String>(sourceKey, null),
      HomeWidget.saveWidgetData<String>(iconCodeKey, null),
      HomeWidget.saveWidgetData<String>(updatedAtKey, null),
      HomeWidget.updateWidget(qualifiedAndroidName: androidProviderName),
    ]);
  }

  static Future<void> clearLocationSnapshot() async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(locationCityKey, null),
      HomeWidget.saveWidgetData<String>(locationTempKey, null),
      HomeWidget.saveWidgetData<String>(locationSourceKey, null),
      HomeWidget.saveWidgetData<String>(locationIconCodeKey, null),
      HomeWidget.saveWidgetData<String>(locationUpdatedAtKey, null),
      HomeWidget.updateWidget(qualifiedAndroidName: androidProviderName),
    ]);
  }

  static Future<void> clearSnapshot() async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(cityKey, null),
      HomeWidget.saveWidgetData<String>(tempKey, null),
      HomeWidget.saveWidgetData<String>(sourceKey, null),
      HomeWidget.saveWidgetData<String>(iconCodeKey, null),
      HomeWidget.saveWidgetData<String>(updatedAtKey, null),
      HomeWidget.saveWidgetData<String>(locationCityKey, null),
      HomeWidget.saveWidgetData<String>(locationTempKey, null),
      HomeWidget.saveWidgetData<String>(locationSourceKey, null),
      HomeWidget.saveWidgetData<String>(locationIconCodeKey, null),
      HomeWidget.saveWidgetData<String>(locationUpdatedAtKey, null),
      HomeWidget.saveWidgetData<String>(widgetSourceModeKey, null),
      HomeWidget.updateWidget(qualifiedAndroidName: androidProviderName),
    ]);
  }
}
