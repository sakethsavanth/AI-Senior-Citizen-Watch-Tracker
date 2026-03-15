import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../mock_data.dart';
import '../../widgets/medication_card.dart';
import '../../widgets/senior_nav_bar.dart';

class MedicationTrackerScreen extends StatelessWidget {
  const MedicationTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const SeniorNavBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medications',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Medication cards
              for (final med in mockMedications) MedicationCard(med: med),

              const SizedBox(height: 12),

              // Mark as Taken button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.okText,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Mark as Taken'),
                ),
              ),
              const SizedBox(height: 12),

              // Auto-refill banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-refill triggered',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningText,
                      ),
                    ),
                    Text(
                      'Lisinopril ordered \u2014 arrives Mon',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.warningText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Dose history link
              Center(
                child: TextButton(
                  onPressed: () => context.go('/senior/dose-history'),
                  child: Text(
                    'View dose history',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.brandPrimary,
                    ),
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
