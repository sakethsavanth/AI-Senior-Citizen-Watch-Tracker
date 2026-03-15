import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'synthetic_scenarios.dart';
import 'agent_simulator.dart';

/// Currently selected scenario key.
final currentScenarioProvider = StateProvider<String>((ref) => 'normal_day');

/// Currently selected persona key.
final currentPersonaProvider = StateProvider<String>((ref) => 'senior_001');

/// Merged health data: scenario health_data + persona fields.
/// For declining_week, uses the last day.
final scenarioHealthDataProvider = Provider<Map<String, dynamic>>((ref) {
  final scenarioKey = ref.watch(currentScenarioProvider);
  final personaKey = ref.watch(currentPersonaProvider);
  final scenario = scenarios[scenarioKey]!;
  final persona = personas[personaKey]!;

  Map<String, dynamic> healthData;
  if (scenarioKey == 'declining_week') {
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
  healthData['medication_name'] = persona['medication_name'];
  healthData['emergency_contact'] = persona['emergency_contact'];
  healthData['family_contacts'] = persona['family_contacts'];
  healthData['persona_name'] = persona['name'];
  healthData['persona_age'] = persona['age'];
  healthData['persona_medications'] = persona['medications'];

  return healthData;
});

/// Full triage result from the agent simulator.
final triageResultProvider = Provider<Map<String, dynamic>>((ref) {
  final h = ref.watch(scenarioHealthDataProvider);
  return AgentSimulator.fullHealthAssessment(h);
});

/// All agent results including routing decisions.
final agentResultsProvider = Provider<Map<String, dynamic>>((ref) {
  final h = ref.watch(scenarioHealthDataProvider);
  final contacts = (h['family_contacts'] as List?)
      ?.map((c) => Map<String, dynamic>.from(c as Map))
      .toList() ?? [];
  final emergency = h['emergency_contact'] as String? ?? '';
  return AgentSimulator.runAllAgents(h, contacts, emergency);
});

/// Declining week days (only valid when scenario is declining_week).
final decliningWeekDaysProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final scenarioKey = ref.watch(currentScenarioProvider);
  if (scenarioKey != 'declining_week') return [];
  final scenario = scenarios[scenarioKey]!;
  final days = scenario['days'] as List;
  return days.map((d) => Map<String, dynamic>.from(d as Map)).toList();
});
