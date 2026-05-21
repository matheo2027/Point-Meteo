import WidgetKit
import SwiftUI

struct WeatherEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let temperature: String
    let weatherEmoji: String
    let sourceName: String
    let updatedAt: String
}

struct PointMeteoProvider: TimelineProvider {
    private let appGroupId = "group.com.example.pointmeteo"

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(
            date: Date(),
            cityName: "Paris",
            temperature: "18°C",
            weatherEmoji: "⛅",
            sourceName: "Point Météo",
            updatedAt: "MAJ 12:00"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let nextUpdate = Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [buildEntry()], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func buildEntry() -> WeatherEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let sourceMode = defaults?.string(forKey: "favorite_widget_source_mode") ?? "favorite"
        let isLocation = sourceMode == "location"

        let cityKey     = isLocation ? "location_widget_city"       : "favorite_widget_city"
        let tempKey     = isLocation ? "location_widget_temp"        : "favorite_widget_temp"
        let sourceKey   = isLocation ? "location_widget_source"      : "favorite_widget_source"
        let iconKey     = isLocation ? "location_widget_icon_code"   : "favorite_widget_icon_code"
        let updatedKey  = isLocation ? "location_widget_updated_at"  : "favorite_widget_updated_at"

        let defaultCity = isLocation ? "Ma localisation" : "Ville favorite"
        let cityName    = defaults?.string(forKey: cityKey)    ?? defaultCity
        let temperature = defaults?.string(forKey: tempKey)    ?? "--°C"
        let sourceName  = defaults?.string(forKey: sourceKey)  ?? "Point Météo"
        let updatedAt   = defaults?.string(forKey: updatedKey) ?? "Ouvre l'app pour rafraîchir"
        let code        = Int(defaults?.string(forKey: iconKey) ?? "") ?? -1

        return WeatherEntry(
            date: Date(),
            cityName: cityName,
            temperature: temperature,
            weatherEmoji: weatherEmoji(for: code),
            sourceName: sourceName,
            updatedAt: updatedAt
        )
    }

    private func weatherEmoji(for code: Int) -> String {
        switch code {
        case 0:       return "☀️"
        case 1, 2:    return "⛅"
        case 3:       return "☁️"
        case 45, 48:  return "🌫️"
        case 51...67: return "🌧️"
        case 71...77: return "❄️"
        case 80...82: return "🌦️"
        case 95...99: return "⛈️"
        default:      return "🌤️"
        }
    }
}

struct PointMeteoWidgetEntryView: View {
    var entry: PointMeteoProvider.Entry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.35, blue: 0.75),
                    Color(red: 0.12, green: 0.22, blue: 0.55),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.cityName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 10) {
                    Text(entry.weatherEmoji)
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.temperature)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text(entry.sourceName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.87, green: 0.90, blue: 1.0))
                    }
                }

                Spacer()

                Text(entry.updatedAt)
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.72, green: 0.78, blue: 1.0))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.cityName), \(entry.temperature), \(entry.sourceName), mis à jour \(entry.updatedAt)")
    }
}

struct PointMeteoWidget: Widget {
    let kind: String = "PointMeteoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PointMeteoProvider()) { entry in
            PointMeteoWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Point Météo")
        .description("Météo de votre ville favorite ou de votre position actuelle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
