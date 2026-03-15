class HealthData {
  final int heartRate;
  final double spo2;
  final int steps;
  final double sleepHours;
  final int pillCount;
  final int lastMovementMinutes;
  final double? hrvPercent;
  final bool fallDetected;
  final double? moodScore;
  final String overallRisk;
  final Map<String, bool>? medicationTakenToday;
  final int dosesMissedConsecutiveDays;
  final String? medicationName;

  const HealthData({
    required this.heartRate,
    required this.spo2,
    required this.steps,
    required this.sleepHours,
    required this.pillCount,
    required this.lastMovementMinutes,
    this.hrvPercent,
    this.fallDetected = false,
    this.moodScore,
    this.overallRisk = 'low',
    this.medicationTakenToday,
    this.dosesMissedConsecutiveDays = 0,
    this.medicationName,
  });

  factory HealthData.fromMap(Map<String, dynamic> map, {String risk = 'low'}) {
    final medToday = map['medication_taken_today'] as Map?;
    return HealthData(
      heartRate: map['heart_rate'] as int? ?? 72,
      spo2: (map['spo2'] as num?)?.toDouble() ?? 98,
      steps: map['steps'] as int? ?? 0,
      sleepHours: (map['sleep_hours'] as num?)?.toDouble() ?? 0,
      pillCount: map['pill_count'] as int? ?? 0,
      lastMovementMinutes: map['last_movement_minutes'] as int? ?? 0,
      hrvPercent: (map['hrv_percent'] as num?)?.toDouble(),
      fallDetected: map['fall_detected'] as bool? ?? false,
      moodScore: (map['mood_score'] as num?)?.toDouble(),
      overallRisk: risk,
      medicationTakenToday: medToday?.map((k, v) => MapEntry(k as String, v as bool)),
      dosesMissedConsecutiveDays: map['doses_missed_consecutive_days'] as int? ?? 0,
      medicationName: map['medication_name'] as String?,
    );
  }
}
