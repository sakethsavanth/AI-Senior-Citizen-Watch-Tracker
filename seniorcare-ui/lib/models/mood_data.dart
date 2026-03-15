class MoodData {
  final double? score;
  final String status;
  final bool triggerCall;
  final List<String> recommendations;
  final String wellnessSummary;

  const MoodData({
    this.score,
    required this.status,
    required this.triggerCall,
    required this.recommendations,
    required this.wellnessSummary,
  });

  factory MoodData.fromMaps(Map<String, dynamic> mood, Map<String, dynamic> recs) {
    return MoodData(
      score: (mood['mood_score'] as num?)?.toDouble(),
      status: mood['status'] as String? ?? 'unknown',
      triggerCall: mood['trigger_call'] as bool? ?? false,
      recommendations: (recs['recommendations'] as List?)
          ?.map((r) => r as String)
          .toList() ?? [],
      wellnessSummary: recs['wellness_summary'] as String? ?? 'unknown',
    );
  }
}
