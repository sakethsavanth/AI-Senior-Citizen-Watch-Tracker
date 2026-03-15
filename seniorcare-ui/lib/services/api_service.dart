import '../data/agent_simulator.dart';
import '../models/medication.dart';
import '../models/alert.dart';
import '../models/dose_log.dart';

/// Scenario-driven API service. All data derived from the current scenario
/// and persona via AgentSimulator. No real network calls.
class ApiService {
  /// Generate medications from persona + scenario pill_count / taken_today.
  static List<Medication> getMedicationsFromData(
    Map<String, dynamic> healthData,
  ) {
    final personaMeds = healthData['persona_medications'] as List? ?? [];
    final pillCount = (healthData['pill_count'] as num?)?.toInt() ?? 10;
    final takenToday = healthData['medication_taken_today'] as Map<String, dynamic>? ?? {};
    final windows = ['morning', 'afternoon', 'evening'];

    return List.generate(personaMeds.length.clamp(0, 3), (i) {
      final pm = personaMeds[i] as Map;
      final window = i < windows.length ? windows[i] : 'morning';
      final taken = takenToday[window] as bool? ?? false;
      DoseStatus status;
      String? takenAt;
      if (taken) {
        status = DoseStatus.taken;
        takenAt = pm['scheduled_time'] as String? ?? '8:00 AM';
      } else {
        status = DoseStatus.pending;
      }
      return Medication(
        id: pm['id'] as String? ?? 'med_$i',
        name: pm['name'] as String? ?? 'Medication',
        dosage: pm['dosage'] as String? ?? '',
        scheduledTime: pm['scheduled_time'] as String? ?? '',
        pillsRemaining: (pillCount - i * 3).clamp(0, 30),
        status: status,
        takenAt: takenAt,
      );
    });
  }

  /// Generate alerts from agent results.
  static List<Alert> getAlertsFromAgentResults(Map<String, dynamic> agentResults) {
    final alerts = <Alert>[];
    final triage = agentResults['triage'] as Map<String, dynamic>? ?? {};
    final flags = triage['critical_flags'] as List? ?? [];

    for (final flag in flags) {
      final f = flag as String;
      switch (f) {
        case 'vitals_critical':
          alerts.add(const Alert(type: AlertType.critical, message: 'Vital signs critical — HR or SpO2 out of range.', time: 'Now', hasCta: true, ctaLabel: 'Call Now'));
        case 'fall_detected':
          alerts.add(const Alert(type: AlertType.critical, message: 'Fall detected! Emergency services alerted.', time: 'Now', hasCta: true, ctaLabel: 'Call Now'));
        case 'hrv_low':
          alerts.add(const Alert(type: AlertType.warning, message: 'HRV below 40% — consider a doctor visit.', time: 'Today'));
        case 'sleep_poor':
          alerts.add(const Alert(type: AlertType.warning, message: 'Very poor sleep last night — monitoring closely.', time: 'Today'));
        case 'activity_critical':
          alerts.add(const Alert(type: AlertType.critical, message: 'No movement detected for extended period.', time: 'Now', hasCta: true, ctaLabel: 'Call Now'));
        case 'medication_depleted':
          alerts.add(const Alert(type: AlertType.warning, message: 'Medication depleted — refill urgent.', time: 'Today'));
        case 'mood_low':
          alerts.add(const Alert(type: AlertType.aiAction, message: 'Low mood detected — AI wellness check initiated.', time: 'Today'));
      }
    }

    // Refill alert
    final refill = agentResults['refill'] as Map<String, dynamic>? ?? {};
    if (refill['invoked'] == true) {
      final output = refill['output'] as Map<String, dynamic>? ?? {};
      if (output['refill_needed'] == true) {
        alerts.add(const Alert(type: AlertType.warning, message: 'Medication refill ordered — arrives in 2-3 days.', time: 'Today'));
      }
    }

    // Medication confirmation
    final med = agentResults['medication'] as Map<String, dynamic>? ?? {};
    if (med['invoked'] == true) {
      final output = med['output'] as Map<String, dynamic>? ?? {};
      if (output['window_taken'] == true) {
        alerts.add(const Alert(type: AlertType.info, message: 'Medication confirmed for current window.', time: 'Today'));
      }
    }

    if (alerts.isEmpty) {
      alerts.add(const Alert(type: AlertType.info, message: 'All systems normal. No alerts.', time: 'Today'));
    }

    return alerts;
  }

  /// Generate dose log entries from scenario data.
  static DoseLog getDoseLogFromData(Map<String, dynamic> healthData) {
    final personaMeds = healthData['persona_medications'] as List? ?? [];
    final takenToday = healthData['medication_taken_today'] as Map<String, dynamic>? ?? {};
    final windows = ['morning', 'afternoon', 'evening'];
    final entries = <DoseEntry>[];

    for (var i = 0; i < personaMeds.length && i < 3; i++) {
      final pm = personaMeds[i] as Map;
      final window = i < windows.length ? windows[i] : 'morning';
      final taken = takenToday[window] as bool? ?? false;
      entries.add(DoseEntry(
        medName: pm['name'] as String? ?? 'Medication',
        scheduledTime: pm['scheduled_time'] as String? ?? '',
        takenAt: taken ? pm['scheduled_time'] as String? : null,
        status: taken ? DoseStatus.taken : DoseStatus.pending,
      ));
    }

    return DoseLog(date: '2026-03-15', entries: entries);
  }

  /// Generate call history from calling agent output.
  static List<Map<String, String>> getCallHistoryFromAgentResults(
    Map<String, dynamic> agentResults,
    String seniorName,
  ) {
    final calls = <Map<String, String>>[];
    final calling = agentResults['calling'] as Map<String, dynamic>? ?? {};
    if (calling['invoked'] == true) {
      final output = calling['output'] as Map<String, dynamic>? ?? {};
      final reasons = (output['reasons'] as List?)?.join(', ') ?? 'Wellness check';
      final contact = output['contact'] as Map<String, dynamic>? ?? {};
      calls.add({
        'time': 'Now',
        'target': seniorName,
        'reason': reasons,
        'duration': '0:34',
        'outcome': 'Attempted',
      });
      if (contact.isNotEmpty) {
        calls.add({
          'time': 'Now',
          'target': '${contact['name']} (Family)',
          'reason': 'Family alert: $reasons',
          'duration': '0:15',
          'outcome': 'Notified',
        });
      }
    }
    // Add a default history entry
    calls.add({
      'time': '9:15 AM',
      'target': seniorName,
      'reason': 'Morning wellness check',
      'duration': '1:12',
      'outcome': 'All good',
    });
    return calls;
  }
}
