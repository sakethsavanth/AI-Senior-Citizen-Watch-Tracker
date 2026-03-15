import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ActivityRow extends StatelessWidget {
  final Color dotColor;
  final String text;

  const ActivityRow({
    super.key,
    required this.dotColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}
