import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_avatar_widget.dart';

class AICallIncomingScreen extends StatelessWidget {
  final Map<String, dynamic> callData;

  const AICallIncomingScreen({super.key, required this.callData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AIAvatarWidget(size: 80, pulsing: false),
            const SizedBox(height: 16),
            const Text('SeniorCare AI', style: AppTextStyles.seniorTitle),
            const Text('Health Check Call', style: AppTextStyles.seniorLabel),
            const SizedBox(height: 12),

            // Speech bubble
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '"${callData['question'] ?? 'Good morning! Did you take your medication today?'}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CallActionButton(
                  icon: Icons.call_end,
                  bgColor: AppColors.criticalBg,
                  iconColor: AppColors.criticalText,
                  label: 'Decline',
                  onTap: () => context.go('/senior/home'),
                ),
                const SizedBox(width: 40),
                _CallActionButton(
                  icon: Icons.call,
                  bgColor: AppColors.okBg,
                  iconColor: AppColors.okText,
                  label: 'Answer',
                  onTap: () =>
                      context.go('/senior/call-active', extra: callData),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: iconColor),
          ),
        ],
      ),
    );
  }
}
