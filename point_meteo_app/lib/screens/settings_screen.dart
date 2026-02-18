import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paramètres")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.thermostat),
            title: const Text("Unité de température"),
            trailing: const Text("Celsius (°C)"),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text("Mode Sombre"),
            value: false,
            onChanged: (bool value) {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Version de l'application"),
            subtitle: const Text("1.0.0"),
          ),
        ],
      ),
    );
  }
}
