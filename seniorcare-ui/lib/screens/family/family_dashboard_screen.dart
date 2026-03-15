import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../mock_data.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/family_nav_bar.dart';

class FamilyDashboardScreen extends StatelessWidget {
  const FamilyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const FamilyNavBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Dad's Health", style: AppTextStyles.title),
                  const StatusBadge(
                    label: 'All Good',
                    bgColor: AppColors.okBg,
                    textColor: AppColors.okText,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Parent card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.aiActionBg,
                          child: Text(
                            'MS',
                            style: TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                seniorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$location \u2022 2m ago',
                                style: AppTextStyles.micro,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$normalStreakDays day streak',
                              style: TextStyle(
                                fontSize: 8,
                                color: AppColors.okText,
                              ),
                            ),
                            Text(
                              '$normalAdherencePct% adherence',
                              style: AppTextStyles.micro,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Vital chips
                    Row(
                      children: [
                        _VitalChip('HR', '$normalHeartRate'),
                        const SizedBox(width: 8),
                        _VitalChip('SpO2', '$normalSpo2%'),
                        const SizedBox(width: 8),
                        _VitalChip('Steps', '3.2k'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Today's Activity
              Text(
                "Today's Activity",
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ActivityRow(
                dotColor: AppColors.okText,
                text: '8:07 AM \u2014 Metformin taken',
              ),
              ActivityRow(
                dotColor: AppColors.brandPrimary,
                text: '10:30 AM \u2014 30 min walk',
              ),
              ActivityRow(
                dotColor: AppColors.brandPrimary,
                text: '1:04 PM \u2014 AI call: confirmed dose',
              ),
              ActivityRow(
                dotColor: AppColors.warningText,
                text: 'Lisinopril: 3 pills \u2014 refill ordered',
              ),
              const SizedBox(height: 16),

              // Video Call button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Video Call $seniorName'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;

  const _VitalChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
