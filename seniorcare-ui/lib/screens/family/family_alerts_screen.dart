import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/family_nav_bar.dart';
import '../../widgets/scenario_picker.dart';

class FamilyAlertsScreen extends ConsumerWidget {
  const FamilyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiServiceProvider);
    final alerts = api.getAlerts();

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      bottomNavigationBar: const FamilyNavBar(currentIndex: 2),
      floatingActionButton: const ScenarioPickerFab(),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          return AlertRow(
            alert: alerts[index],
            onCtaTap: alerts[index].hasCta
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Action: ${alerts[index].ctaLabel}'),
                      ),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }
}
