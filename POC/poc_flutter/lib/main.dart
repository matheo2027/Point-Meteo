import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Mon Test Météo')),
        body: const MeteoPage(),
      ),
    );
  }
}

class MeteoPage extends StatefulWidget {
  const MeteoPage({super.key});

  @override
  State<MeteoPage> createState() => _MeteoPageState();
}

class _MeteoPageState extends State<MeteoPage> {
  String message = "Appuie pour tester la connexion";
  bool isLoading = false; // Pour afficher un petit rond de chargement

  Future<void> getData() async {
    setState(() {
      isLoading = true; // On commence le chargement
      message = "Connexion en cours...";
    });

    try {
      // ⚠️ 10.0.2.2 est l'adresse spéciale pour que l'émulateur
      // puisse parler à ton "localhost" sur le PC.
      var response = await Dio().get('http://10.0.2.2:3000/meteo');
      
      setState(() {
        // On récupère le score calculé par Python
        double score = response.data['score_moyen_A'];
        message = "✅ SUCCÈS !\nScore reçu du Python : $score";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        message = "❌ ERREUR :\nImpossible de joindre le serveur Node.\nVérifie qu'il est bien lancé !";
        isLoading = false;
      });
      print(e); // Affiche l'erreur dans la console pour débugger
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            isLoading
                ? const CircularProgressIndicator() // Rond qui tourne
                : ElevatedButton.icon(
                    onPressed: getData,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text("INTERROGER LE SERVEUR"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}