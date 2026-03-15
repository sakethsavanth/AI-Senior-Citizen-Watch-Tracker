import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/agent_simulator.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/family_nav_bar.dart';

class HealthRecordsScreen extends ConsumerWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final records = AgentSimulator.simulateHealthRecords(h);
    final interactions = records['medication_interactions'] as Map<String, dynamic>;
    final lab = records['lab_summary'] as Map<String, dynamic>;
    final visit = records['visit_prep'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Records')),
      bottomNavigationBar: const FamilyNavBar(currentIndex: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Section(
              title: 'Drug Interactions',
              icon: Icons.medication,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medications: ${(interactions['medications'] as List).join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    interactions['note'] as String? ?? '',
                    style: TextStyle(fontSize: 12, color: AppColors.okText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Section(
              title: 'Lab Summary',
              icon: Icons.science,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last updated: ${lab['last_updated']}', style: AppTextStyles.label),
                  const SizedBox(height: 4),
                  Text(lab['summary'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Section(
              title: 'Visit Preparation',
              icon: Icons.checklist,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in (visit['checklist'] as List? ?? []))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: AppColors.okText),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item as String, style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: AppColors.brandPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}
