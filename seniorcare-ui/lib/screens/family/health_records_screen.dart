import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scenario_picker.dart';

class HealthRecordsScreen extends ConsumerWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(currentPersonaDataProvider);
    final agentResults = ref.watch(agentResultsProvider);
    final hrAgent = (agentResults['agent_results'] as Map<String, dynamic>?)?['HealthRecords'] as Map<String, dynamic>?;

    final interactions = persona['drug_interactions'] as List? ?? [];
    final labResults = persona['lab_results'] as Map<String, dynamic>?;
    final labTests = labResults?['tests'] as List? ?? [];
    final labSummary = labResults?['summary'] as String? ?? '';
    final labUpdated = labResults?['last_updated'] as String? ?? '';

    // Visit checklist from agent
    final visitChecklist = hrAgent?['visit_checklist'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Health Records')),
      floatingActionButton: const ScenarioPickerFab(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Lab Results
          Text('Lab Results', style: AppTextStyles.seniorTitle),
          if (labUpdated.isNotEmpty)
            Text('Updated: $labUpdated', style: AppTextStyles.seniorLabel),
          const SizedBox(height: 8),
          ...labTests.map((t) {
            final test = t as Map<String, dynamic>;
            final flag = test['flag'] as String? ?? 'normal';
            Color flagColor;
            switch (flag) {
              case 'high':
                flagColor = AppColors.criticalText;
              case 'borderline':
                flagColor = AppColors.warningText;
              default:
                flagColor = AppColors.okText;
            }
            return Card(
              child: ListTile(
                dense: true,
                title: Text(test['name'] as String? ?? '', style: AppTextStyles.title),
                subtitle: Text('Range: ${test['range'] ?? ''}', style: AppTextStyles.seniorLabel),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(test['value'] as String? ?? '', style: AppTextStyles.seniorBody.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: flagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(flag.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: flagColor)),
                  ),
                ]),
              ),
            );
          }),
          if (labSummary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Summary: $labSummary', style: AppTextStyles.seniorBody),
            ),

          const SizedBox(height: 24),

          // Drug Interactions
          Text('Drug Interactions', style: AppTextStyles.seniorTitle),
          const SizedBox(height: 8),
          ...interactions.map((inter) {
            final i = inter as Map<String, dynamic>;
            final severity = i['severity'] as String? ?? 'low';
            final isCritical = severity == 'high';
            return Card(
              color: isCritical ? AppColors.criticalBg : AppColors.warningBg,
              child: ListTile(
                leading: Icon(
                  isCritical ? Icons.warning_amber : Icons.info_outline,
                  color: isCritical ? AppColors.criticalText : AppColors.warningText,
                ),
                title: Text((i['drugs'] as List?)?.join(' + ') ?? '',
                    style: AppTextStyles.title.copyWith(
                        color: isCritical ? AppColors.criticalText : AppColors.warningText)),
                subtitle: Text(i['warning'] as String? ?? '', style: AppTextStyles.seniorBody),
              ),
            );
          }),

          if (visitChecklist.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Visit Preparation Checklist', style: AppTextStyles.seniorTitle),
            const SizedBox(height: 8),
            Card(
              color: AppColors.aiActionBg,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: visitChecklist.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.aiActionText),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.toString(), style: AppTextStyles.seniorBody)),
                    ]),
                  )).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
