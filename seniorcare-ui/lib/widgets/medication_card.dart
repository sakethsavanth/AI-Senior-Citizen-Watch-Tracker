import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';
import '../utils/dose_badge_logic.dart';
import 'badge_widget.dart';
import 'pill_progress_bar.dart';

class MedicationCard extends StatelessWidget {
  final Medication med;

  const MedicationCard({super.key, required this.med});

  Color _getBorderColor() {
    switch (med.status) {
      case DoseStatus.missed:
        return AppColors.criticalBorder;
      case DoseStatus.pending:
        return AppColors.aiActionBorder;
      case DoseStatus.low:
        return AppColors.warningBorder;
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  Color _getPillBarColor() {
    final ratio = med.pillsRemaining / 30.0;
    if (med.status == DoseStatus.pending) return AppColors.pillPending;
    if (ratio < 0.2) return AppColors.pillLow;
    return AppColors.pillFull;
  }

  @override
  Widget build(BuildContext context) {
    final badge = getDoseBadge(med);
    final borderColor =
        med.pillsRemaining < 5 ? AppColors.warningBorder : _getBorderColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${med.scheduledTime} \u2022 ${med.pillsRemaining} pills',
                      style: TextStyle(
                        fontSize: 10,
                        color: med.status == DoseStatus.missed
                            ? AppColors.criticalText
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: badge.label,
                bgColor: badge.bgColor,
                textColor: badge.textColor,
              ),
            ],
          ),
          PillProgressBar(
            value: med.pillsRemaining / 30.0,
            color: _getPillBarColor(),
          ),
        ],
      ),
    );
  }
}
