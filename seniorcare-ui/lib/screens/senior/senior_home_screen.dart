import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../mock_data.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/phone_metric_card.dart';
import '../../widgets/pill_progress_bar.dart';
import '../../widgets/senior_nav_bar.dart';

class SeniorHomeScreen extends StatelessWidget {
  const SeniorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SeniorNavBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning, $seniorName',
                        style: AppTextStyles.seniorTitle,
                      ),
                      Text('Sat, March 14', style: AppTextStyles.seniorLabel),
                    ],
                  ),
                  const StatusBadge(
                    label: '7 day streak',
                    bgColor: AppColors.okBg,
                    textColor: AppColors.okText,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vitals 2x2 grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: const [
                  VitalCard(
                    label: 'Heart Rate',
                    value: '72',
                    unit: 'bpm',
                    color: AppColors.brandPrimary,
                  ),
                  VitalCard(
                    label: 'SpO2',
                    value: '98',
                    unit: '%',
                    color: AppColors.okText,
                  ),
                  VitalCard(
                    label: 'Steps',
                    value: '3,241',
                    unit: '',
                    color: Colors.black87,
                  ),
                  VitalCard(
                    label: 'Sleep',
                    value: '7.2',
                    unit: 'h',
                    color: Colors.black87,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Medication card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Medication',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Metformin 500mg',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '8:00 PM tonight \u2022 12 pills left',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const StatusBadge(
                          label: 'Taken',
                          bgColor: AppColors.okBg,
                          textColor: AppColors.okText,
                        ),
                      ],
                    ),
                    const PillProgressBar(
                      value: 0.85,
                      color: AppColors.pillFull,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Call Arjun button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/senior/call-incoming', extra: {
                      'med_id': 'lis',
                      'question':
                          'Good morning Mr. Sharma! Did you take your Lisinopril today?',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Call $familyName',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
