import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/agent_simulator.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/phone_metric_card.dart';
import '../../widgets/pill_progress_bar.dart';
import '../../widgets/senior_nav_bar.dart';

class SeniorHomeScreen extends ConsumerWidget {
  const SeniorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final triage = ref.watch(triageResultProvider);
    final risk = triage['overall_risk'] as String? ?? 'low';
    final name = h['persona_name'] as String? ?? 'Senior';
    final hr = (h['heart_rate'] as num).toInt();
    final spo2 = (h['spo2'] as num).toInt();
    final steps = (h['steps'] as num).toInt();
    final sleepH = (h['sleep_hours'] as num).toDouble();
    final hrvPct = (h['hrv_percent'] as num?)?.toDouble() ?? 0;
    final pillCount = (h['pill_count'] as num).toInt();
    final lastMovement = (h['last_movement_minutes'] as num).toInt();
    final moodScore = (h['mood_score'] as num?)?.toDouble();
    final fallDetected = h['fall_detected'] as bool? ?? false;
    final contacts = (h['family_contacts'] as List?)
        ?.map((c) => Map<String, dynamic>.from(c as Map))
        .toList() ?? [];
    final familyContact = AgentSimulator.pickFamilyContact(contacts);
    final medName = h['medication_name'] as String? ?? 'Medication';

    String riskLabel;
    Color riskBg, riskText;
    switch (risk) {
      case 'high':
        riskLabel = 'Critical';
        riskBg = AppColors.criticalBg;
        riskText = AppColors.criticalText;
      case 'medium':
        riskLabel = 'Warning';
        riskBg = AppColors.warningBg;
        riskText = AppColors.warningText;
      default:
        riskLabel = 'All Good';
        riskBg = AppColors.okBg;
        riskText = AppColors.okText;
    }

    // HRV color
    Color hrvColor;
    if (hrvPct >= 60) {
      hrvColor = AppColors.okText;
    } else if (hrvPct >= 40) {
      hrvColor = AppColors.warningText;
    } else {
      hrvColor = AppColors.criticalText;
    }

    return Scaffold(
      bottomNavigationBar: const SeniorNavBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inactivity banner
              if (lastMovement > 240)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\u26A0 No movement detected for ${lastMovement ~/ 60}h ${lastMovement % 60}m',
                    style: TextStyle(fontSize: 14, color: AppColors.warningText, fontWeight: FontWeight.w600),
                  ),
                ),

              // Greeting row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning, $name', style: AppTextStyles.seniorTitle),
                        Text('Sat, March 15', style: AppTextStyles.seniorLabel),
                      ],
                    ),
                  ),
                  StatusBadge(label: riskLabel, bgColor: riskBg, textColor: riskText),
                ],
              ),
              const SizedBox(height: 12),

              // Vitals grid (2x3 with HRV)
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
                    color: (hr < 50 || hr > 120) ? AppColors.criticalText : AppColors.brandPrimary,
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
                    value: sleepH.toStringAsFixed(1),
                    unit: 'h',
                    color: sleepH < 4 ? AppColors.criticalText : (sleepH < 6 ? AppColors.warningText : Colors.black87),
                  ),
                  VitalCard(
                    label: 'HRV',
                    value: '${hrvPct.toStringAsFixed(0)}',
                    unit: '%',
                    color: hrvColor,
                  ),
                  if (moodScore != null)
                    VitalCard(
                      label: 'Mood',
                      value: moodScore.toStringAsFixed(1),
                      unit: '/5',
                      color: moodScore < 3 ? AppColors.criticalText : (moodScore < 4 ? AppColors.warningText : AppColors.okText),
                    )
                  else
                    VitalCard(
                      label: 'Pills',
                      value: '$pillCount',
                      unit: 'left',
                      color: pillCount < 3 ? AppColors.criticalText : AppColors.okText,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Mood card (tap to go to mood input)
              if (moodScore != null)
                GestureDetector(
                  onTap: () => context.go('/senior/mood'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: moodScore < 3 ? AppColors.warningBg : AppColors.aiActionBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          moodScore < 3 ? '😟' : (moodScore < 4 ? '😐' : '🙂'),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            moodScore < 3
                                ? 'You seem down today. Tap for wellness tips.'
                                : 'How are you feeling? Tap to log your mood.',
                            style: TextStyle(
                              fontSize: 14,
                              color: moodScore < 3 ? AppColors.warningText : AppColors.aiActionText,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: moodScore < 3 ? AppColors.warningText : AppColors.aiActionText),
                      ],
                    ),
                  ),
                ),

              // Medication card
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
                    const Text(
                      'Next Medication',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(medName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('$pillCount pills left', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: pillCount < 3 ? 'Low' : 'OK',
                          bgColor: pillCount < 3 ? AppColors.warningBg : AppColors.okBg,
                          textColor: pillCount < 3 ? AppColors.warningText : AppColors.okText,
                        ),
                      ],
                    ),
                    PillProgressBar(value: (pillCount / 30.0).clamp(0.0, 1.0), color: pillCount < 3 ? AppColors.pillLow : AppColors.pillFull),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Call family button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (fallDetected) {
                      context.go('/senior/emergency');
                    } else {
                      context.go('/senior/call-incoming', extra: {
                        'med_id': 'lis',
                        'question': 'Good morning $name! Did you take your $medName today?',
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fallDetected ? AppColors.criticalText : AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    fallDetected ? 'Emergency — Call Now' : 'Call ${familyContact['name'] ?? 'Family'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
