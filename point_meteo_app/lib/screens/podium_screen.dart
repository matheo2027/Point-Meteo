import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class PodiumScreen extends StatelessWidget {
  const PodiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final WeatherService service = WeatherService();

    return Scaffold(
      appBar: AppBar(title: const Text("Podium de Fiabilité")),
      body: FutureBuilder<List<dynamic>>(
        // Note: Pour l'exemple, on utilise l'ID 1 ou on pourrait passer l'ID de la dernière recherche
        future: service.getScores(1),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("Aucune donnée d'analyse disponible"),
            );
          }

          final scores = snapshot.data!;
          scores.sort(
            (a, b) => double.parse(
              b['score_fiabilite'].toString(),
            ).compareTo(double.parse(a['score_fiabilite'].toString())),
          );

          return ListView.builder(
            itemCount: scores.length,
            itemBuilder: (context, index) {
              final s = scores[index];
              final score = double.parse(s['score_fiabilite'].toString());
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: CircleAvatar(child: Text("${index + 1}")),
                  title: Text(s['source']),
                  subtitle: LinearProgressIndicator(
                    value: score / 100,
                    color: Colors.green,
                  ),
                  trailing: Text(
                    "${score.toStringAsFixed(1)}%",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
