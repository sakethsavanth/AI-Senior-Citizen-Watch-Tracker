/// Pure Dart simulator mirroring every backend agent tool.
/// Uses the same thresholds as the Python backend.

class AgentSimulator {
  // ─── Individual Tool Simulators ────────────────────────────

  static Map<String, dynamic> assessVitals(int heartRate, int spo2) {
    final issues = <String>[];
    if (heartRate < 50) issues.add('bradycardia');
    if (heartRate > 120) issues.add('tachycardia');
    if (spo2 < 92) issues.add('hypoxemia');
    return {
      'category': 'vitals',
      'heart_rate': heartRate,
      'spo2': spo2,
      'period': '24h',
      'status': issues.isEmpty ? 'normal' : 'critical',
      'issues': issues,
    };
  }

  static Map<String, dynamic> assessHrv(double hrvPercent) {
    return {
      'category': 'hrv',
      'hrv_percent': hrvPercent,
      'status': hrvPercent < 40 ? 'low' : 'normal',
      'below_threshold': hrvPercent < 40,
    };
  }

  static Map<String, dynamic> assessFall(bool fallDetected) {
    return {
      'category': 'fall',
      'fall_detected': fallDetected,
      'status': fallDetected ? 'critical' : 'normal',
    };
  }

  static Map<String, dynamic> assessSleep(double sleepHours) {
    String quality;
    if (sleepHours < 4) {
      quality = 'poor';
    } else if (sleepHours < 6) {
      quality = 'fair';
    } else {
      quality = 'good';
    }
    return {
      'category': 'sleep',
      'sleep_hours': sleepHours,
      'quality': quality,
      'below_threshold': sleepHours < 6,
    };
  }

  static Map<String, dynamic> assessActivity(int steps, int lastMovementMinutes) {
    String status;
    if (lastMovementMinutes > 360) {
      status = 'critical';
    } else if (lastMovementMinutes > 240) {
      status = 'sedentary';
    } else {
      status = 'active';
    }
    return {
      'category': 'activity',
      'steps': steps,
      'last_movement_minutes': lastMovementMinutes,
      'status': status,
      'inactive_flag': lastMovementMinutes > 240,
    };
  }

  static Map<String, dynamic> assessMedication(int pillCount, int dosesMissedConsecutiveDays, String medicationName) {
    String status;
    if (pillCount == 0) {
      status = 'depleted';
    } else if (pillCount < 3) {
      status = 'low';
    } else {
      status = 'sufficient';
    }
    return {
      'category': 'medication',
      'pill_count': pillCount,
      'medication_name': medicationName,
      'status': status,
      'refill_needed': pillCount < 3,
      'refill_3day_miss': dosesMissedConsecutiveDays >= 3,
    };
  }

  static Map<String, dynamic> getCurrentMedWindow() {
    final hour = DateTime.now().hour;
    String? window;
    String label = '';
    int hourStart = 0, hourEnd = 0;

    if (hour >= 7 && hour < 10) {
      window = 'morning';
      label = 'Morning (7-10 AM)';
      hourStart = 7;
      hourEnd = 10;
    } else if (hour >= 12 && hour < 14) {
      window = 'afternoon';
      label = 'Afternoon (12-2 PM)';
      hourStart = 12;
      hourEnd = 14;
    } else if (hour >= 18 && hour < 21) {
      window = 'evening';
      label = 'Evening (6-9 PM)';
      hourStart = 18;
      hourEnd = 21;
    } else if (hour >= 21 && hour < 23) {
      window = 'night';
      label = 'Night (9-11 PM)';
      hourStart = 21;
      hourEnd = 23;
    }
    return {
      'window': window,
      'label': label,
      'hour_start': hourStart,
      'hour_end': hourEnd,
      'current_hour': hour,
    };
  }

  static Map<String, dynamic> requestPharmacyRefill(String userId, String medication, int quantity) {
    return {
      'status': 'simulated',
      'order_id': 'SIM-$userId-001',
      'estimated_delivery': '2-3 business days',
    };
  }

  static Map<String, dynamic> assessMood(double? moodScore) {
    if (moodScore == null) {
      return {
        'category': 'mood',
        'mood_score': null,
        'status': 'unknown',
        'low_mood': false,
        'trigger_call': false,
      };
    }
    return {
      'category': 'mood',
      'mood_score': moodScore,
      'status': moodScore < 3.0 ? 'low' : 'ok',
      'low_mood': moodScore < 3.0,
      'trigger_call': moodScore < 3.0,
    };
  }

