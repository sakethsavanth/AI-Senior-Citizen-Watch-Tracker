import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/agent_simulator.dart';
import '../../data/scenario_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/medication_card.dart';
import '../../widgets/senior_nav_bar.dart';

class MedicationTrackerScreen extends ConsumerStatefulWidget {
  const MedicationTrackerScreen({super.key});

  @override
  ConsumerState<MedicationTrackerScreen> createState() => _MedicationTrackerScreenState();
}

class _MedicationTrackerScreenState extends ConsumerState<MedicationTrackerScreen> {
  @override
  Widget build(BuildContext context) {
    final h = ref.watch(scenarioHealthDataProvider);
    final agentResults = ref.watch(agentResultsProvider);
    final meds = ApiService.getMedicationsFromData(h);
    final medWindow = AgentSimulator.getCurrentMedWindow();
    final windowName = medWindow['label'] as String? ?? '';

    // Check refill
    final refill = agentResults['refill'] as Map<String, dynamic>? ?? {};
    final refillInvoked = refill['invoked'] == true;
    final refillOutput = refill['output'] as Map<String, dynamic>?;

    return Scaffold(
      bottomNavigationBar: const SeniorNavBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Medications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),

              // Med window indicator
              if (windowName.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.aiActionBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Current window: $windowName',
                    style: TextStyle(fontSize: 12, color: AppColors.aiActionText, fontWeight: FontWeight.w600),
                  ),
                ),

              // Medication cards
              for (final med in meds) MedicationCard(med: med),

              const SizedBox(height: 12),

              // Mark as Taken button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dose confirmed. Family notified.'), backgroundColor: AppColors.okText),
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

              // Auto-refill banner (conditional)
              if (refillInvoked && refillOutput != null && refillOutput['refill_needed'] == true)
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
                      Text(
                        'Auto-refill triggered',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
                      ),
                      Text(
                        '${refillOutput['reason']} \u2014 arrives in 2-3 days',
                        style: TextStyle(fontSize: 10, color: AppColors.warningText),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // Dose history link
              Center(
                child: TextButton(
                  onPressed: () => context.go('/senior/dose-history'),
                  child: Text('View dose history', style: TextStyle(fontSize: 14, color: AppColors.brandPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
