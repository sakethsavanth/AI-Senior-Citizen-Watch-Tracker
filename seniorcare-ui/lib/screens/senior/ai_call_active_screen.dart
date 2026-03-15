import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_avatar_widget.dart';
import '../../widgets/call_timer_widget.dart';

class AICallActiveScreen extends StatelessWidget {
  final Map<String, dynamic> callData;

  const AICallActiveScreen({super.key, required this.callData});

  @override
  Widget build(BuildContext context) {
    final question = callData['question'] as String? ?? 'Did you take your medication today?';
    final medName = callData['medication_name'] as String? ?? 'medication';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AIAvatarWidget(size: 80, pulsing: true),
                const SizedBox(height: 8),
                const CallTimerWidget(),
                const SizedBox(height: 20),

                // AI speech bubble
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.aiActionBg, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI is asking:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.aiActionText)),
                      const SizedBox(height: 4),
                      Text('"$question"', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Response buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$medName dose confirmed. Family notified.'), backgroundColor: AppColors.okText),
                          );
                          context.go('/senior/home');
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.okBg,
                          foregroundColor: AppColors.okText,
                          side: const BorderSide(color: AppColors.okBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Yes, taken', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$medName missed. Family alerted.'), backgroundColor: AppColors.criticalText),
                          );
                          context.go('/senior/home');
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.criticalBg,
                          foregroundColor: AppColors.criticalText,
                          side: const BorderSide(color: AppColors.criticalBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('No, missed', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/senior/home'),
                  child: const Text('End Call', style: TextStyle(fontSize: 14, color: AppColors.criticalText)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
