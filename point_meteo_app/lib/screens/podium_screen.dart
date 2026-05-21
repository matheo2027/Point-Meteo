import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../widgets/state_views.dart';
import 'provider_kpi_screen.dart';

class PodiumScreen extends StatefulWidget {
  const PodiumScreen({super.key});

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen> {
  final WeatherService _service = WeatherService();
  bool _isGlobalMode = false;
  late Future<List<dynamic>> _scoresFuture;

  @override
  void initState() {
    super.initState();
    _scoresFuture = _loadScores();
  }

  void _refreshScores() {
    _scoresFuture = _loadScores();
  }

  Future<List<dynamic>> _loadScores() {
    if (_isGlobalMode) {
      return _service.getGlobalScores();
    }

    final int? cityId = WeatherService.lastCityId;
    if (cityId == null) {
      return Future.value([]);
    }

    return _service.getScores(cityId);
  }

  double _extractScore(Map<String, dynamic> row) {
    final dynamic raw = _isGlobalMode
        ? (row['score_moyen'] ?? row['score_fiabilite'])
        : (row['score_fiabilite'] ?? row['score_moyen']);
    return double.tryParse(raw.toString()) ?? 0;
  }

  double _extractTrendDelta(Map<String, dynamic> row) {
    final dynamic raw = row['trend_delta'];
    return double.tryParse(raw.toString()) ?? 0;
  }

  IconData _trendIcon(double delta) {
    if (delta > 0.1) return Icons.north_east;
    if (delta < -0.1) return Icons.south_east;
    return Icons.trending_flat;
  }

  Color _trendColor(double delta) {
    if (delta > 0.1) return Colors.green;
    if (delta < -0.1) return Colors.red;
    return Colors.grey;
  }

  String _trendDescription(double delta) {
    if (delta > 0.1) return 'amélioration';
    if (delta < -0.1) return 'dégradation';
    return 'stable';
  }

  @override
  Widget build(BuildContext context) {
    final String cityName =
        WeatherService.lastCityName ?? 'Ville non sélectionnée';
    final String modeTitle = _isGlobalMode
        ? 'Scores Nationaux/Globaux'
        : 'Scores pour $cityName';
    final bool hasSelectedCity = WeatherService.lastCityId != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Podium de Fiabilité")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          modeTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isGlobalMode,
                        onChanged: (value) {
                          setState(() {
                            _isGlobalMode = value;
                            _refreshScores();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isGlobalMode
                      ? 'Mode global: moyenne des scores sur toutes les villes.'
                      : 'Mode ville: score de la derniere ville recherchee.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _scoresFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingSkeletonView(itemCount: 4);
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final bool backendDown = error is BackendUnavailableException;
                  if (backendDown) {
                    return ServerUnavailableStateView(
                      onRetry: () => setState(_refreshScores),
                    );
                  }
                  return ErrorStateView(
                    title: 'Erreur de chargement',
                    message: 'Impossible de récupérer les scores.',
                    onRetry: () => setState(_refreshScores),
                  );
                }

                if (!_isGlobalMode && !hasSelectedCity) {
                  return const Center(
                    child: Text(
                      'Aucune ville sélectionnée.\nFais une recherche météo puis reviens ici.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text("Aucune donnée d'analyse disponible"),
                  );
                }

                final scores = List<dynamic>.from(snapshot.data!);
                scores.sort((a, b) {
                  final scoreB = _extractScore(Map<String, dynamic>.from(b));
                  final scoreA = _extractScore(Map<String, dynamic>.from(a));
                  return scoreB.compareTo(scoreA);
                });

                return ListView.builder(
                  itemCount: scores.length,
                  itemBuilder: (context, index) {
                    final s = Map<String, dynamic>.from(scores[index]);
                    final score = _extractScore(s);
                    final trendDelta = _extractTrendDelta(s);
                    final trendColor = _trendColor(trendDelta);
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: Semantics(
                          label: 'Position ${index + 1} au classement',
                          child: CircleAvatar(child: ExcludeSemantics(child: Text("${index + 1}"))),
                        ),
                        title: Semantics(
                          label: 'Fournisseur : ${s['source']}',
                          child: Text(s['source'].toString()),
                        ),
                        subtitle: Semantics(
                          label:
                              'Score ${score.toStringAsFixed(1)} pour cent, ${_trendDescription(trendDelta)} de ${trendDelta.toStringAsFixed(1)}',
                          value: '${score.toStringAsFixed(1)} pour cent',
                          child: ExcludeSemantics(
                            child: LinearProgressIndicator(
                              value: (score / 100).clamp(0.0, 1.0),
                              color: Colors.green,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: 'Score de fiabilité : ${score.toStringAsFixed(1)} pour cent',
                              child: ExcludeSemantics(
                                child: Text(
                                  "${score.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              label:
                                  'Tendance ${_trendDescription(trendDelta)}',
                              child: ExcludeSemantics(
                                child: Icon(
                                  _trendIcon(trendDelta),
                                  color: trendColor,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "${trendDelta >= 0 ? '+' : ''}${trendDelta.toStringAsFixed(1)}",
                              style: TextStyle(
                                color: trendColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProviderKpiScreen(
                                providerName: s['source'].toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
