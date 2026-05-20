package com.example.point_meteo_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FavoriteWeatherWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val sourceMode = widgetData.getString(WIDGET_SOURCE_MODE_KEY, WIDGET_SOURCE_FAVORITE)

    appWidgetIds.forEach { widgetId ->
      val snapshot = if (sourceMode == WIDGET_SOURCE_LOCATION) {
        Snapshot(
            widgetData.getString(LOCATION_CITY_KEY, null),
            widgetData.getString(LOCATION_TEMP_KEY, null),
            widgetData.getString(LOCATION_SOURCE_KEY, null),
            widgetData.getString(LOCATION_WEATHER_CODE_KEY, null),
            widgetData.getString(LOCATION_UPDATED_AT_KEY, null),
            "Ma localisation",
        )
      } else {
        Snapshot(
            widgetData.getString(CITY_KEY, null),
            widgetData.getString(TEMP_KEY, null),
            widgetData.getString(SOURCE_KEY, null),
            widgetData.getString(WEATHER_CODE_KEY, null),
            widgetData.getString(UPDATED_AT_KEY, null),
            "Ville favorite",
        )
      }

      val cityName = snapshot.cityName ?: snapshot.defaultTitle
      val temperature = snapshot.temperature ?: "--°C"
      val source = snapshot.source ?: "Point Météo"
      val weatherCode = snapshot.weatherCode?.toIntOrNull() ?: -1
      val updatedAt = snapshot.updatedAt ?: "Ouvre l'application pour rafraîchir"

      val views =
          RemoteViews(context.packageName, R.layout.favorite_weather_widget).apply {
            setTextViewText(R.id.widget_city_name, cityName)
            setTextViewText(R.id.widget_temp, temperature)
            setTextViewText(R.id.widget_source, source)
            setTextViewText(R.id.widget_updated_at, updatedAt)
            setTextViewText(R.id.widget_icon, weatherEmoji(weatherCode))

            setTextColor(R.id.widget_city_name, Color.WHITE)
            setTextColor(R.id.widget_temp, Color.WHITE)
            setTextColor(R.id.widget_source, Color.parseColor("#DDE7FF"))
            setTextColor(R.id.widget_updated_at, Color.parseColor("#B7C7FF"))
            setTextColor(R.id.widget_icon, Color.WHITE)

            val openAppIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_container, openAppIntent)
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private fun weatherEmoji(code: Int): String {
    return when (code) {
      0 -> "☀"
      1, 2 -> "⛅"
      3 -> "☁"
      45, 48 -> "🌫"
      in 51..67 -> "🌧"
      in 71..77 -> "❄"
      in 80..82 -> "🌦"
      in 95..99 -> "⛈"
      else -> "🌤"
    }
  }

  private companion object {
    const val WIDGET_SOURCE_MODE_KEY = "favorite_widget_source_mode"
    const val WIDGET_SOURCE_FAVORITE = "favorite"
    const val WIDGET_SOURCE_LOCATION = "location"

    const val CITY_KEY = "favorite_widget_city"
    const val TEMP_KEY = "favorite_widget_temp"
    const val SOURCE_KEY = "favorite_widget_source"
    const val WEATHER_CODE_KEY = "favorite_widget_icon_code"
    const val UPDATED_AT_KEY = "favorite_widget_updated_at"

    const val LOCATION_CITY_KEY = "location_widget_city"
    const val LOCATION_TEMP_KEY = "location_widget_temp"
    const val LOCATION_SOURCE_KEY = "location_widget_source"
    const val LOCATION_WEATHER_CODE_KEY = "location_widget_icon_code"
    const val LOCATION_UPDATED_AT_KEY = "location_widget_updated_at"
  }
}

  private data class Snapshot(
    val cityName: String?,
    val temperature: String?,
    val source: String?,
    val weatherCode: String?,
    val updatedAt: String?,
    val defaultTitle: String,
  )
