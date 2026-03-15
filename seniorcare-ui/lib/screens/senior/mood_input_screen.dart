import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/agent_simulator.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/senior_nav_bar.dart';

class MoodInputScreen extends ConsumerStatefulWidget {
  const MoodInputScreen({super.key});

  @override
  ConsumerState<MoodInputScreen> createState() => _MoodInputScreenState();
}

class _MoodInputScreenState extends ConsumerState<MoodInputScreen> {
  double _selectedMood = 3.0;
  Map<String, dynamic>? _result;

  void _submit() {
    final h = ref.read(scenarioHealthDataProvider);
    final mood = AgentSimulator.assessMood(_selectedMood);
    final recs = AgentSimulator.buildMoodRecommendations(
      _selectedMood,
      (h['steps'] as num).toInt(),
      (h['sleep_hours'] as num).toDouble(),
    );
    setState(() {
      _result = {'mood': mood, 'recs': recs};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How are you feeling?')),
      bottomNavigationBar: const SeniorNavBar(currentIndex: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rate your mood', style: AppTextStyles.seniorTitle),
            const SizedBox(height: 16),

            // Emoji row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [1, 2, 3, 4, 5].map((v) {
                final emojis = ['😞', '😟', '😐', '🙂', '😊'];
                final selected = _selectedMood == v.toDouble();
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = v.toDouble()),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.brandPrimary.withValues(alpha: 0.15) : Colors.grey[100],
                      border: Border.all(
                        color: selected ? AppColors.brandPrimary : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(emojis[v - 1], style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Score: ${_selectedMood.toInt()}/5',
                style: AppTextStyles.seniorLabel,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 16),

            if (_result != null) ...[
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final mood = _result!['mood'] as Map<String, dynamic>;
    final recs = _result!['recs'] as Map<String, dynamic>;
    final triggerCall = mood['trigger_call'] as bool? ?? false;
    final summary = recs['wellness_summary'] as String? ?? '';
    final recommendations = (recs['recommendations'] as List?)?.cast<String>() ?? [];

    Color summaryColor;
    switch (summary) {
      case 'low':
        summaryColor = AppColors.criticalText;
      case 'fair':
        summaryColor = AppColors.warningText;
      default:
        summaryColor = AppColors.okText;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (triggerCall)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "We'll notify your family to check in on you.",
              style: TextStyle(fontSize: 14, color: AppColors.warningText, fontWeight: FontWeight.w600),
            ),
          ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Wellness: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(summary.toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: summaryColor)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Recommendations:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final rec in recommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14)),
                      Expanded(child: Text(rec, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
