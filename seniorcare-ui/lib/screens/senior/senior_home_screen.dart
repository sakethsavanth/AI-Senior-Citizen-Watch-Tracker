import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/scenario_provider.dart';
import '../../models/medication.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/phone_metric_card.dart';
import '../../widgets/pill_progress_bar.dart';
import '../../widgets/scenario_picker.dart';
import '../../widgets/senior_nav_bar.dart';

class SeniorHomeScreen extends ConsumerWidget {
  const SeniorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthData = ref.watch(scenarioHealthDataProvider);
    final persona = ref.watch(currentPersonaDataProvider);
    final triage = ref.watch(triageResultProvider);
    final api = ref.watch(apiServiceProvider);
    final meds = api.getMedications();

    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final steps = healthData['steps'] as int? ?? 0;
    final sleep = (healthData['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final hrvPct = healthData['hrv_percent'] as int? ?? 60;
    final mood = (healthData['mood_score'] as num?)?.toDouble();
    final lastMovement = healthData['last_movement_minutes'] as int? ?? 0;
    final risk = triage['overall_risk'] as String? ?? 'low';
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final seniorName = persona['name'] as String? ?? 'Senior';
    final familyContacts = persona['family_contacts'] as List? ?? [];
    final familyName = familyContacts.isNotEmpty
        ? (familyContacts[0] as Map)['name'] as String? ?? 'Family'
        : 'Family';

    Color riskBgColor;
    Color riskTextColor;
    String riskLabel;
    switch (risk) {
      case 'high':
        riskBgColor = AppColors.criticalBg;
        riskTextColor = AppColors.criticalText;
        riskLabel = 'Critical';
      case 'medium':
        riskBgColor = AppColors.warningBg;
        riskTextColor = AppColors.warningText;
        riskLabel = 'Watch';
      default:
        riskBgColor = AppColors.okBg;
        riskTextColor = AppColors.okText;
        riskLabel = 'All Good';
    }

    // Next pending med
    final nextMed = meds.isNotEmpty ? meds.first : null;

    return Scaffold(
      bottomNavigationBar: const SeniorNavBar(currentIndex: 0),
      floatingActionButton: const ScenarioPickerFab(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning, $seniorName',
                        style: AppTextStyles.seniorTitle,
                      ),
                      Text('Sat, March 14', style: AppTextStyles.seniorLabel),
                    ],
                  ),
                  StatusBadge(
                    label: riskLabel,
                    bgColor: riskBgColor,
                    textColor: riskTextColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vitals grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  VitalCard(
                    label: 'Heart Rate',
                    value: '$hr',
                    unit: 'bpm',
                    color: (hr > 120 || hr < 50) ? AppColors.criticalText : AppColors.brandPrimary,
                  ),
                  VitalCard(
                    label: 'SpO2',
                    value: '$spo2',
                    unit: '%',
                    color: spo2 < 92 ? AppColors.criticalText : AppColors.okText,
                  ),
                  VitalCard(
                    label: 'Steps',
                    value: steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps',
                    unit: '',
                    color: Colors.black87,
                  ),
                  VitalCard(
                    label: 'Sleep',
                    value: sleep.toStringAsFixed(1),
                    unit: 'h',
                    color: sleep < 4 ? AppColors.criticalText : sleep < 6 ? AppColors.warningText : Colors.black87,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // HRV card
              if (hrvPct < 40)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.monitor_heart, color: AppColors.warningText, size: 18),
                    const SizedBox(width: 8),
                    Text('HRV $hrvPct% — below threshold',
                        style: TextStyle(fontSize: 12, color: AppColors.warningText, fontWeight: FontWeight.w600)),
                  ]),
                ),

              // Inactivity banner
              if (lastMovement >= 240)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lastMovement >= 360 ? AppColors.criticalBg : AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber,
                        color: lastMovement >= 360 ? AppColors.criticalText : AppColors.warningText, size: 18),
                    const SizedBox(width: 8),
                    Text('No movement for ${lastMovement ~/ 60}h ${lastMovement % 60}m',
                        style: TextStyle(
                          fontSize: 12,
                          color: lastMovement >= 360 ? AppColors.criticalText : AppColors.warningText,
                          fontWeight: FontWeight.w600,
                        )),
                  ]),
                ),

              // Mood indicator
              if (mood != null && mood < 3.0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.aiActionBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    onTap: () => context.go('/senior/mood'),
                    child: Row(children: [
                      Icon(Icons.psychology, color: AppColors.aiActionText, size: 18),
                      const SizedBox(width: 8),
                      Text('Mood: ${mood.toStringAsFixed(1)} — Tap for wellness check',
                          style: TextStyle(fontSize: 12, color: AppColors.aiActionText, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),

              const SizedBox(height: 12),

              // Medication card
              if (nextMed != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Next Medication',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nextMed.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('${nextMed.scheduledTime} • ${nextMed.pillsRemaining} pills left',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                          StatusBadge(
                            label: nextMed.status.name[0].toUpperCase() + nextMed.status.name.substring(1),
                            bgColor: nextMed.status == DoseStatus.taken ? AppColors.okBg : AppColors.warningBg,
                            textColor: nextMed.status == DoseStatus.taken ? AppColors.okText : AppColors.warningText,
                          ),
                        ],
                      ),
                      PillProgressBar(
                        value: pillCount / 30,
                        color: pillCount < 5 ? AppColors.pillLow : AppColors.pillFull,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Call button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/senior/call-incoming', extra: {
                      'med_id': nextMed?.id ?? 'lis',
                      'question': 'Good morning $seniorName! Did you take your ${nextMed?.name ?? "medication"} today?',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Call $familyName', style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
