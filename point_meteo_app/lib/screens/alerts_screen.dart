import 'package:flutter/material.dart';
import '../models/alert_rule.dart';
import '../services/alerts_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final rules = await AlertsService.getRules();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  Future<void> _toggleRule(String id) async {
    await AlertsService.toggleRule(id);
    await _loadRules();
  }

  Future<void> _deleteRule(String id) async {
    await AlertsService.deleteRule(id);
    await _loadRules();
  }

  Future<void> _showAddAlertDialog() async {
    final result = await showDialog<AlertRule>(
      context: context,
      builder: (ctx) => const _AddAlertDialog(),
    );
    if (result != null) {
      await AlertsService.addRule(result);
      await _loadRules();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Smart Alerts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'À propos des alertes',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState(isDark)
              : _buildRulesList(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAlertDialog,
        backgroundColor: Colors.blue.shade900,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouvelle alerte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune alerte configurée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuie sur + pour créer ta première alerte météo',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: _showAddAlertDialog,
            icon: const Icon(Icons.add_alert),
            label: const Text('Créer une alerte'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade700),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${_rules.length} alerte${_rules.length > 1 ? 's' : ''} configurée${_rules.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ),
        ..._rules.map((rule) => _buildRuleCard(rule, isDark)),
      ],
    );
  }

  Widget _buildRuleCard(AlertRule rule, bool isDark) {
    return Dismissible(
      key: Key(rule.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteRule(rule.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Semantics(
          label: 'Supprimer cette alerte',
          child: const ExcludeSemantics(
            child: Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? Colors.grey[850] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Semantics(
                label: rule.label,
                image: true,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: rule.isEnabled
                        ? Colors.blue.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(rule.icon, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.cityName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: rule.isEnabled
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rule.description,
                      style: TextStyle(
                        color: rule.isEnabled
                            ? (isDark ? Colors.white70 : Colors.grey.shade600)
                            : Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: rule.isEnabled
                            ? Colors.blue.shade900.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rule.label,
                        style: TextStyle(
                          color: rule.isEnabled
                              ? Colors.blue.shade900
                              : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.isEnabled,
                onChanged: (_) => _toggleRule(rule.id),
                activeTrackColor: Colors.blue.shade700,
                activeThumbColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue),
            SizedBox(width: 10),
            Text('Smart Alerts', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comment ça marche ?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Définis une règle météo pour une ville (pluie, température, vent)'),
              SizedBox(height: 8),
              Text('Notre serveur vérifie les conditions toutes les 30 minutes'),
              SizedBox(height: 8),
              Text('Tu reçois une notification push dès que la condition est remplie'),
              SizedBox(height: 16),
              Text(
                'Glisse une carte vers la gauche pour supprimer une alerte.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('J\'ai compris',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Dialogue d'ajout d'une alerte ────────────────────────────────────────────

class _AddAlertDialog extends StatefulWidget {
  const _AddAlertDialog();

  @override
  State<_AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends State<_AddAlertDialog> {
  final _cityController = TextEditingController();
  AlertType _selectedType = AlertType.rain;
  double _threshold = 0;
  int _hoursAhead = 3;

  bool get _needsThreshold =>
      _selectedType == AlertType.tempBelow ||
      _selectedType == AlertType.tempAbove ||
      _selectedType == AlertType.wind;

  String get _thresholdLabel {
    switch (_selectedType) {
      case AlertType.tempBelow:
      case AlertType.tempAbove:
        return 'Seuil de température (°C)';
      case AlertType.wind:
        return 'Vitesse du vent (km/h)';
      default:
        return '';
    }
  }

  double get _thresholdMin {
    switch (_selectedType) {
      case AlertType.tempBelow:
        return -30;
      case AlertType.tempAbove:
        return 20;
      case AlertType.wind:
        return 20;
      default:
        return 0;
    }
  }

  double get _thresholdMax {
    switch (_selectedType) {
      case AlertType.tempBelow:
        return 25;
      case AlertType.tempAbove:
        return 55;
      case AlertType.wind:
        return 200;
      default:
        return 100;
    }
  }

  @override
  void initState() {
    super.initState();
    _threshold = _thresholdMin;
  }

  void _onTypeChanged(AlertType type) {
    setState(() {
      _selectedType = type;
      _threshold = _thresholdMin;
    });
  }

  void _submit() {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    final rule = AlertRule(
      id: AlertsService.generateId(),
      cityName: city,
      type: _selectedType,
      threshold: _threshold,
      hoursAhead: _hoursAhead,
    );
    Navigator.of(context).pop(rule);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      title: const Text(
        'Nouvelle alerte',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Ville',
                  hintText: 'ex: Paris',
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Type d'alerte",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              _buildTypeSelector(isDark),
              if (_needsThreshold) ...[
                const SizedBox(height: 20),
                Text(
                  _thresholdLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _threshold.clamp(_thresholdMin, _thresholdMax),
                        min: _thresholdMin,
                        max: _thresholdMax,
                        divisions: (_thresholdMax - _thresholdMin).toInt(),
                        activeColor: Colors.blue.shade700,
                        onChanged: (v) => setState(() => _threshold = v),
                      ),
                    ),
                    Container(
                      width: 56,
                      alignment: Alignment.center,
                      child: Text(
                        '${_threshold.toStringAsFixed(0)}${_selectedType == AlertType.wind ? ' km/h' : '°C'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_selectedType == AlertType.rain) ...[
                const SizedBox(height: 20),
                Text(
                  'Horizon de prévision',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1h')),
                    ButtonSegment(value: 3, label: Text('3h')),
                    ButtonSegment(value: 6, label: Text('6h')),
                  ],
                  selected: {_hoursAhead},
                  onSelectionChanged: (v) =>
                      setState(() => _hoursAhead = v.first),
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.blue.shade900;
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor:
                        WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.blueAccent;
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Annuler', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    final types = AlertType.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final rule = AlertRule(
          id: '',
          cityName: '',
          type: type,
        );
        final isSelected = _selectedType == type;
        return GestureDetector(
          onTap: () => _onTypeChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.shade900
                  : (isDark ? Colors.grey[800] : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.blue.shade700
                    : Colors.transparent,
              ),
            ),
            child: Semantics(
              label: rule.label,
              selected: isSelected,
              button: true,
              excludeSemantics: false,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: Text(rule.icon, style: const TextStyle(fontSize: 18))),
                const SizedBox(width: 6),
                Text(
                  rule.label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
