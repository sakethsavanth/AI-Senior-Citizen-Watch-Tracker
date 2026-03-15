import 'package:flutter/material.dart';
import '../../mock_data.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/family_nav_bar.dart';

class FamilyAlertsScreen extends StatelessWidget {
  const FamilyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      bottomNavigationBar: const FamilyNavBar(currentIndex: 2),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockAlerts.length,
        itemBuilder: (context, index) {
          return AlertRow(alert: mockAlerts[index]);
        },
      ),
    );
  }
}
