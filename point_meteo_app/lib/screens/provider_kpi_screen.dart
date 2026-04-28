import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../widgets/state_views.dart';

class ProviderKpiScreen extends StatefulWidget {
  final String providerName;

  const ProviderKpiScreen({super.key, required this.providerName});

  @override
  State<ProviderKpiScreen> createState() => _ProviderKpiScreenState();
}

class _ProviderKpiScreenState extends State<ProviderKpiScreen> {
  final WeatherService _service = WeatherService();

  String _fmtNum(dynamic value, {int digits = 2, String fallback = '0.00'}) {
    if (value == null) return fallback;
    final n = double.tryParse(value.toString());
    if (n == null) return fallback;
    return n.toStringAsFixed(digits);
  }

  Widget _metricCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KPI ${widget.providerName}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _service.getProviderKpi(widget.providerName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingSkeletonView(itemCount: 6);
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final bool backendDown = error is BackendUnavailableException;
            return ErrorStateView(
              title: backendDown ? 'Serveur indisponible' : 'KPI indisponibles',
              message: backendDown
                  ? error.toString()
                  : 'Impossible de charger les KPI du provider.',
              onRetry: () => setState(() {}),
            );
          }

          if (!snapshot.hasData) {
            return const ErrorStateView(
              title: 'Aucune donnee',
              message: 'Aucun KPI disponible pour ce provider.',
            );
          }

          final data = snapshot.data!;
          final exactRate = _fmtNum(data['exact_rate']);
          final exactCount = data['exact_predictions']?.toString() ?? '0';
          final totalCompared = data['total_compared']?.toString() ?? '0';
          final confidence = data['confidence'] as Map<String, dynamic>? ?? {};
          final confidenceLabel = confidence['label']?.toString() ?? 'Faible';
          final confidenceScore = _fmtNum(
            confidence['score'],
            digits: 0,
            fallback: '0',
          );
          final confidenceThresholds =
              data['confidence_thresholds'] as Map<String, dynamic>? ?? {};
          final avgScore = _fmtNum(data['avg_reliability_score']);
          final mae = _fmtNum(data['mae']);
          final rmse = _fmtNum(data['rmse']);
          final cities = data['compared_cities']?.toString() ?? '0';
          final apiLatencyAvg = _fmtNum(
            data['api_latency_ms_avg'],
            digits: 1,
            fallback: 'N/A',
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.providerName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Indicateurs de performance sur les 120 derniers jours',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.28,
                  children: [
                    _metricCard(
                      title: 'Confiance statistique',
                      value: confidenceLabel,
                      icon: confidenceLabel == 'Elevee'
                          ? Icons.verified_user
                          : confidenceLabel == 'Moyenne'
                          ? Icons.rule_folder
                          : Icons.warning_amber_rounded,
                    ),
                    _metricCard(
                      title: 'Taux de previsions exactes',
                      value: '$exactRate%',
                      icon: Icons.verified,
                    ),
                    _metricCard(
                      title: 'Previsions exactes',
                      value: '$exactCount / $totalCompared',
                      icon: Icons.checklist,
                    ),
                    _metricCard(
                      title: 'Score fiabilite moyen',
                      value: '$avgScore%',
                      icon: Icons.stars,
                    ),
                    _metricCard(
                      title: 'MAE moyenne',
                      value: '$mae C',
                      icon: Icons.straighten,
                    ),
                    _metricCard(
                      title: 'RMSE',
                      value: '$rmse C',
                      icon: Icons.analytics,
                    ),
                    _metricCard(
                      title: 'Villes comparees',
                      value: cities,
                      icon: Icons.location_city,
                    ),
                    _metricCard(
                      title: 'Latence API moyenne',
                      value: apiLatencyAvg == 'N/A'
                          ? apiLatencyAvg
                          : '$apiLatencyAvg ms',
                      icon: Icons.timer,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: confidenceLabel == 'Elevee'
                        ? Colors.green.withValues(alpha: 0.12)
                        : confidenceLabel == 'Moyenne'
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: confidenceLabel == 'Elevee'
                          ? Colors.green.withValues(alpha: 0.5)
                          : confidenceLabel == 'Moyenne'
                          ? Colors.orange.withValues(alpha: 0.5)
                          : Colors.redAccent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        confidenceLabel == 'Elevee'
                            ? Icons.verified_user
                            : confidenceLabel == 'Moyenne'
                            ? Icons.rule_folder
                            : Icons.warning_amber_rounded,
                        color: confidenceLabel == 'Elevee'
                            ? Colors.green
                            : confidenceLabel == 'Moyenne'
                            ? Colors.orange
                            : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confiance $confidenceLabel basee sur $totalCompared comparaisons (score: $confidenceScore/100). Seuils: ${confidenceThresholds['medium'] ?? '-'} / ${confidenceThresholds['high'] ?? '-'}.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
