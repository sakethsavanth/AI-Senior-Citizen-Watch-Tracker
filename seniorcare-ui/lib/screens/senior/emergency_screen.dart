import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phone_metric_card.dart';
import '../../widgets/scenario_picker.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthData = ref.watch(scenarioHealthDataProvider);
    final persona = ref.watch(currentPersonaDataProvider);
    final triage = ref.watch(triageResultProvider);
    final flags = triage['critical_flags'] as List? ?? [];

    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final lastMovement = healthData['last_movement_minutes'] as int? ?? 0;
    final familyContacts = persona['family_contacts'] as List? ?? [];
    final familyName = familyContacts.isNotEmpty
        ? (familyContacts[0] as Map)['name'] as String? ?? 'Family'
        : 'Family';

    String alertMessage = 'Health anomaly detected. Family notified.';
    if (flags.contains('fall_detected')) {
      alertMessage = 'Fall detected! Emergency response initiated.';
    } else if (lastMovement >= 360) {
      alertMessage = 'No movement for ${lastMovement ~/ 60}h. Family notified.';
    } else if (flags.contains('tachycardia') || flags.contains('bradycardia')) {
      alertMessage = 'Abnormal heart rate: $hr bpm. Family alerted.';
    } else if (flags.contains('hypoxemia')) {
      alertMessage = 'Low SpO2: $spo2%. Emergency contact notified.';
    }

    return Scaffold(
      backgroundColor: AppColors.criticalBg.withValues(alpha: 0.3),
      floatingActionButton: const ScenarioPickerFab(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Emergency', style: AppTextStyles.seniorTitle),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.criticalBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert Sent to $familyName',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.criticalText)),
                    const SizedBox(height: 4),
                    Text(alertMessage,
                        style: const TextStyle(fontSize: 14, color: AppColors.criticalText)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text('Are you okay?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/senior/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.okText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Yes, I am fine', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Emergency services contacted. Help is on the way.'),
                        backgroundColor: AppColors.criticalText,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.criticalText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Need Help Now', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Vitals now',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: VitalCard(
                      label: 'Heart Rate',
                      value: '$hr',
                      unit: 'bpm',
                      color: (hr > 120 || hr < 50) ? AppColors.criticalText : AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VitalCard(
                      label: 'SpO2',
                      value: '$spo2',
                      unit: '%',
                      color: spo2 < 92 ? AppColors.criticalText : AppColors.okText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
