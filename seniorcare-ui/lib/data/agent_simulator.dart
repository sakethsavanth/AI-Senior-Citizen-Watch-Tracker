/// Pure-Dart agent simulator mirroring every backend tool function.
/// Uses the same thresholds as the Python railtracks tools.

class AgentSimulator {
  // ─── Vitals Tools ───

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

  static Map<String, dynamic> assessHrv(double? hrvPercent) {
    if (hrvPercent == null) {
      return {'category': 'hrv', 'hrv_percent': null, 'status': 'unknown', 'below_threshold': false};
    }
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
    bool below;
    bool alertFamily;
    if (sleepHours < 4) {
      quality = 'poor';
      below = true;
      alertFamily = true;
    } else if (sleepHours < 6) {
      quality = 'fair';
      below = true;
      alertFamily = false;
    } else {
      quality = 'good';
      below = false;
      alertFamily = false;
    }
    return {
      'category': 'sleep',
      'sleep_hours': sleepHours,
      'quality': quality,
      'below_threshold': below,
      'alert_family': alertFamily,
    };
  }

  static Map<String, dynamic> sleepHrCorrelation(double sleepHours, int heartRate) {
    final sleep = assessSleep(sleepHours);
    String note = 'No notable correlation.';
    String rec = 'Continue monitoring.';
    if (sleep['quality'] == 'poor' && heartRate > 90) {
      note = 'Poor sleep may explain elevated heart rate.';
      rec = 'Prioritize rest. Consider relaxation before bed.';
    } else if (sleep['quality'] == 'poor') {
      note = 'Poor sleep detected but heart rate stable.';
      rec = 'Improve sleep hygiene.';
    }
    return {
      'sleep_hours': sleepHours,
      'heart_rate': heartRate,
      'correlation_note': note,
      'recommendation': rec,
    };
  }

  static Map<String, dynamic> assessActivity(int steps, int lastMovementMinutes) {
    String status;
    bool inactiveFlag;
    bool alertFamily;
    String rec = '';
    if (lastMovementMinutes > 360) {
      status = 'critical';
      inactiveFlag = true;
      alertFamily = true;
      rec = 'No movement detected for over 6 hours. Welfare check recommended.';
    } else if (lastMovementMinutes > 240) {
      status = 'sedentary';
      inactiveFlag = true;
      alertFamily = false;
      rec = 'Extended inactivity. Gentle movement suggested.';
    } else {
      status = 'active';
      inactiveFlag = false;
      alertFamily = false;
    }
    if (steps < 500) {
      rec = rec.isEmpty ? 'Very low step count. Please try a short walk.' : rec;
    } else if (steps < 1000) {
      rec = rec.isEmpty ? 'Below average steps. A light stroll may help.' : rec;
    }
    return {
      'category': 'activity',
      'steps': steps,
      'last_movement_minutes': lastMovementMinutes,
      'status': status,
      'inactive_flag': inactiveFlag,
      'alert_family': alertFamily,
      'recommendation': rec,
    };
  }

  // ─── Medication Tools ───

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
    int hourStart = 0;
    int hourEnd = 0;

    if (hour >= 7 && hour < 10) {
      window = 'morning';
      label = 'Morning';
      hourStart = 7;
      hourEnd = 10;
    } else if (hour >= 12 && hour < 14) {
      window = 'afternoon';
      label = 'Afternoon';
      hourStart = 12;
      hourEnd = 14;
    } else if (hour >= 18 && hour < 21) {
      window = 'evening';
      label = 'Evening';
      hourStart = 18;
      hourEnd = 21;
    } else if (hour >= 21 && hour < 23) {
      window = 'night';
      label = 'Night';
      hourStart = 21;
      hourEnd = 23;
    }

