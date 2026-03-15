import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../mock_data.dart';
import '../../widgets/badge_widget.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: mockCallHistory.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final call = mockCallHistory[index];
          final isConfirmed = call['outcome'] == 'Confirmed';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                // AI avatar
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.aiActionBg,
                    border:
                        Border.all(color: AppColors.brandPrimary, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Time
                SizedBox(
                  width: 110,
                  child: Text(
                    call['time']!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Target
                SizedBox(
                  width: 100,
                  child: Text(
                    call['target']!,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),

                // Reason
                Expanded(
                  child: Text(
                    call['reason']!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),

                // Duration
                SizedBox(
                  width: 50,
                  child: Text(
                    call['duration']!,
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),

                // Outcome badge
                StatusBadge(
                  label: call['outcome']!,
                  bgColor: isConfirmed ? AppColors.okBg : AppColors.aiActionBg,
                  textColor: isConfirmed
                      ? AppColors.okText
                      : AppColors.aiActionText,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
