import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SearchNotFoundScreen extends StatelessWidget {
  final String query;
  final VoidCallback onTryAgain;

  const SearchNotFoundScreen({
    super.key,
    required this.query,
    required this.onTryAgain,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.blueGrey.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 110,
                    color: isDark ? Colors.blueGrey.shade100 : Colors.blueGrey,
                  ).animate().fadeIn(duration: 450.ms).scale(),
                  Positioned(
                    right: 12,
                    top: 10,
                    child:
                        Icon(
                              Icons.search_off_rounded,
                              size: 34,
                              color: isDark
                                  ? Colors.amberAccent
                                  : Colors.orange,
                            )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                              duration: 1700.ms,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.4),
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Oups, ville introuvable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.blueGrey.shade900,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Aucun resultat pour "$query".\nVerifie l orthographe ou essaie une ville proche.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onTryAgain,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),
      ),
    );
  }
}
