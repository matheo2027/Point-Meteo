import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/favorite_weather_widget_service.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  String _widgetSourceMode = FavoriteWeatherWidgetService.widgetSourceFavorite;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _widgetSourceMode =
          prefs.getString(FavoriteWeatherWidgetService.widgetSourceModeKey) ??
          FavoriteWeatherWidgetService.widgetSourceFavorite;
    });
  }

  Future<void> _setWidgetSourceMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _widgetSourceMode = value;
    });
    await prefs.setString(
      FavoriteWeatherWidgetService.widgetSourceModeKey,
      value,
    );
    await FavoriteWeatherWidgetService.setWidgetSourceMode(value);
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
    });
    await prefs.setBool('isDarkMode', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _toggleUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !isCelsiusNotifier.value;
    isCelsiusNotifier.value = newValue;
    await prefs.setBool('isCelsius', newValue);
  }

  Future<void> _toggleTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !is24HourNotifier.value;
    is24HourNotifier.value = newValue;
    await prefs.setBool('is24Hour', newValue);
  }

  Future<void> _resetApp() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Réinitialiser l'application ?"),
          content: const Text(
            "Cela effacera vos favoris et remettra les paramètres par défaut. Action irréversible.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                await FavoriteWeatherWidgetService.clearSnapshot();

                setState(() {
                  _isDarkMode = false;
                });
                themeNotifier.value = ThemeMode.light;
                isCelsiusNotifier.value = true;
                is24HourNotifier.value = true;

                HomeScreen.forceResetNotifier.value =
                    !HomeScreen.forceResetNotifier.value;

                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Application remise à zéro 🧹"),
                    ),
                  );
                }
              },
              child: const Text(
                "Réinitialiser",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHowItWorksDialog() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber),
              SizedBox(width: 10),
              Text("Le concept & Sources", style: TextStyle(fontSize: 18)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Point Météo croise les données pour vous offrir la meilleure prévision.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),
                Text("1️⃣ L'application interroge 3 sources :"),
                Text(
                  "   • Open-Meteo\n   • WeatherAPI\n   • Meteo-Concept",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "2️⃣ Notre algorithme Python compare leurs prévisions passées avec la réalité.",
                ),
                SizedBox(height: 10),
                Text(
                  "3️⃣ Vous voyez uniquement les données du fournisseur le plus fiable pour la ville demandée !",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "J'ai compris",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Paramètres",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
            child: Text(
              "PRÉFÉRENCES",
              style: TextStyle(
                color: isDark ? Colors.blueAccent : Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: isCelsiusNotifier,
            builder: (context, isCelsius, _) {
              return ListTile(
                leading: const Icon(Icons.thermostat),
                title: const Text("Unité de température"),
                trailing: Text(
                  isCelsius ? "Celsius (°C)" : "Fahrenheit (°F)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                onTap: _toggleUnit,
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: is24HourNotifier,
            builder: (context, is24Hour, _) {
              return ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text("Format de l'heure"),
                trailing: Text(
                  is24Hour ? "24h (14:00)" : "12h (2:00 PM)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                onTap: _toggleTimeFormat,
              );
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text("Mode Sombre"),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeThumbColor: Colors.blueAccent,
          ),

          const Divider(height: 40),

          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 10),
            child: Text(
              "WIDGET",
              style: TextStyle(
                color: isDark ? Colors.blueAccent : Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: _widgetSourceMode,
              decoration: const InputDecoration(
                labelText: "Source du widget",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: FavoriteWeatherWidgetService.widgetSourceFavorite,
                  child: Row(
                    children: [
                      Icon(Icons.favorite, size: 18),
                      SizedBox(width: 10),
                      Text("Ville favorite"),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: FavoriteWeatherWidgetService.widgetSourceLocation,
                  child: Row(
                    children: [
                      Icon(Icons.my_location, size: 18),
                      SizedBox(width: 10),
                      Text("Ma localisation"),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _setWidgetSourceMode(value);
                }
              },
            ),
          ),

          const Divider(height: 40),

          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 10),
            child: Text(
              "À PROPOS",
              style: TextStyle(
                color: isDark ? Colors.blueAccent : Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.amber),
            title: const Text("Comment ça marche ?"),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showHowItWorksDialog,
          ),

          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Version de l'application"),
            subtitle: Text("1.0.0 (Projet de Soutenance)"),
          ),

          const Divider(height: 40),

          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 10),
            child: Text(
              "ZONE DE DANGER",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              "Réinitialiser l'application",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: _resetApp,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
