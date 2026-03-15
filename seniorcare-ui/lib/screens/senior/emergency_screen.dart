import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/agent_simulator.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phone_metric_card.dart';

class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final hr = (h['heart_rate'] as num?)?.toInt() ?? 0;
    final spo2 = (h['spo2'] as num?)?.toInt() ?? 0;
    final familyName = (h['emergency_contact'] as String?) ?? 'Family';
    final personaName = h['persona_name'] as String? ?? 'Senior';

    return Scaffold(
      backgroundColor: AppColors.criticalBg.withValues(alpha: 0.3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Emergency', style: AppTextStyles.seniorTitle),
              const SizedBox(height: 16),

              // Alert box
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
                    Text(
                      'Alert Sent to $familyName',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.criticalText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Emergency detected. Family notified.',
                      style: TextStyle(fontSize: 14, color: AppColors.criticalText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text('Are you okay?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Yes button
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

              // Need Help button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final result = AgentSimulator.emergencyEscalation(personaName, familyName);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Emergency Escalation'),
                        content: Text(result['message'] as String? ?? 'Emergency services notified.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                        ],
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

              const Text('Vitals now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: VitalCard(label: 'Heart Rate', value: '$hr', unit: 'bpm', color: AppColors.criticalText),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VitalCard(label: 'SpO2', value: '$spo2', unit: '%', color: AppColors.criticalText),
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
