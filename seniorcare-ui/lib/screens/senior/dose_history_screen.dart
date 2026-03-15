import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../models/medication.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/scenario_picker.dart';
import '../../widgets/senior_nav_bar.dart';

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiServiceProvider);
    final doseLog = api.getDoseLog();
    final weekLogs = api.getWeekDoseLogs();

    // Build week status from weekly logs
    final weekDoseStatus = weekLogs.map((log) {
      if (log.entries.isEmpty) return 'pending';
      final allTaken = log.entries.every((e) => e.status == DoseStatus.taken);
      final anyMissed = log.entries.any((e) => e.status == DoseStatus.missed);
      if (allTaken) return 'taken';
      if (anyMissed) return 'missed';
      return 'pending';
    }).toList();

    // Pad to 7 days
    while (weekDoseStatus.length < 7) {
      weekDoseStatus.add('pending');
    }

    final adherence = weekDoseStatus.where((s) => s == 'taken').length * 100 ~/ 7;
    final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dose History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusBadge(
              label: '$adherence%',
              bgColor: AppColors.okBg,
              textColor: AppColors.okText,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SeniorNavBar(currentIndex: 1),
      floatingActionButton: const ScenarioPickerFab(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mar 10\u201316 \u2022 $adherence% adherence',
              style: AppTextStyles.seniorLabel,
            ),
            const SizedBox(height: 12),

            // Week calendar strip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final status = weekDoseStatus[i];
                Color circleColor;
                String circleLabel;
                Color labelColor;

                switch (status) {
                  case 'taken':
                    circleColor = AppColors.okBg;
                    circleLabel = '\u2713';
                    labelColor = AppColors.okText;
                  case 'missed':
                    circleColor = AppColors.criticalBg;
                    circleLabel = '!';
                    labelColor = AppColors.criticalText;
                  default:
                    circleColor = Colors.grey[200]!;
                    circleLabel = '-';
                    labelColor = Colors.grey;
                }

                return Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor,
                      ),
                      child: Center(
                        child: Text(
                          circleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: labelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Dose entries grouped by drug
            for (final entry in doseLog.entries) ...[
              Text(
                entry.medName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: _getRowColor(entry.status),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.takenAt != null
                          ? '${entry.scheduledTime} \u2192 taken at ${entry.takenAt}'
                          : entry.status == DoseStatus.missed
                              ? '${entry.scheduledTime} \u2192 MISSED'
                              : '${entry.scheduledTime} \u2192 pending',
                      style: TextStyle(
                        fontSize: 14,
                        color: _getTextColor(entry.status),
                      ),
                    ),
                    if (entry.aiNote != null)
                      Text(
                        entry.aiNote!,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.criticalText,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRowColor(DoseStatus status) => switch (status) {
        DoseStatus.taken => AppColors.okBg,
        DoseStatus.missed => AppColors.criticalBg,
        DoseStatus.pending => AppColors.aiActionBg,
        DoseStatus.low => AppColors.warningBg,
      };

  Color _getTextColor(DoseStatus status) => switch (status) {
        DoseStatus.taken => AppColors.okText,
        DoseStatus.missed => AppColors.criticalText,
        DoseStatus.pending => AppColors.aiActionText,
        DoseStatus.low => AppColors.warningText,
      };
}
