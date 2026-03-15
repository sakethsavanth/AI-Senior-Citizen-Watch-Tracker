import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scenario_picker.dart';

class AgentResultsScreen extends ConsumerWidget {
  const AgentResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orchestrator = ref.watch(agentResultsProvider);
    final agentResults = orchestrator['agent_results'] as Map<String, dynamic>? ?? {};
    final invoked = orchestrator['invoked_agents'] as List? ?? [];
    final triage = ref.watch(triageResultProvider);
    final overallRisk = triage['overall_risk'] as String? ?? 'low';

    Color riskColor;
    switch (overallRisk) {
      case 'high':
        riskColor = AppColors.criticalText;
      case 'medium':
        riskColor = AppColors.warningText;
      default:
        riskColor = AppColors.okText;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Results')),
      floatingActionButton: const ScenarioPickerFab(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall risk banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.shield, color: riskColor, size: 28),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Overall Risk', style: AppTextStyles.title),
                Text(overallRisk.toUpperCase(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: riskColor)),
              ]),
            ]),
          ),

          const SizedBox(height: 16),
          Text('${invoked.length} Agents Invoked', style: AppTextStyles.title),
          const SizedBox(height: 8),

          // Agent cards
          ...agentResults.entries.map((entry) {
            final agentName = entry.key;
            final output = entry.value as Map<String, dynamic>;
            final wasInvoked = invoked.contains(agentName);

            return Card(
              color: wasInvoked ? null : Colors.grey[50],
              child: ExpansionTile(
                leading: Icon(
                  wasInvoked ? Icons.check_circle : Icons.remove_circle_outline,
                  color: wasInvoked ? AppColors.okText : Colors.grey,
                  size: 20,
                ),
                title: Text(agentName, style: AppTextStyles.title),
                subtitle: wasInvoked
                    ? null
                    : Text('Not invoked', style: AppTextStyles.label),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _AgentOutputView(output: output),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AgentOutputView extends StatelessWidget {
  final Map<String, dynamic> output;
  const _AgentOutputView({required this.output});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: output.entries.map((e) {
        final value = e.value;
        String display;
        if (value is List) {
          display = value.map((v) => '• $v').join('\n');
        } else if (value is Map) {
          display = value.entries.map((v) => '${v.key}: ${v.value}').join('\n');
        } else {
          display = value.toString();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(display, style: AppTextStyles.body),
            ],
          ),
        );
      }).toList(),
    );
  }
}
