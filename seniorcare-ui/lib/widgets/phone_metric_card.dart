import 'package:flutter/material.dart';

class VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const VitalCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
