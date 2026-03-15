class HealthRecord {
  final Map<String, dynamic> drugInteractions;
  final Map<String, dynamic> labSummary;
  final Map<String, dynamic> visitChecklist;
  final Map<String, dynamic> familyView;

  const HealthRecord({
    required this.drugInteractions,
    required this.labSummary,
    required this.visitChecklist,
    required this.familyView,
  });

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      drugInteractions: Map<String, dynamic>.from(map['medication_interactions'] as Map? ?? {}),
      labSummary: Map<String, dynamic>.from(map['lab_summary'] as Map? ?? {}),
      visitChecklist: Map<String, dynamic>.from(map['visit_prep'] as Map? ?? {}),
      familyView: Map<String, dynamic>.from(map['family_dashboard'] as Map? ?? {}),
    );
  }
}
