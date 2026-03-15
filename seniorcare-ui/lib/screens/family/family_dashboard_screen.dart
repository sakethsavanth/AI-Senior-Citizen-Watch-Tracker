import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/family_nav_bar.dart';

class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final triage = ref.watch(triageResultProvider);
    final agentResults = ref.watch(agentResultsProvider);

    final seniorName = h['persona_name'] as String? ?? 'Senior';
    final initials = seniorName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final hr = (h['heart_rate'] as num?)?.toInt() ?? 0;
    final spo2 = (h['spo2'] as num?)?.toInt() ?? 0;
    final steps = (h['steps'] as num?)?.toInt() ?? 0;
    final risk = triage['overall_risk'] as String? ?? 'low';

    // Build activity rows from agent results
    final activityRows = <({Color dotColor, String text})>[];
    final meds = ApiService.getMedicationsFromData(h);
    for (final m in meds) {
      if (m.takenAt != null) {
        activityRows.add((dotColor: AppColors.okText, text: '${m.takenAt} \u2014 ${m.name} taken'));
      }
    }
    final activityAgent = agentResults['activity'] as Map<String, dynamic>? ?? {};
    if (activityAgent['invoked'] == true) {
      final out = activityAgent['output'] as Map<String, dynamic>? ?? {};
      activityRows.add((dotColor: AppColors.warningText, text: 'Activity: ${out['status'] ?? 'unknown'}'));
    }
    final callingAgent = agentResults['calling'] as Map<String, dynamic>? ?? {};
    if (callingAgent['invoked'] == true) {
      activityRows.add((dotColor: AppColors.brandPrimary, text: 'AI call: wellness check attempted'));
    }
    final refillAgent = agentResults['refill'] as Map<String, dynamic>? ?? {};
    if (refillAgent['invoked'] == true) {
      final out = refillAgent['output'] as Map<String, dynamic>? ?? {};
      if (out['refill_needed'] == true) {
        activityRows.add((dotColor: AppColors.warningText, text: '${h['medication_name'] ?? 'Med'}: refill ordered'));
      }
    }

    String badgeLabel;
    Color badgeBg, badgeText;
    if (risk == 'high') {
      badgeLabel = 'Critical';
      badgeBg = AppColors.criticalBg;
      badgeText = AppColors.criticalText;
    } else if (risk == 'medium') {
      badgeLabel = 'Warning';
      badgeBg = AppColors.warningBg;
      badgeText = AppColors.warningText;
    } else {
      badgeLabel = 'All Good';
      badgeBg = AppColors.okBg;
      badgeText = AppColors.okText;
    }

    return Scaffold(
      bottomNavigationBar: const FamilyNavBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$seniorName's Health", style: AppTextStyles.title),
                  StatusBadge(label: badgeLabel, bgColor: badgeBg, textColor: badgeText),
                ],
              ),
              const SizedBox(height: 12),

              // Parent card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.aiActionBg,
                          child: Text(initials, style: TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w600, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(seniorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              Text('At home \u2022 2m ago', style: AppTextStyles.micro),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _VitalChip('HR', '$hr'),
                        const SizedBox(width: 8),
                        _VitalChip('SpO2', '$spo2%'),
                        const SizedBox(width: 8),
                        _VitalChip('Steps', '${(steps / 1000).toStringAsFixed(1)}k'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Today's Activity
              Text("Today's Activity", style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (activityRows.isEmpty)
                const ActivityRow(dotColor: AppColors.okText, text: 'No notable activity yet.')
              else
                for (final a in activityRows)
                  ActivityRow(dotColor: a.dotColor, text: a.text),
              const SizedBox(height: 16),

              // Video Call button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video call simulated in demo mode.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Video Call $seniorName'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;

  const _VitalChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
