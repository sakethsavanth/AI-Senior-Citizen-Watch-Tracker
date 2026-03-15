import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/agent_simulator.dart';
import '../data/scenario_provider.dart';
import '../data/synthetic_scenarios.dart';
import '../models/medication.dart';
import '../models/alert.dart';
import '../models/dose_log.dart';
import '../models/health_data.dart';

/// API service that reads from scenario providers + AgentSimulator.
class ApiService {
  final Ref _ref;

  ApiService(this._ref);

  Map<String, dynamic> get _healthData => _ref.read(scenarioHealthDataProvider);
  Map<String, dynamic> get _triage => _ref.read(triageResultProvider);
  Map<String, dynamic> get _agentResults => _ref.read(agentResultsProvider);
  Map<String, dynamic> get _persona => _ref.read(currentPersonaDataProvider);
  Map<String, dynamic> get _rawScenario => _ref.read(rawScenarioProvider);

  HealthData getSeniorHealth() {
    return HealthData.fromMap(_healthData, risk: _triage['overall_risk'] as String);
  }

  List<Medication> getMedications() {
    final personaMeds = _persona['medications'] as List?;
    final pillCount = _healthData['pill_count'] as int? ?? 30;
    final medTaken = _healthData['medication_taken_today'] as Map<String, dynamic>?;

    if (personaMeds == null) return [];

    final windows = ['morning', 'afternoon', 'evening'];
    return List.generate(personaMeds.length.clamp(0, 3), (i) {
      final pm = personaMeds[i] as Map<String, dynamic>;
      final window = i < windows.length ? windows[i] : 'morning';
      final taken = medTaken?[window] as bool? ?? false;

      DoseStatus status;
      String? takenAt;
      if (taken) {
        status = DoseStatus.taken;
        takenAt = pm['scheduled_time'] as String?;
      } else {
        // If the window has passed, it's missed; otherwise pending
        final hour = DateTime.now().hour;
        final windowHours = {'morning': 10, 'afternoon': 14, 'evening': 21};
        final windowEnd = windowHours[window] ?? 24;
        status = hour >= windowEnd ? DoseStatus.missed : DoseStatus.pending;
      }

      final pills = i == 0 ? pillCount : (pillCount * 1.5).round();
      if (pills < 5 && status != DoseStatus.taken) status = DoseStatus.low;

      return Medication(
        id: pm['id'] as String? ?? 'med_$i',
        name: pm['name'] as String? ?? 'Unknown',
        dosage: pm['dosage'] as String? ?? '',
        scheduledTime: pm['scheduled_time'] as String? ?? '',
        pillsRemaining: i == 0 ? pillCount : pills,
        status: status,
        takenAt: takenAt,
      );
    });
  }

  List<Alert> getAlerts() {
    final alerts = <Alert>[];
    final flags = _triage['critical_flags'] as List? ?? [];
    final agentResults = _agentResults['agent_results'] as Map<String, dynamic>? ?? {};

    for (final flag in flags) {
      switch (flag) {
        case 'fall_detected':
          alerts.add(const Alert(type: AlertType.critical, message: 'Fall detected! Emergency response initiated.', time: 'Now', hasCta: true, ctaLabel: 'Call Now'));
        case 'tachycardia':
          alerts.add(Alert(type: AlertType.critical, message: 'High heart rate: ${_healthData['heart_rate']} bpm', time: 'Now', hasCta: true, ctaLabel: 'Call Dad Now'));
        case 'bradycardia':
          alerts.add(Alert(type: AlertType.critical, message: 'Low heart rate: ${_healthData['heart_rate']} bpm', time: 'Now', hasCta: true, ctaLabel: 'Call Dad Now'));
        case 'hypoxemia':
          alerts.add(Alert(type: AlertType.critical, message: 'Low SpO2: ${_healthData['spo2']}%', time: 'Now', hasCta: true, ctaLabel: 'Call Dad Now'));
        case 'low_mood':
          alerts.add(const Alert(type: AlertType.aiAction, message: 'Low mood detected. AI wellness check initiated.', time: 'Today'));
        case 'poor_sleep':
          alerts.add(Alert(type: AlertType.warning, message: 'Poor sleep: ${_healthData['sleep_hours']}h. Family alerted.', time: 'Today'));
        case 'low_hrv':
          alerts.add(Alert(type: AlertType.warning, message: 'Low HRV: ${_healthData['hrv_percent']}%. Doctor visit suggested.', time: 'Today'));
        case 'refill_needed':
          alerts.add(Alert(type: AlertType.warning, message: '${_healthData['medication_name']}: ${_healthData['pill_count']} pills left. Refill ordered.', time: 'Today'));
        case 'medication_depleted':
          alerts.add(Alert(type: AlertType.critical, message: '${_healthData['medication_name']} depleted! Urgent refill needed.', time: 'Now', hasCta: true, ctaLabel: 'Order Refill'));
        case '3day_miss':
          alerts.add(const Alert(type: AlertType.warning, message: '3+ consecutive days of missed doses.', time: 'Today'));
      }
    }

    // Add info alerts from adherence
    if (agentResults.containsKey('Medication')) {
      final medResult = agentResults['Medication'] as Map<String, dynamic>;
      final adherence = medResult['adherence_today'] as Map<String, dynamic>?;
      if (adherence != null) {
        final taken = adherence['taken'] as List? ?? [];
        for (final window in taken) {
          alerts.add(Alert(type: AlertType.info, message: '${window[0].toUpperCase()}${(window as String).substring(1)} medication confirmed.', time: 'Today'));
        }
      }
    }

    if (alerts.isEmpty) {
      alerts.add(const Alert(type: AlertType.info, message: 'All clear. Vitals normal, medications on track.', time: 'Today'));
    }

    return alerts;
  }

