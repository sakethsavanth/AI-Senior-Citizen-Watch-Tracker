class TriageResult {
  final String overallRisk;
  final List<Map<String, dynamic>> assessments;
  final List<String> criticalFlags;

  const TriageResult({
    required this.overallRisk,
    required this.assessments,
    required this.criticalFlags,
  });

  factory TriageResult.fromMap(Map<String, dynamic> map) {
    return TriageResult(
      overallRisk: map['overall_risk'] as String? ?? 'low',
      assessments: (map['assessments'] as List?)
          ?.map((a) => Map<String, dynamic>.from(a as Map))
          .toList() ?? [],
      criticalFlags: (map['critical_flags'] as List?)
          ?.map((f) => f as String)
          .toList() ?? [],
    );
  }
}