  static Map<String, dynamic> buildMoodRecommendations(double? moodScore, int steps, double sleepHours) {
    final recs = <String>[];
    final mood = moodScore ?? 5.0;
    if (mood < 3.0) {
      recs.add('Consider calling a family member for a chat');
      recs.add('Listen to some gentle music');
    } else if (mood < 4.0) {
      recs.add('A short chat with family could brighten your day');
    }
    if (steps < 1000) {
      recs.add('A short stroll around the house could help');
    } else if (steps < 3000) {
      recs.add('Try to walk a bit more today');
    }
    if (sleepHours < 4) {
      recs.add('Consider a short nap — you slept very little');
    } else if (sleepHours < 6) {
      recs.add('Try an earlier bedtime routine tonight');
    }
    if (recs.isEmpty) {
      recs.add("You're doing great — keep it up!");
    }
    String summary;
    if (mood < 3.0 || sleepHours < 4) {
      summary = 'low';
    } else if (mood < 4.0 || sleepHours < 6 || steps < 1000) {
      summary = 'fair';
    } else {
      summary = 'good';
    }
    return {
      'mood_score': moodScore,
      'recommendations': recs,
      'wellness_summary': summary,
    };
  }

  static Map<String, dynamic> callSenior(String toNumber, String message) {
    return {'call_sid': 'SIMULATED', 'status': 'simulated', 'to': toNumber};
  }

  static Map<String, dynamic> alertFamilySms(String message, String familyNumber) {
    return {'message_sid': 'SIMULATED', 'status': 'simulated', 'to': familyNumber};
  }

  static Map<String, dynamic> emergencyEscalation(String seniorNumber, String familyNumber, String reason) {
    return {
      'call': {'call_sid': 'SIMULATED', 'status': 'simulated', 'to': seniorNumber},
      'sms': {'message_sid': 'SIMULATED', 'status': 'simulated', 'to': familyNumber},
    };
  }

  static Map<String, dynamic> pickFamilyContact(List<Map<String, dynamic>> familyContacts) {
    if (familyContacts.isEmpty) {
      return {'name': 'Unknown', 'phone': '', 'last_contact_iso': '', 'reason': 'no contacts available'};
    }
    final sorted = List<Map<String, dynamic>>.from(familyContacts)
      ..sort((a, b) => (a['last_contact_iso'] as String).compareTo(b['last_contact_iso'] as String));
    final pick = sorted.first;
    return {
      'name': pick['name'],
      'phone': pick['phone'],
      'last_contact_iso': pick['last_contact_iso'],
      'reason': 'least recently contacted',
    };
  }

  static Map<String, dynamic> getMedicationInteractions(List<String> medications) {
    return {
      'medications': medications,
      'interactions': <String>[],
      'note': 'No known interactions (stub)',
    };
  }

  static Map<String, dynamic> getLabSummary(String userId) {
    return {
      'user_id': userId,
      'last_updated': 'stub',
      'summary': 'No new lab results. A1C within range (stub).',
    };
  }

  static Map<String, dynamic> getVisitPrep(String userId) {
    return {
      'user_id': userId,
      'checklist': [
        'Bring blood pressure log.',
        'Bring medication list.',
        'List symptoms since last visit.',
      ],
    };
  }

  static Map<String, dynamic> buildFamilyDashboard(Map<String, dynamic> healthData) {
    return {
      'user_id': healthData['user_id'] ?? '',
      'vitals_24h': {
        'heart_rate': healthData['heart_rate'],
        'spo2': healthData['spo2'],
        'hrv_percent': healthData['hrv_percent'],
      },
      'medication': healthData['medication_name'] ?? '',
      'pill_count': healthData['pill_count'],
      'next_checkup': 'Mar 20 (stub)',
    };
  }

  // ─── Full Health Assessment (Triage) ───────────────────────

  static Map<String, dynamic> fullHealthAssessment(Map<String, dynamic> h) {
    final vitals = assessVitals(
      (h['heart_rate'] as num).toInt(),
      (h['spo2'] as num).toInt(),
    );
    final hrv = assessHrv((h['hrv_percent'] as num).toDouble());
    final fall = assessFall(h['fall_detected'] as bool? ?? false);
    final sleep = assessSleep((h['sleep_hours'] as num).toDouble());
    final activity = assessActivity(
      (h['steps'] as num).toInt(),
      (h['last_movement_minutes'] as num).toInt(),
    );
    final medication = assessMedication(
      (h['pill_count'] as num).toInt(),
      (h['doses_missed_consecutive_days'] as num?)?.toInt() ?? 0,
      h['medication_name'] as String? ?? '',
    );
    final mood = assessMood((h['mood_score'] as num?)?.toDouble());

    final assessments = [vitals, hrv, fall, sleep, activity, medication, mood];

    final criticalFlags = <String>[];
    if (vitals['status'] == 'critical') criticalFlags.add('vitals_critical');
    if (hrv['status'] == 'low') criticalFlags.add('hrv_low');
    if (fall['status'] == 'critical') criticalFlags.add('fall_detected');
    if (sleep['quality'] == 'poor') criticalFlags.add('sleep_poor');
    if (activity['status'] == 'critical') criticalFlags.add('activity_critical');
    if (medication['status'] == 'depleted') criticalFlags.add('medication_depleted');
    if (mood['low_mood'] == true) criticalFlags.add('mood_low');

    String overallRisk;
    if (criticalFlags.length >= 2 || fall['fall_detected'] == true) {
      overallRisk = 'high';
    } else if (criticalFlags.length == 1) {
      overallRisk = 'medium';
    } else {
      overallRisk = 'low';
    }

    return {
      'user_id': h['user_id'] ?? '',
      'overall_risk': overallRisk,
      'assessments': assessments,
      'critical_flags': criticalFlags,
    };
  }

