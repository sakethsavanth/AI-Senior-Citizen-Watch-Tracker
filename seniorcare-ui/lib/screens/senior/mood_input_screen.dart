import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scenario_picker.dart';

class MoodInputScreen extends ConsumerStatefulWidget {
  const MoodInputScreen({super.key});

  @override
  ConsumerState<MoodInputScreen> createState() => _MoodInputScreenState();
}

class _MoodInputScreenState extends ConsumerState<MoodInputScreen> {
  double _moodScore = 3.0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final healthData = ref.read(scenarioHealthDataProvider);
    _moodScore = (healthData['mood_score'] as num?)?.toDouble() ?? 3.0;
  }

  @override
  Widget build(BuildContext context) {
    final agentResults = ref.watch(agentResultsProvider);
    final emoResult = (agentResults['agent_results'] as Map<String, dynamic>?)?['EmoCare'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('How are you feeling?')),
      floatingActionButton: const ScenarioPickerFab(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rate your mood', style: AppTextStyles.seniorTitle),
            const SizedBox(height: 16),
            _MoodEmoji(score: _moodScore),
            const SizedBox(height: 12),
            Slider(
              value: _moodScore,
              min: 1,
              max: 5,
              divisions: 8,
              label: _moodScore.toStringAsFixed(1),
              activeColor: _moodScore >= 3.5
                  ? AppColors.okText
                  : _moodScore >= 2.5
                      ? AppColors.warningText
                      : AppColors.criticalText,
              onChanged: _submitted ? null : (v) => setState(() => _moodScore = v),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Very low', style: AppTextStyles.seniorLabel),
              Text('Great', style: AppTextStyles.seniorLabel),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: Text(_submitted ? 'Submitted' : 'Submit Mood'),
              onPressed: _submitted
                  ? null
                  : () => setState(() => _submitted = true),
            ),
            if (_submitted && emoResult != null) ...[
              const SizedBox(height: 24),
              _RecommendationCard(emoResult: emoResult),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoodEmoji extends StatelessWidget {
  final double score;
  const _MoodEmoji({required this.score});

  @override
  Widget build(BuildContext context) {
    final emoji = score >= 4
        ? '😊'
        : score >= 3
            ? '😐'
            : score >= 2
                ? '😟'
                : '😢';
    return Text(emoji, style: const TextStyle(fontSize: 64), textAlign: TextAlign.center);
  }
}

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> emoResult;
  const _RecommendationCard({required this.emoResult});

  @override
  Widget build(BuildContext context) {
    final recs = emoResult['recommendations'] as List? ?? [];
    final summary = emoResult['wellness_summary'] as String? ?? '';

    return Card(
      color: AppColors.aiActionBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.psychology, color: AppColors.aiActionText, size: 20),
              const SizedBox(width: 8),
              Text('AI Recommendations', style: AppTextStyles.title.copyWith(color: AppColors.aiActionText)),
            ]),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary, style: AppTextStyles.seniorBody),
            ],
            const SizedBox(height: 8),
            ...recs.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(child: Text(r.toString(), style: AppTextStyles.seniorBody)),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}
