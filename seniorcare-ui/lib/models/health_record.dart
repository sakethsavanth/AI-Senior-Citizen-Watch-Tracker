class HealthRecord {
  final Map<String, dynamic> drugInteractions;
  final Map<String, dynamic> labSummary;
  final List<String> visitChecklist;
  final Map<String, dynamic> familyView;

  const HealthRecord({
    required this.drugInteractions,
    required this.labSummary,
    required this.visitChecklist,
    required this.familyView,
  });
}
