import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/scenario_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/medication_card.dart';
import '../../widgets/scenario_picker.dart';
import '../../widgets/senior_nav_bar.dart';

class MedicationTrackerScreen extends ConsumerWidget {
  const MedicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiServiceProvider);
    final meds = api.getMedications();
    final agentResults = ref.watch(agentResultsProvider);
    final refillAgent = (agentResults['agent_results'] as Map<String, dynamic>?)?['Refill'] as Map<String, dynamic>?;
    final shouldRefill = refillAgent?['should_refill'] == true;
    final refillMed = refillAgent?['medication_name'] as String? ?? 'Medication';

    return Scaffold(
      bottomNavigationBar: const SeniorNavBar(currentIndex: 1),
      floatingActionButton: const ScenarioPickerFab(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Medications',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              for (final med in meds) MedicationCard(med: med),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dose confirmed! Family notified.'),
                        backgroundColor: AppColors.okText,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.okText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Mark as Taken'),
                ),
              ),
              const SizedBox(height: 12),

              if (shouldRefill)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-refill triggered',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText)),
                      Text('$refillMed ordered — arrives Mon',
                          style: TextStyle(fontSize: 10, color: AppColors.warningText)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => context.go('/senior/dose-history'),
                  child: Text('View dose history',
                      style: TextStyle(fontSize: 14, color: AppColors.brandPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
