import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../theme/app_theme.dart';

class BadgeData {
  final String label;
  final Color bgColor;
  final Color textColor;

  const BadgeData(this.label, this.bgColor, this.textColor);
}

BadgeData getDoseBadge(Medication med) {
  if (med.status == DoseStatus.taken) {
    return BadgeData('Done ${med.takenAt}', AppColors.okBg, AppColors.okText);
  }
  if (med.status == DoseStatus.missed) {
    return BadgeData('Missed', AppColors.criticalBg, AppColors.criticalText);
  }
  if (med.pillsRemaining < 5) {
    return BadgeData('Low', AppColors.warningBg, AppColors.warningText);
  }
  return BadgeData('Pending', AppColors.aiActionBg, AppColors.aiActionText);
}