  DoseLog getDoseLog({int dayIndex = 0}) {
    final medTaken = _healthData['medication_taken_today'] as Map<String, dynamic>?;
    final personaMeds = _persona['medications'] as List? ?? [];
    final entries = <DoseEntry>[];

    if (medTaken != null && personaMeds.isNotEmpty) {
      final windowMeds = {'morning': 0, 'afternoon': 1, 'evening': 2};
      for (final entry in windowMeds.entries) {
        if (entry.value < personaMeds.length) {
          final med = personaMeds[entry.value] as Map<String, dynamic>;
          final taken = medTaken[entry.key] as bool? ?? false;
          entries.add(DoseEntry(
            medName: med['name'] as String? ?? 'Unknown',
            scheduledTime: med['scheduled_time'] as String? ?? '',
            takenAt: taken ? med['scheduled_time'] as String? : null,
            status: taken ? DoseStatus.taken : DoseStatus.missed,
            aiNote: !taken ? 'AI reminder sent' : null,
          ));
        }
      }
    }

    return DoseLog(date: '2026-03-15', entries: entries);
  }

  List<DoseLog> getWeekDoseLogs() {
    final scenario = _rawScenario;
    if (scenario.containsKey('days')) {
      final days = scenario['days'] as List;
      final personaMeds = _persona['medications'] as List? ?? [];
      return List.generate(days.length, (i) {
        final day = days[i] as Map<String, dynamic>;
        final medTaken = day['medication_taken_today'] as Map<String, dynamic>?;
        final entries = <DoseEntry>[];
        if (medTaken != null) {
          final windowMeds = {'morning': 0, 'afternoon': 1, 'evening': 2};
          for (final entry in windowMeds.entries) {
            if (entry.value < personaMeds.length) {
              final med = personaMeds[entry.value] as Map<String, dynamic>;
              final taken = medTaken[entry.key] as bool? ?? false;
              entries.add(DoseEntry(
                medName: med['name'] as String? ?? 'Unknown',
                scheduledTime: med['scheduled_time'] as String? ?? '',
                takenAt: taken ? med['scheduled_time'] as String? : null,
                status: taken ? DoseStatus.taken : DoseStatus.missed,
              ));
            }
          }
        }
        return DoseLog(date: day['date'] as String? ?? '2026-03-${9 + i}', entries: entries);
      });
    }
    return [getDoseLog()];
  }

  List<Map<String, dynamic>> getCallHistory() {
    final agentResults = _agentResults['agent_results'] as Map<String, dynamic>? ?? {};
    final calls = <Map<String, dynamic>>[];
    final personaName = _persona['name'] as String? ?? 'Senior';

    if (agentResults.containsKey('Calling')) {
      final calling = agentResults['Calling'] as Map<String, dynamic>;
      if (calling['action_taken'] == true) {
        final reasons = calling['reasons'] as List? ?? [];
        calls.add({
          'time': 'Now',
          'target': personaName,
          'reason': reasons.join(', '),
          'duration': '0:45',
          'outcome': calling['escalation'] != null ? 'Emergency' : 'Completed',
        });
      }
    }

    // Add some standard calls
    calls.add({'time': '10:00 AM', 'target': personaName, 'reason': 'Morning wellness check', 'duration': '1:12', 'outcome': 'All good'});
    calls.add({'time': 'Yesterday', 'target': personaName, 'reason': 'Medication reminder', 'duration': '0:28', 'outcome': 'Confirmed'});

    return calls;
  }

  Map<String, dynamic> getWeeklySummary() {
    final scenario = _rawScenario;
    if (scenario.containsKey('days')) {
      final days = scenario['days'] as List;
      double avgHr = 0, avgSpo2 = 0, avgSleep = 0, avgSteps = 0;
      for (final d in days) {
        final day = d as Map<String, dynamic>;
        avgHr += (day['heart_rate'] as int? ?? 0);
        avgSpo2 += (day['spo2'] as int? ?? 0);
        avgSleep += (day['sleep_hours'] as num? ?? 0).toDouble();
        avgSteps += (day['steps'] as int? ?? 0);
      }
      final n = days.length;
      return {
        'avg_hr': (avgHr / n).round(),
        'avg_spo2': (avgSpo2 / n).round(),
        'avg_sleep': double.parse((avgSleep / n).toStringAsFixed(1)),
        'avg_steps': '${(avgSteps / n / 1000).toStringAsFixed(1)}k',
        'adherence_pct': 85,
        'ai_summary': 'Declining trend observed over 7 days. HR rising, sleep decreasing. Close monitoring recommended.',
        'weekly_steps': days.map((d) => (d as Map)['steps'] as int? ?? 0).toList(),
      };
    }
    // Single-day scenario: extrapolate
    final h = _healthData;
    return {
      'avg_hr': h['heart_rate'] ?? 72,
      'avg_spo2': h['spo2'] ?? 98,
      'avg_sleep': h['sleep_hours'] ?? 7.0,
      'avg_steps': '${((h['steps'] as int? ?? 3000) / 1000).toStringAsFixed(1)}k',
      'adherence_pct': 95,
      'ai_summary': _triage['overall_risk'] == 'low'
          ? 'Stable week. Good vitals and medication adherence.'
          : 'Some concerns detected. Review alerts for details.',
      'weekly_steps': List.generate(7, (_) => h['steps'] as int? ?? 3000),
    };
  }
}

/// Provider for ApiService
final apiServiceProvider = Provider<ApiService>((ref) => ApiService(ref));

