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
  });
}
