import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widget.dart';

class AgentResultsScreen extends ConsumerWidget {
  const AgentResultsScreen({super.key});

  static const _agentOrder = [
    'vital_sync', 'medicine', 'medication', 'health_records',
    'activity', 'sleep', 'emo_care', 'refill', 'calling',
  ];

  static const _agentLabels = {
    'vital_sync': 'VitalSync',
    'medicine': 'Medicine',
    'medication': 'Medication',
    'health_records': 'HealthRecords',
    'activity': 'Activity',
    'sleep': 'Sleep',
    'emo_care': 'EmoCare',
    'refill': 'Refill',
    'calling': 'Calling',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(agentResultsProvider);
    final triage = results['triage'] as Map<String, dynamic>? ?? {};
    final risk = triage['overall_risk'] as String? ?? 'low';
    final flags = (triage['critical_flags'] as List?)?.cast<String>() ?? [];

    Color riskColor;
    switch (risk) {
      case 'high':
        riskColor = AppColors.criticalText;
      case 'medium':
        riskColor = AppColors.warningText;
      default:
        riskColor = AppColors.okText;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Risk badge
            Row(
              children: [
                const Text('Overall Risk: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                StatusBadge(label: risk.toUpperCase(), bgColor: riskColor.withValues(alpha: 0.15), textColor: riskColor),
              ],
            ),
            if (flags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Flags: ${flags.join(', ')}', style: TextStyle(fontSize: 11, color: AppColors.criticalText)),
            ],
            const SizedBox(height: 12),

            // Agent list
            for (final key in _agentOrder) ...[
              _AgentTile(
                name: _agentLabels[key] ?? key,
                data: results[key] as Map<String, dynamic>? ?? {},
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentTile extends StatefulWidget {
  final String name;
  final Map<String, dynamic> data;

  const _AgentTile({required this.name, required this.data});

  @override
  State<_AgentTile> createState() => _AgentTileState();
}

class _AgentTileState extends State<_AgentTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final invoked = widget.data['invoked'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: invoked ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    invoked ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 18,
                    color: invoked ? AppColors.okText : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: invoked ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                  if (invoked) Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
          if (_expanded && invoked && widget.data['output'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFF8FAFC),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(widget.data['output']),
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }
}
