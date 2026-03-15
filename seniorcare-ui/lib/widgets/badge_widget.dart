import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
