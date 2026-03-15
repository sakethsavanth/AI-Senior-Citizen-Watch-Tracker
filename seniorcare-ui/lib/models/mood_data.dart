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
}