    return {
      'window': window,
      'label': window != null ? label : 'No active window',
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

  static Map<String, dynamic> shouldRefill(int pillCount, int dosesMissedConsecutiveDays) {
    bool refillNeeded = pillCount < 3 || dosesMissedConsecutiveDays >= 3;
    String urgency;
    String reason;
    if (pillCount == 0) {
      urgency = 'high';
      reason = 'No pills remaining. Immediate refill required.';
    } else if (refillNeeded) {
      urgency = 'medium';
      reason = pillCount < 3
          ? 'Low pill count ($pillCount remaining).'
          : '$dosesMissedConsecutiveDays consecutive days missed.';
    } else {
      urgency = 'low';
      reason = 'Adequate supply.';
    }
    return {
      'refill_needed': refillNeeded,
      'reason': reason,
      'urgency': urgency,
    };
  }

  static Map<String, dynamic> computeAdherenceToday(Map<String, bool> medicationTakenToday) {
    final taken = <String>[];
    final missed = <String>[];
    medicationTakenToday.forEach((window, wasTaken) {
      if (wasTaken) {
        taken.add(window);
      } else {
        missed.add(window);
      }
    });
    final total = medicationTakenToday.length;
    final pct = total > 0 ? ((taken.length / total) * 100).round() : 0;
    return {
      'taken': taken,
      'missed': missed,
      'adherence_pct': pct,
      'summary': '$pct% adherence today (${taken.length}/$total windows).',
    };
  }

  static Map<String, dynamic> buildMedicationReminder(Map<String, dynamic> healthData) {
    final window = getCurrentMedWindow();
    final medName = (healthData['medication_name'] as String?) ?? 'your medication';
    final pillCount = (healthData['pill_count'] as int?) ?? 0;
    final windowLabel = window['label'] as String;
    return {
      'message': 'Reminder: Please take your $medName ($windowLabel dose). You have $pillCount pills remaining.',
      'window': window['window'],
      'medication_name': medName,
      'pill_count': pillCount,
    };
  }

  // ─── Mood Tools ───

  static Map<String, dynamic> assessMood(double? moodScore) {
    if (moodScore == null) {
      return {'category': 'mood', 'mood_score': null, 'status': 'unknown', 'low_mood': false, 'trigger_call': false};
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
    String wellness;
    final mood = moodScore ?? 5.0;

    if (mood < 3) {
      recs.add('Consider calling a family member for support.');
      recs.add('Try listening to gentle, calming music.');
    } else if (mood < 4) {
      recs.add('A short chat with a loved one might brighten your day.');
    }
    if (steps < 1000) {
      recs.add('A gentle stroll around the house could help.');
    } else if (steps < 3000) {
      recs.add('Try to walk a bit more today.');
    }
    if (sleepHours < 4) {
      recs.add('Consider a short nap to recover energy.');
    } else if (sleepHours < 6) {
      recs.add('Try an earlier bedtime routine tonight.');
    }
    if (recs.isEmpty) {
      recs.add("You're doing great! Keep it up.");
    }

    if (mood < 3) {
      wellness = 'low';
    } else if (mood < 4 || steps < 2000 || sleepHours < 5) {
      wellness = 'fair';
    } else {
      wellness = 'good';
    }

    return {
      'mood_score': moodScore,
      'recommendations': recs,
      'wellness_summary': wellness,
    };
  }

  // ─── Communication Tools ───

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
      return {'name': 'Unknown', 'phone': '', 'last_contact_iso': '', 'reason': 'No contacts available'};
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

  // ─── Health Records Tools ───

  static Map<String, dynamic> getMedicationInteractions(List<String> medications) {
    final knownInteractions = <List<String>, String>{};
    // Static interaction list
    final interactionDb = [
      {'drug_a': 'ACE Inhibitor', 'drug_b': 'NSAID', 'warning': 'May reduce ACE inhibitor effectiveness and harm kidneys.'},
      {'drug_a': 'Warfarin', 'drug_b': 'Aspirin', 'warning': 'Increased bleeding risk.'},
      {'drug_a': 'Metformin', 'drug_b': 'Alcohol', 'warning': 'Risk of lactic acidosis.'},
      {'drug_a': 'ACE Inhibitor', 'drug_b': 'Potassium-sparing', 'warning': 'Risk of hyperkalemia.'},
    ];

    final found = <Map<String, dynamic>>[];
    for (final interaction in interactionDb) {
      final a = (interaction['drug_a'] as String).toLowerCase();
      final b = (interaction['drug_b'] as String).toLowerCase();
      final medsLower = medications.map((m) => m.toLowerCase()).toList();
      if (medsLower.any((m) => m.contains(a)) && medsLower.any((m) => m.contains(b))) {
        found.add(interaction);
      }
    }

    return {
      'medications': medications,
      'interactions': found,
      'interaction_count': found.length,
      'note': found.isEmpty ? 'No known interactions found.' : '${found.length} potential interaction(s) found.',
    };
  }

  static Map<String, dynamic> getLabSummary(String userId) {
    final labData = <String, Map<String, dynamic>>{
      'senior_001': {
        'user_id': 'senior_001',
        'last_updated': '2026-03-01',
        'results': {'a1c': '6.8%', 'cholesterol': '195 mg/dL', 'bp_avg': '128/82', 'note': 'HbA1c slightly above range'},
        'summary': 'All within range',
      },
      'senior_002': {
        'user_id': 'senior_002',
        'last_updated': '2026-03-01',
        'results': {'a1c': '6.2%', 'cholesterol': '210 mg/dL', 'bp_avg': '135/85', 'note': 'Cholesterol elevated'},
        'summary': 'A1C slightly elevated',
      },
      'senior_003': {
        'user_id': 'senior_003',
        'last_updated': '2026-03-01',
        'results': {'a1c': '5.4%', 'cholesterol': '180 mg/dL', 'bp_avg': '120/78', 'note': 'All normal'},
        'summary': 'Excellent',
      },
    };
    return labData[userId] ?? {
      'user_id': userId,
      'last_updated': '2026-03-01',
      'results': {'a1c': 'N/A', 'cholesterol': 'N/A', 'bp_avg': 'N/A', 'note': 'No data'},
      'summary': 'No data available',
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

  static Map<String, dynamic> getVisitPrepFromHealth(Map<String, dynamic> healthData) {
    final userId = (healthData['user_id'] as String?) ?? 'unknown';
    final checklist = <String>[
      'Bring blood pressure log.',
      'Bring medication list.',
      'List symptoms since last visit.',
    ];
    if (healthData['fall_detected'] == true) checklist.add('Report recent fall to doctor.');
    final hrv = healthData['hrv_percent'];
    if (hrv != null && hrv is num && hrv < 40) checklist.add('Discuss low HRV readings.');
    final sleep = healthData['sleep_hours'];
    if (sleep != null && sleep is num && sleep < 4) checklist.add('Discuss poor sleep quality.');
    final mood = healthData['mood_score'];
    if (mood != null && mood is num && mood < 3) checklist.add('Discuss low mood / mental wellness.');
    final pills = healthData['pill_count'];
    if (pills != null && pills is num && pills < 3) checklist.add('Request new prescription / refill.');
    final missed = healthData['doses_missed_consecutive_days'];
    if (missed != null && missed is num && missed >= 3) checklist.add('Discuss medication adherence issues.');
    return {
      'user_id': userId,
      'checklist': checklist,
    };
  }

  static Map<String, dynamic> buildFamilyDashboard(Map<String, dynamic> healthData) {
    final userId = (healthData['user_id'] as String?) ?? 'unknown';
    final hr = healthData['heart_rate'] as int? ?? 0;
    final spo2 = healthData['spo2'] as int? ?? 0;
    final hrvPercent = healthData['hrv_percent'];
    final sleepHours = (healthData['sleep_hours'] as num?)?.toDouble() ?? 0;
    final steps = healthData['steps'] as int? ?? 0;
    final medName = (healthData['medication_name'] as String?) ?? 'Unknown';
    final pillCount = healthData['pill_count'] as int? ?? 0;
    final fallDetected = healthData['fall_detected'] as bool? ?? false;
    final moodScore = healthData['mood_score'] as double?;

    final alerts = <Map<String, dynamic>>[];
    if (fallDetected) alerts.add({'type': 'critical', 'message': 'Fall detected! Immediate attention needed.'});
    if (hr < 50 || hr > 120) alerts.add({'type': 'critical', 'message': 'Abnormal heart rate: $hr bpm'});
    if (spo2 < 92) alerts.add({'type': 'critical', 'message': 'Low SpO2: $spo2%'});
    if (moodScore != null && moodScore < 3) alerts.add({'type': 'warning', 'message': 'Low mood detected (${moodScore.toStringAsFixed(1)})'});
    if (pillCount < 3) alerts.add({'type': 'warning', 'message': 'Low medication supply: $pillCount pills'});

    return {
      'user_id': userId,
      'vitals_24h': {'heart_rate': hr, 'spo2': spo2, 'hrv_percent': hrvPercent},
      'sleep_hours': sleepHours,
      'steps': steps,
      'medication': medName,
      'pill_count': pillCount,
      'alerts': alerts,
      'alert_count': alerts.length,
      'next_checkup': '2026-03-20',
    };
  }

  // ─── Full Health Assessment (triage) ───

  static Map<String, dynamic> fullHealthAssessment(Map<String, dynamic> healthData) {
    final userId = (healthData['user_id'] as String?) ?? 'unknown';
    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final steps = healthData['steps'] as int? ?? 0;
    final sleepHours = (healthData['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final lastMovement = healthData['last_movement_minutes'] as int? ?? 0;
    final hrvPercent = (healthData['hrv_percent'] as num?)?.toDouble();
    final fallDetected = healthData['fall_detected'] as bool? ?? false;
    final moodScore = (healthData['mood_score'] as num?)?.toDouble();
    final medName = (healthData['medication_name'] as String?) ?? 'Unknown';
    final missedDays = healthData['doses_missed_consecutive_days'] as int? ?? 0;

    final vitals = assessVitals(hr, spo2);
    final hrv = assessHrv(hrvPercent);
    final fall = assessFall(fallDetected);
    final sleep = assessSleep(sleepHours);
    final activity = assessActivity(steps, lastMovement);
    final medication = assessMedication(pillCount, missedDays, medName);
    final mood = assessMood(moodScore);

    final assessments = [vitals, hrv, fall, sleep, activity, medication, mood];

    // Count critical flags
    final criticalFlags = <String>[];
    if (vitals['status'] == 'critical') {
      for (final issue in (vitals['issues'] as List)) {
        criticalFlags.add(issue as String);
      }
    }
    if (fall['status'] == 'critical') criticalFlags.add('fall_detected');
    if (sleep['quality'] == 'poor') criticalFlags.add('poor_sleep');
    if (medication['status'] == 'depleted') criticalFlags.add('medication_depleted');
    if (medication['refill_needed'] == true) criticalFlags.add('refill_needed');
    if (medication['refill_3day_miss'] == true) criticalFlags.add('3day_miss');
    if (mood['low_mood'] == true) criticalFlags.add('low_mood');
    if (hrv['status'] == 'low') criticalFlags.add('low_hrv');

    String overallRisk;
    if (criticalFlags.length >= 2 || fallDetected) {
      overallRisk = 'high';
    } else if (criticalFlags.length == 1) {
      overallRisk = 'medium';
    } else {
      overallRisk = 'low';
    }

    return {
      'user_id': userId,
      'overall_risk': overallRisk,
      'assessments': assessments,
      'critical_flags': criticalFlags,
    };
  }

  // ─── Agent-Level Simulators ───

  static Map<String, dynamic> simulateVitalSync(Map<String, dynamic> healthData) {
    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final hrvPercent = (healthData['hrv_percent'] as num?)?.toDouble();
    final fallDetected = healthData['fall_detected'] as bool? ?? false;
    final sleepHours = (healthData['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final steps = healthData['steps'] as int? ?? 0;
    final lastMovement = healthData['last_movement_minutes'] as int? ?? 0;

    final vitals = assessVitals(hr, spo2);
    final hrv = assessHrv(hrvPercent);
    final fall = assessFall(fallDetected);
    final sleep = assessSleep(sleepHours);
    final activity = assessActivity(steps, lastMovement);

    bool alertFamily = fallDetected || sleep['alert_family'] == true || activity['alert_family'] == true;
    bool emergency = fallDetected || vitals['status'] == 'critical';
    String severity = emergency ? 'critical' : (alertFamily ? 'warning' : 'normal');

    return {
      'agent': 'VitalSync',
      'severity': severity,
      'daily_message': _buildDailyMessage(vitals, hrv, fall, sleep, activity),
      'alert_family': alertFamily,
      'emergency_action_taken': emergency,
      'assessments': [vitals, hrv, fall, sleep, activity],
    };
  }

  static String _buildDailyMessage(
    Map<String, dynamic> vitals,
    Map<String, dynamic> hrv,
    Map<String, dynamic> fall,
    Map<String, dynamic> sleep,
    Map<String, dynamic> activity,
  ) {
    final parts = <String>[];
    if (fall['fall_detected'] == true) parts.add('ALERT: Fall detected!');
    if (vitals['status'] == 'critical') parts.add('Critical vitals: ${(vitals['issues'] as List).join(', ')}');
    if (hrv['status'] == 'low') parts.add('Low HRV (${hrv['hrv_percent']}%).');
    if (sleep['quality'] == 'poor') parts.add('Poor sleep (${sleep['sleep_hours']}h).');
    if (activity['status'] == 'critical') parts.add('Extended inactivity detected.');
    if (parts.isEmpty) parts.add('All vitals within normal range.');
    return parts.join(' ');
  }

  static Map<String, dynamic> simulateMedicine(Map<String, dynamic> healthData) {
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final missedDays = healthData['doses_missed_consecutive_days'] as int? ?? 0;
    final medName = (healthData['medication_name'] as String?) ?? 'Unknown';

    final med = assessMedication(pillCount, missedDays, medName);
    final window = getCurrentMedWindow();
    final reminder = buildMedicationReminder(healthData);

    return {
      'agent': 'Medicine',
      'medication_status': med,
      'current_window': window,
      'reminder': reminder,
    };
  }

  static Map<String, dynamic> simulateMedication(Map<String, dynamic> healthData) {
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final missedDays = healthData['doses_missed_consecutive_days'] as int? ?? 0;
    final medName = (healthData['medication_name'] as String?) ?? 'Unknown';
    final medTaken = healthData['medication_taken_today'] as Map<String, dynamic>?;

    final med = assessMedication(pillCount, missedDays, medName);
    final window = getCurrentMedWindow();
    Map<String, dynamic>? adherence;
    if (medTaken != null) {
      adherence = computeAdherenceToday(medTaken.map((k, v) => MapEntry(k, v as bool)));
    }

    return {
      'agent': 'Medication',
      'medication_status': med,
      'current_window': window,
      'adherence_today': adherence,
    };
  }

  static Map<String, dynamic> simulateRefill(Map<String, dynamic> healthData) {
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final missedDays = healthData['doses_missed_consecutive_days'] as int? ?? 0;
    final userId = (healthData['user_id'] as String?) ?? 'unknown';
    final medName = (healthData['medication_name'] as String?) ?? 'Unknown';

    final refillCheck = shouldRefill(pillCount, missedDays);
    Map<String, dynamic>? refillOrder;
    if (refillCheck['refill_needed'] == true) {
      refillOrder = requestPharmacyRefill(userId, medName, 30);
    }

    return {
      'agent': 'Refill',
      'refill_check': refillCheck,
      'refill_order': refillOrder,
    };
  }

  static Map<String, dynamic> simulateEmoCare(Map<String, dynamic> healthData) {
    final moodScore = (healthData['mood_score'] as num?)?.toDouble();
    final steps = healthData['steps'] as int? ?? 0;
    final sleepHours = (healthData['sleep_hours'] as num?)?.toDouble() ?? 7.0;

    final mood = assessMood(moodScore);
    final recs = buildMoodRecommendations(moodScore, steps, sleepHours);

    return {
      'agent': 'EmoCare',
      'mood_assessment': mood,
      'recommendations': recs,
    };
  }

  static Map<String, dynamic> simulateCalling(Map<String, dynamic> healthData) {
    final fallDetected = healthData['fall_detected'] as bool? ?? false;
    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final hrvPercent = (healthData['hrv_percent'] as num?)?.toDouble();
    final moodScore = (healthData['mood_score'] as num?)?.toDouble();
    final familyContacts = _extractFamilyContacts(healthData);
    final emergencyContact = (healthData['emergency_contact'] as String?) ?? '+14165551234';
    final userId = (healthData['user_id'] as String?) ?? 'unknown';

    final reasons = <String>[];
    if (fallDetected) reasons.add('Fall detected');
    if (hr < 50 || hr > 120) reasons.add('Abnormal heart rate ($hr bpm)');
    if (spo2 < 92) reasons.add('Low SpO2 ($spo2%)');
    if (hrvPercent != null && hrvPercent < 40) reasons.add('Low HRV (${hrvPercent.toStringAsFixed(0)}%)');
    if (moodScore != null && moodScore < 3) reasons.add('Low mood (${moodScore.toStringAsFixed(1)})');

    Map<String, dynamic>? contactPicked;
    Map<String, dynamic>? callResult;
    Map<String, dynamic>? smsResult;
    Map<String, dynamic>? escalation;

    if (reasons.isNotEmpty) {
      if (familyContacts.isNotEmpty) {
        contactPicked = pickFamilyContact(familyContacts);
      }
      final isEmergency = fallDetected || hr < 50 || hr > 120 || spo2 < 92;
      if (isEmergency) {
        final familyPhone = contactPicked?['phone'] as String? ?? emergencyContact;
        escalation = emergencyEscalation('+1$userId', familyPhone, reasons.join(', '));
      } else {
        callResult = callSenior('+1$userId', 'Wellness check: ${reasons.join(', ')}');
        if (contactPicked != null) {
          smsResult = alertFamilySms('Alert for $userId: ${reasons.join(', ')}', contactPicked['phone'] as String);
        }
      }
    }

    return {
      'agent': 'Calling',
      'reasons': reasons,
      'contact_picked': contactPicked,
      'call_result': callResult,
      'sms_result': smsResult,
      'escalation': escalation,
      'action_taken': reasons.isNotEmpty,
    };
  }

  static Map<String, dynamic> simulateActivity(Map<String, dynamic> healthData) {
    final steps = healthData['steps'] as int? ?? 0;
    final lastMovement = healthData['last_movement_minutes'] as int? ?? 0;
    final fallDetected = healthData['fall_detected'] as bool? ?? false;

    return {
      'agent': 'Activity',
      'activity_assessment': assessActivity(steps, lastMovement),
      'fall_assessment': assessFall(fallDetected),
    };
  }

  static Map<String, dynamic> simulateSleep(Map<String, dynamic> healthData) {
    final sleepHours = (healthData['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final hr = healthData['heart_rate'] as int? ?? 72;

    return {
      'agent': 'Sleep',
      'sleep_assessment': assessSleep(sleepHours),
      'sleep_hr_correlation': sleepHrCorrelation(sleepHours, hr),
    };
  }

  static Map<String, dynamic> simulateHealthRecords(Map<String, dynamic> healthData) {
    final userId = (healthData['user_id'] as String?) ?? 'unknown';

    return {
      'agent': 'HealthRecords',
      'lab_summary': getLabSummary(userId),
      'visit_prep': getVisitPrepFromHealth(healthData),
      'family_dashboard': buildFamilyDashboard(healthData),
    };
  }

  // ─── Orchestrator: determines which agents to invoke ───

  static Map<String, dynamic> runOrchestrator(Map<String, dynamic> healthData) {
    final triage = fullHealthAssessment(healthData);
    final overallRisk = triage['overall_risk'] as String;
    final steps = healthData['steps'] as int? ?? 0;
    final lastMovement = healthData['last_movement_minutes'] as int? ?? 0;
    final sleepHours = (healthData['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final pillCount = healthData['pill_count'] as int? ?? 30;
    final missedDays = healthData['doses_missed_consecutive_days'] as int? ?? 0;
    final moodScore = (healthData['mood_score'] as num?)?.toDouble();
    final fallDetected = healthData['fall_detected'] as bool? ?? false;
    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final hrvPercent = (healthData['hrv_percent'] as num?)?.toDouble();

    // Always invoke
    final agents = <String, Map<String, dynamic>>{};
    agents['VitalSync'] = simulateVitalSync(healthData);
    agents['Medicine'] = simulateMedicine(healthData);
    agents['Medication'] = simulateMedication(healthData);
    agents['HealthRecords'] = simulateHealthRecords(healthData);

    // Conditional
    if (steps < 500 || lastMovement > 240) {
      agents['Activity'] = simulateActivity(healthData);
    }
    if (sleepHours < 6) {
      agents['Sleep'] = simulateSleep(healthData);
    }
    if (pillCount < 3 || missedDays >= 3) {
      agents['Refill'] = simulateRefill(healthData);
    }
    if (moodScore != null) {
      agents['EmoCare'] = simulateEmoCare(healthData);
    }

    // Calling agent
    bool shouldCall = fallDetected ||
        hr < 50 || hr > 120 ||
        spo2 < 92 ||
        (hrvPercent != null && hrvPercent < 40) ||
        (moodScore != null && moodScore < 3) ||
        overallRisk == 'high';
    if (shouldCall) {
      agents['Calling'] = simulateCalling(healthData);
    }

    return {
      'triage': triage,
      'agents_invoked': agents.keys.toList(),
      'agent_results': agents,
    };
  }

  static List<Map<String, dynamic>> _extractFamilyContacts(Map<String, dynamic> data) {
    final contacts = data['family_contacts'];
    if (contacts is List) {
      return contacts.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    }
    return [];
  }
}
