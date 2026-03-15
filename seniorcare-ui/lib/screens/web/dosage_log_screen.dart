import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../mock_data.dart';
import '../../models/medication.dart';

class DosageLogScreen extends StatelessWidget {
  const DosageLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dayLetters = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosage Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week picker
            Row(
              children: [
                Text(
                  'Week of Mar 10 \u2013 16, 2026',
                  style: AppTextStyles.title,
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
              ],
            ),
            Text(
              '$normalAdherencePct% adherence this week',
              style: AppTextStyles.label,
            ),
            const SizedBox(height: 16),

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
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor,
                      ),
                      child: Center(
                        child: Text(
                          circleLabel,
                          style: TextStyle(
                            fontSize: 12,
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
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Dose entries
            for (final entry in mockDoseLog.entries) ...[
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        fontSize: 13,
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
              const SizedBox(height: 12),
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
