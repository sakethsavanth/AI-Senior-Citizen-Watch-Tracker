import 'package:flutter/material.dart';

class PillProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const PillProgressBar({
    super.key,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