  // ─── Agent-Level Simulators ────────────────────────────────

  static Map<String, dynamic> simulateVitalSync(Map<String, dynamic> h) {
    final vitals = assessVitals((h['heart_rate'] as num).toInt(), (h['spo2'] as num).toInt());
    final hrv = assessHrv((h['hrv_percent'] as num).toDouble());
    final fall = assessFall(h['fall_detected'] as bool? ?? false);
    final isCritical = vitals['status'] == 'critical' || hrv['status'] == 'low' || fall['status'] == 'critical';
    return {
      'severity': isCritical ? 'critical' : 'normal',
      'daily_message': isCritical ? 'Vital signs require attention.' : 'All vitals within normal range.',
      'alert_family': isCritical,
      'emergency_action_taken': fall['fall_detected'] == true,
      'assessments': [vitals, hrv, fall],
    };
  }

  static Map<String, dynamic> simulateMedicine(Map<String, dynamic> h) {
    final med = assessMedication(
      (h['pill_count'] as num).toInt(),
      (h['doses_missed_consecutive_days'] as num?)?.toInt() ?? 0,
      h['medication_name'] as String? ?? '',
    );
    final refillTriggered = med['refill_needed'] == true || med['refill_3day_miss'] == true;
    Map<String, dynamic>? refillResult;
    if (refillTriggered) {
      refillResult = requestPharmacyRefill(h['user_id'] as String? ?? '', med['medication_name'] as String, 30);
    }
    return {
      'medication_status': med,
      'refill_triggered': refillTriggered,
      'refill_result': refillResult,
    };
  }

  static Map<String, dynamic> simulateMedication(Map<String, dynamic> h) {
    final medWindow = getCurrentMedWindow();
    final takenToday = h['medication_taken_today'] as Map<String, dynamic>? ?? {};
    final windowName = medWindow['window'] as String?;
    final taken = windowName != null ? (takenToday[windowName] as bool? ?? false) : false;
    return {
      'current_window': medWindow,
      'window_taken': taken,
      'pill_count': h['pill_count'],
      'adherence_note': taken ? 'Dose confirmed for current window.' : (windowName != null ? 'Dose pending for $windowName window.' : 'No medication window active.'),
    };
  }

  static Map<String, dynamic> simulateRefill(Map<String, dynamic> h) {
    final pillCount = (h['pill_count'] as num).toInt();
    final missed = (h['doses_missed_consecutive_days'] as num?)?.toInt() ?? 0;
    final needed = pillCount < 3 || missed >= 3;
    Map<String, dynamic>? result;
    if (needed) {
      result = requestPharmacyRefill(h['user_id'] as String? ?? '', h['medication_name'] as String? ?? '', 30);
    }
    return {
      'refill_needed': needed,
      'reason': needed ? (pillCount < 3 ? 'Low pill count ($pillCount)' : '3+ consecutive missed days') : 'Sufficient supply',
      'refill_result': result,
    };
  }

  static Map<String, dynamic> simulateEmoCare(Map<String, dynamic> h) {
    final moodScore = (h['mood_score'] as num?)?.toDouble();
    final mood = assessMood(moodScore);
    final recs = buildMoodRecommendations(
      moodScore,
      (h['steps'] as num).toInt(),
      (h['sleep_hours'] as num).toDouble(),
    );
    return {
      'mood_assessment': mood,
      'recommendations': recs,
      'trigger_call': mood['trigger_call'] ?? false,
    };
  }

