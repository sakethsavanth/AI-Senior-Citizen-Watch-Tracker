import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../models/medication.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/senior_nav_bar.dart';

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final days = ref.watch(decliningWeekDaysProvider);
    final doseLog = ApiService.getDoseLogFromData(h);

    // Build week dose status from declining_week or from today's data
    final weekDoseStatus = days.isNotEmpty
        ? days.map((d) {
            final taken = d['medication_taken_today'] as Map<String, dynamic>?;
            if (taken == null) return 'pending';
            final anyTaken = taken.values.any((v) => v == true);
            final allTaken = taken.values.every((v) => v == true);
            return allTaken ? 'taken' : anyTaken ? 'taken' : 'missed';
          }).toList()
        : ['taken', 'taken', 'taken', 'taken', 'taken', 'taken', 'pending'];

    final dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dose History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusBadge(label: '95%', bgColor: AppColors.okBg, textColor: AppColors.okText),
          ),
        ],
      ),
      bottomNavigationBar: const SeniorNavBar(currentIndex: 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week \u2022 Dose adherence', style: AppTextStyles.seniorLabel),
            const SizedBox(height: 12),

            // Week calendar strip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(weekDoseStatus.length.clamp(0, 7), (i) {
                final status = i < weekDoseStatus.length ? weekDoseStatus[i] : 'pending';
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
                    Text(i < dayLetters.length ? dayLetters[i] : '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
                      child: Center(child: Text(circleLabel, style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w600))),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Dose entries
            for (final entry in doseLog.entries) ...[
              Text(entry.medName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(color: _getRowColor(entry.status), borderRadius: BorderRadius.circular(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.takenAt != null
                          ? '${entry.scheduledTime} \u2192 taken at ${entry.takenAt}'
                          : entry.status == DoseStatus.missed
                              ? '${entry.scheduledTime} \u2192 MISSED'
                              : '${entry.scheduledTime} \u2192 pending',
                      style: TextStyle(fontSize: 14, color: _getTextColor(entry.status)),
                    ),
                    if (entry.aiNote != null)
                      Text(entry.aiNote!, style: TextStyle(fontSize: 10, color: AppColors.criticalText)),
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
