import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/podium_screen.dart';
import 'screens/settings_screen.dart';

void main() => runApp(const PointMeteoApp());

class PointMeteoApp extends StatelessWidget {
  const PointMeteoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // On définit les pages une seule fois
  final List<Widget> _pages = [
    const HomeScreen(),
    const PodiumScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // On remplace "body: _pages[_currentIndex]" par IndexedStack
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.wb_sunny), label: "Météo"),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: "Podium",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