  static Map<String, dynamic> simulateCalling(Map<String, dynamic> h, List<Map<String, dynamic>> familyContacts, String emergencyContact) {
    final fall = h['fall_detected'] as bool? ?? false;
    final hr = (h['heart_rate'] as num).toInt();
    final spo2 = (h['spo2'] as num).toInt();
    final hrv = (h['hrv_percent'] as num).toDouble();
    final mood = (h['mood_score'] as num?)?.toDouble();
    final reasons = <String>[];
    if (fall) reasons.add('Fall detected');
    if (hr < 50 || hr > 120) reasons.add('Heart rate anomaly');
    if (spo2 < 92) reasons.add('Low SpO2');
    if (hrv < 40) reasons.add('Low HRV');
    if (mood != null && mood < 3.0) reasons.add('Low mood');

    if (reasons.isEmpty) {
      return {'invoked': false, 'reason': 'No calling triggers met'};
    }

    final contact = pickFamilyContact(familyContacts);
    Map<String, dynamic>? escalation;
    if (fall) {
      escalation = emergencyEscalation(emergencyContact, contact['phone'] as String, reasons.join(', '));
    }
    return {
      'invoked': true,
      'reasons': reasons,
      'contact': contact,
      'escalation': escalation,
      'call_result': callSenior(emergencyContact, 'Wellness check: ${reasons.join(', ')}'),
      'sms_result': alertFamilySms('Alert: ${reasons.join(', ')}', contact['phone'] as String),
    };
  }

  static Map<String, dynamic> simulateActivity(Map<String, dynamic> h) {
    final activity = assessActivity(
      (h['steps'] as num).toInt(),
      (h['last_movement_minutes'] as num).toInt(),
    );
    final lastMins = (h['last_movement_minutes'] as num).toInt();
    return {
      'activity_assessment': activity,
      'alert': lastMins > 240 ? 'No movement for ${lastMins ~/ 60}h ${lastMins % 60}m' : null,
    };
  }

  static Map<String, dynamic> simulateSleep(Map<String, dynamic> h) {
    final sleep = assessSleep((h['sleep_hours'] as num).toDouble());
    return {
      'sleep_assessment': sleep,
      'recommendation': sleep['quality'] == 'poor'
          ? 'Very low sleep — consider a nap and earlier bedtime.'
          : sleep['quality'] == 'fair'
              ? 'Below target — try an earlier bedtime routine.'
              : 'Good sleep. Keep it up!',
    };
  }

  static Map<String, dynamic> simulateHealthRecords(Map<String, dynamic> h) {
    final userId = h['user_id'] as String? ?? '';
    final medName = h['medication_name'] as String? ?? '';
    return {
      'medication_interactions': getMedicationInteractions([medName]),
      'lab_summary': getLabSummary(userId),
      'visit_prep': getVisitPrep(userId),
      'family_dashboard': buildFamilyDashboard(h),
    };
  }

  // ─── Run All Agents (Orchestrator Routing) ─────────────────

  static Map<String, dynamic> runAllAgents(Map<String, dynamic> h, List<Map<String, dynamic>> familyContacts, String emergencyContact) {
    final results = <String, dynamic>{};
    final triage = fullHealthAssessment(h);
    results['triage'] = triage;

    // Always invoked
    results['vital_sync'] = {'invoked': true, 'output': simulateVitalSync(h)};
    results['medicine'] = {'invoked': true, 'output': simulateMedicine(h)};
    results['medication'] = {'invoked': true, 'output': simulateMedication(h)};
    results['health_records'] = {'invoked': true, 'output': simulateHealthRecords(h)};

    // Conditional: Activity if steps<500 or idle>240
    final steps = (h['steps'] as num).toInt();
    final idle = (h['last_movement_minutes'] as num).toInt();
    final activityInvoked = steps < 500 || idle > 240;
    results['activity'] = activityInvoked
        ? {'invoked': true, 'output': simulateActivity(h)}
        : {'invoked': false, 'output': null};

    // Conditional: Sleep if sleep<6
    final sleepH = (h['sleep_hours'] as num).toDouble();
    final sleepInvoked = sleepH < 6;
    results['sleep'] = sleepInvoked
        ? {'invoked': true, 'output': simulateSleep(h)}
        : {'invoked': false, 'output': null};

    // Conditional: EmoCare if mood_score present
    final moodPresent = h['mood_score'] != null;
    results['emo_care'] = moodPresent
        ? {'invoked': true, 'output': simulateEmoCare(h)}
        : {'invoked': false, 'output': null};

    // Conditional: Refill if pills<3 or missed≥3
    final pills = (h['pill_count'] as num).toInt();
    final missed = (h['doses_missed_consecutive_days'] as num?)?.toInt() ?? 0;
    final refillInvoked = pills < 3 || missed >= 3;
    results['refill'] = refillInvoked
        ? {'invoked': true, 'output': simulateRefill(h)}
        : {'invoked': false, 'output': null};

    // Conditional: Calling if fall/HR anomaly/SpO2<92/HRV<40/mood<3
    final callingResult = simulateCalling(h, familyContacts, emergencyContact);
    results['calling'] = callingResult['invoked'] == true
        ? {'invoked': true, 'output': callingResult}
        : {'invoked': false, 'output': null};

    return results;
  }
}
