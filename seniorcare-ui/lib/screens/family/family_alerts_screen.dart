import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/family_nav_bar.dart';

class FamilyAlertsScreen extends ConsumerWidget {
  const FamilyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentResults = ref.watch(agentResultsProvider);
    final alerts = ApiService.getAlertsFromAgentResults(agentResults);

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      bottomNavigationBar: const FamilyNavBar(currentIndex: 2),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          return AlertRow(
            alert: alerts[index],
            onCtaTap: alerts[index].hasCta
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling family member...')),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }
}
