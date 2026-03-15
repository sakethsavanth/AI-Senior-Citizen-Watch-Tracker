import 'medication.dart';

class DoseEntry {
  final String medName;
  final String scheduledTime;
  final String? takenAt;
  final DoseStatus status;
  final String? aiNote;

  const DoseEntry({
    required this.medName,
    required this.scheduledTime,
    this.takenAt,
    required this.status,
    this.aiNote,
  });
}

class DoseLog {
  final String date;
  final List<DoseEntry> entries;

  const DoseLog({required this.date, required this.entries});
}
