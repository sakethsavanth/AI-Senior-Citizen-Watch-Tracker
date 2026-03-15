import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../theme/app_theme.dart';

class AlertRow extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onCtaTap;

  const AlertRow({super.key, required this.alert, this.onCtaTap});

  Color _getBgColor(AlertType t) => switch (t) {
        AlertType.critical => AppColors.criticalBg,
        AlertType.aiAction => AppColors.aiActionBg,
        AlertType.warning => AppColors.warningBg,
        AlertType.info => AppColors.okBg,
      };

  Color _getBorderColor(AlertType t) => switch (t) {
        AlertType.critical => AppColors.criticalBorder,
        AlertType.aiAction => AppColors.aiActionBorder,
        AlertType.warning => AppColors.warningBorder,
        AlertType.info => AppColors.okBorder,
      };

  String _getTypeLabel(AlertType t) => switch (t) {
        AlertType.critical => 'CRITICAL',
        AlertType.aiAction => 'AI ACTION',
        AlertType.warning => 'WARNING',
        AlertType.info => 'INFO',
      };

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor(alert.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _getBgColor(alert.type),
        // NO borderRadius — single-side border requires border-radius: 0
        border: Border(
          left: BorderSide(color: borderColor, width: 2),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getTypeLabel(alert.type),
                style: TextStyle(
                  color: borderColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              Text(
                alert.time,
                style: TextStyle(fontSize: 9, color: borderColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: TextStyle(fontSize: 11, color: borderColor),
          ),
          if (alert.hasCta && alert.ctaLabel != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onCtaTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: AppColors.criticalText,
                child: Text(
                  alert.ctaLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
