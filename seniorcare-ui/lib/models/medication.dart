enum DoseStatus { taken, missed, pending, low }

class Medication {
  final String id;
  final String name;
  final String dosage;
  final String scheduledTime;
  final int pillsRemaining;
  final DoseStatus status;
  final String? takenAt;

  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduledTime,
    required this.pillsRemaining,
    required this.status,
    this.takenAt,
  });
}
