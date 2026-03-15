import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'synthetic_scenarios.dart';
import 'agent_simulator.dart';

/// Currently selected scenario key (default: 'normal_day')
final currentScenarioProvider = StateProvider<String>((ref) => 'normal_day');

/// Currently selected persona key (default: 'senior_001')
final currentPersonaProvider = StateProvider<String>((ref) => 'senior_001');

/// Merged health data: scenario health_data + persona fields.
/// For declining_week, uses the last day.
final scenarioHealthDataProvider = Provider<Map<String, dynamic>>((ref) {
  final scenarioKey = ref.watch(currentScenarioProvider);
  final personaKey = ref.watch(currentPersonaProvider);

  final scenario = scenarios[scenarioKey]!;
  final persona = personas[personaKey]!;

  Map<String, dynamic> healthData;
  if (scenario.containsKey('days')) {
    // declining_week: use last day + root-level med fields
    final days = scenario['days'] as List;
    final lastDay = Map<String, dynamic>.from(days.last as Map);
    lastDay['medication_taken_today'] = scenario['medication_taken_today'];
    lastDay['doses_missed_consecutive_days'] = scenario['doses_missed_consecutive_days'];
    healthData = lastDay;
  } else {
    healthData = Map<String, dynamic>.from(scenario['health_data'] as Map);
  }

  // Merge persona fields
  healthData['user_id'] = persona['user_id'];
  healthData['medication_name'] ??= persona['medication_name'];
  healthData['emergency_contact'] ??= persona['emergency_contact'];
  healthData['family_contacts'] ??= persona['family_contacts'];

  return healthData;
});

/// Full triage result from AgentSimulator
final triageResultProvider = Provider<Map<String, dynamic>>((ref) {
  final healthData = ref.watch(scenarioHealthDataProvider);
  return AgentSimulator.fullHealthAssessment(healthData);
});

/// Full orchestrator results: which agents invoked + their outputs
final agentResultsProvider = Provider<Map<String, dynamic>>((ref) {
  final healthData = ref.watch(scenarioHealthDataProvider);
  return AgentSimulator.runOrchestrator(healthData);
});

/// The raw scenario map (for accessing days array, etc.)
final rawScenarioProvider = Provider<Map<String, dynamic>>((ref) {
  final scenarioKey = ref.watch(currentScenarioProvider);
  return scenarios[scenarioKey]!;
});

/// Current persona data
final currentPersonaDataProvider = Provider<Map<String, dynamic>>((ref) {
  final personaKey = ref.watch(currentPersonaProvider);
  return personas[personaKey]!;
});
