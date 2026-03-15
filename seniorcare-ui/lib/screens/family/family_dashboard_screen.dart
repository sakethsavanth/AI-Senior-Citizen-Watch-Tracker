import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../models/alert.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/family_nav_bar.dart';
import '../../widgets/scenario_picker.dart';

class FamilyDashboardScreen extends ConsumerWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthData = ref.watch(scenarioHealthDataProvider);
    final persona = ref.watch(currentPersonaDataProvider);
    final triage = ref.watch(triageResultProvider);
    final api = ref.watch(apiServiceProvider);
    final alerts = api.getAlerts();

    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final steps = healthData['steps'] as int? ?? 0;
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final risk = triage['overall_risk'] as String? ?? 'low';
    final seniorName = persona['name'] as String? ?? 'Senior';
    final initials = seniorName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    Color statusBg;
    Color statusText;
    String statusLabel;
    switch (risk) {
      case 'high':
        statusBg = AppColors.criticalBg;
        statusText = AppColors.criticalText;
        statusLabel = 'Critical';
      case 'medium':
        statusBg = AppColors.warningBg;
        statusText = AppColors.warningText;
        statusLabel = 'Watch';
      default:
        statusBg = AppColors.okBg;
        statusText = AppColors.okText;
        statusLabel = 'All Good';
    }
    return Scaffold(
      bottomNavigationBar: const FamilyNavBar(currentIndex: 0),
      floatingActionButton: const ScenarioPickerFab(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("$seniorName's Health", style: AppTextStyles.title),
                  StatusBadge(label: statusLabel, bgColor: statusBg, textColor: statusText),
                ],
              ),
              const SizedBox(height: 12),

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
                          child: Text(initials,
                              style: TextStyle(color: AppColors.brandPrimary, fontWeight: FontWeight.w600, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(seniorName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              Text('${persona['timezone'] ?? 'Home'} \u2022 2m ago', style: AppTextStyles.micro),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$pillCount pills left',
                                style: TextStyle(fontSize: 8, color: pillCount < 5 ? AppColors.criticalText : AppColors.okText)),
                            Text('${alerts.length} alerts', style: AppTextStyles.micro),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _VitalChip('HR', '$hr'),
                      const SizedBox(width: 8),
                      _VitalChip('SpO2', '$spo2%'),
                      const SizedBox(width: 8),
                      _VitalChip('Steps', steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text("Today's Activity",
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...alerts.take(4).map((alert) => ActivityRow(
                dotColor: alert.type == AlertType.critical
                    ? AppColors.criticalText
                    : alert.type == AlertType.warning
                        ? AppColors.warningText
                        : alert.type == AlertType.aiAction
                            ? AppColors.brandPrimary
                            : AppColors.okText,
                text: '${alert.time} \u2014 ${alert.message}',
              )),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling $seniorName...'),
                          backgroundColor: AppColors.brandPrimary),
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
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
