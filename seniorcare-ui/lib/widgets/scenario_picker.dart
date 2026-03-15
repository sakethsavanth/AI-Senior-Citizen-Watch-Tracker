import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/scenario_provider.dart';
import '../data/synthetic_scenarios.dart';
import '../theme/app_theme.dart';

/// Floating action button that opens scenario/persona picker bottom sheet.
class ScenarioPickerFab extends ConsumerWidget {
  const ScenarioPickerFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenarioKey = ref.watch(currentScenarioProvider);
    final risk = scenarios[scenarioKey]?['expected_risk'] as String? ?? 'low';
    final color = risk == 'high'
        ? AppColors.criticalText
        : risk == 'medium'
            ? AppColors.warningText
            : AppColors.okText;

    return FloatingActionButton.small(
      backgroundColor: color.withValues(alpha: 0.15),
      onPressed: () => _showPicker(context, ref),
      child: Icon(Icons.science_outlined, color: color, size: 20),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ScenarioPickerSheet(),
    );
  }
}

class _ScenarioPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeScenario = ref.watch(currentScenarioProvider);
    final activePersona = ref.watch(currentPersonaProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Demo Scenario Picker',
                style: AppTextStyles.seniorTitle.copyWith(color: AppColors.brandDark)),
          ),
          // Persona selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Persona', style: AppTextStyles.title),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: personaLabels.entries.map((e) {
                    final selected = e.key == activePersona;
                    return ChoiceChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      selectedColor: AppColors.aiActionBg,
                      onSelected: (_) => ref.read(currentPersonaProvider.notifier).state = e.key,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Scenarios', style: AppTextStyles.title),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: scenarioLabels.length,
              itemBuilder: (_, i) {
                final key = scenarioLabels.keys.elementAt(i);
                final label = scenarioLabels[key]!;
                final desc = scenarioDescriptions[key] ?? '';
                final risk = scenarios[key]?['expected_risk'] as String? ?? 'low';
                final selected = key == activeScenario;

                Color riskColor;
                String riskLabel;
                switch (risk) {
                  case 'high':
                    riskColor = AppColors.criticalText;
                    riskLabel = 'HIGH';
                  case 'medium':
                    riskColor = AppColors.warningText;
                    riskLabel = 'MED';
                  default:
                    riskColor = AppColors.okText;
                    riskLabel = 'LOW';
                }

                return Card(
                  color: selected ? AppColors.aiActionBg : null,
                  child: ListTile(
                    dense: true,
                    selected: selected,
                    title: Row(
                      children: [
                        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(riskLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: riskColor)),
                        ),
                      ],
                    ),
                    subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      ref.read(currentScenarioProvider.notifier).state = key;
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
