import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/scenario_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/family_nav_bar.dart';

class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(scenarioHealthDataProvider);
    final triage = ref.watch(triageResultProvider);
    final days = ref.watch(decliningWeekDaysProvider);

    final hr = (h['heart_rate'] as num?)?.toInt() ?? 72;
    final sleepH = (h['sleep_hours'] as num?)?.toDouble() ?? 7.0;
    final steps = (h['steps'] as num?)?.toInt() ?? 3000;

    // If declining_week, use the real 7-day data; otherwise synthesize from today
    final weekSteps = days.isNotEmpty
        ? days.map((d) => ((d['steps'] as num?)?.toDouble() ?? 0)).toList()
        : List.generate(7, (i) => steps.toDouble() + (i - 3) * 200);

    final maxY = (weekSteps.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, 20000.0);
    final avgSteps = weekSteps.isNotEmpty
        ? (weekSteps.reduce((a, b) => a + b) / weekSteps.length).round()
        : steps;
    final avgStepsLabel = avgSteps >= 1000 ? '${(avgSteps / 1000).toStringAsFixed(1)}k' : '$avgSteps';

    final risk = triage['overall_risk'] as String? ?? 'low';
    final summary = risk == 'high'
        ? 'Critical week. Multiple health flags detected. Immediate attention recommended.'
        : risk == 'medium'
            ? 'Some concerns this week. Monitor vitals closely.'
            : 'Stable week. All vitals within normal ranges.';

    return Scaffold(
      bottomNavigationBar: const FamilyNavBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly Report', style: AppTextStyles.title),
              Text('Current scenario week', style: AppTextStyles.micro),
              const SizedBox(height: 12),

              // 2x2 metric grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _MetricTile('Avg HR', '$hr', 'bpm', null),
                  _MetricTile('Adherence', '${h['medication_taken_today'] != null ? '95' : '--'}%', '', AppColors.okText),
                  _MetricTile('Avg Sleep', sleepH.toStringAsFixed(1), 'h', null),
                  _MetricTile('Avg Steps', avgStepsLabel, '', null),
                ],
              ),
              const SizedBox(height: 12),

              // AI Summary box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.aiActionBg, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Summary', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.aiActionText)),
                    const SizedBox(height: 4),
                    Text(summary, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Steps chart
              Text('Steps this week', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            if (value.toInt() >= 0 && value.toInt() < days.length) {
                              return Text(days[value.toInt()], style: const TextStyle(fontSize: 8));
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      weekSteps.length.clamp(0, 7),
                      (i) => BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: weekSteps[i],
                            color: i == weekSteps.length - 1 ? AppColors.brandPrimary : Colors.grey[300],
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  const _MetricTile(this.label, this.value, this.unit, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.black87,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
