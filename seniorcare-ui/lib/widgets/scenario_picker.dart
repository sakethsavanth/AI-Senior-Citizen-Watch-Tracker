import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/synthetic_scenarios.dart';
import '../data/scenario_provider.dart';
import '../theme/app_theme.dart';

class ScenarioPicker extends ConsumerWidget {
  const ScenarioPicker({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ScenarioPicker(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScenario = ref.watch(currentScenarioProvider);
    final currentPersona = ref.watch(currentPersonaProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Demo Scenario', style: AppTextStyles.seniorTitle),
          const SizedBox(height: 4),
          Text('Pick a scenario and persona for the demo.', style: AppTextStyles.seniorLabel),
          const SizedBox(height: 16),

          // Scenario dropdown
          const Text('Scenario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: currentScenario,
                items: scenarioLabels.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (v) {
                  if (v != null) ref.read(currentScenarioProvider.notifier).state = v;
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Scenario description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.aiActionBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              scenarios[currentScenario]?['description'] as String? ?? '',
              style: TextStyle(fontSize: 12, color: AppColors.aiActionText),
            ),
          ),
          const SizedBox(height: 16),

          // Persona dropdown
          const Text('Persona', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: currentPersona,
                items: personaLabels.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (v) {
                  if (v != null) ref.read(currentPersonaProvider.notifier).state = v;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
