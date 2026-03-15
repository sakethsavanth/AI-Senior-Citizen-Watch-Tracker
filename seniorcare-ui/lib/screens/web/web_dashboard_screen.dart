import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/scenario_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/alert_row.dart';

class WebDashboardScreen extends ConsumerStatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  ConsumerState<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends ConsumerState<WebDashboardScreen> {
  int _selectedIndex = 0;

  final _sidebarItems = [
    ('Overview', Icons.dashboard, false),
    ('Vitals', Icons.favorite, false),
    ('Medications', Icons.medication, false),
    ('Dosage Log', Icons.calendar_month, true),
    ('Sleep', Icons.bedtime, false),
    ('Activity', Icons.directions_walk, false),
    ('Alerts', Icons.notifications, false),
    ('Call History', Icons.phone, true),
    ('Agent Results', Icons.psychology, true),
    ('Settings', Icons.settings, false),
  ];

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(scenarioHealthDataProvider);
    final triage = ref.watch(triageResultProvider);
    final agentResults = ref.watch(agentResultsProvider);

    final risk = triage['overall_risk'] as String? ?? 'low';
    final flags = triage['critical_flags'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brandDark,
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.brandPrimary, borderRadius: BorderRadius.circular(6)),
              child: const Center(child: Text('SC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
            ),
            const SizedBox(width: 8),
            const Text('SeniorCare AI', style: TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            if (flags.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.criticalBg, borderRadius: BorderRadius.circular(4)),
                child: Text('${flags.length} Alert${flags.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 10, color: AppColors.criticalText, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.parentRoleBg,
              child: Text('AS', style: TextStyle(fontSize: 10, color: AppColors.parentRoleText, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                _buildSidebar(),
                const VerticalDivider(width: 1),
                Expanded(child: _buildMainContent(h, triage, agentResults, risk)),
              ],
            );
          } else {
            return _buildMainContent(h, triage, agentResults, risk);
          }
        },
      ),
      drawer: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 900) {
            return Drawer(child: _buildSidebar());
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 160,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sidebarItems.length,
        itemBuilder: (context, index) {
          final (label, icon, isNew) = _sidebarItems[index];
          final isActive = index == _selectedIndex;

          return ListTile(
            dense: true,
            selected: isActive,
            selectedTileColor: AppColors.aiActionBg,
            leading: Icon(icon, size: 18),
            title: Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal))),
                if (isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.brandPrimary, borderRadius: BorderRadius.circular(3)),
                    child: const Text('NEW', style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            onTap: () {
              if (label == 'Dosage Log') {
                context.go('/dashboard/dosage-log');
              } else if (label == 'Call History') {
                context.go('/dashboard/call-history');
              } else if (label == 'Agent Results') {
                context.go('/dashboard/agent-results');
              } else {
                setState(() => _selectedIndex = index);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMainContent(
    Map<String, dynamic> h,
    Map<String, dynamic> triage,
    Map<String, dynamic> agentResults,
    String risk,
  ) {
    switch (_selectedIndex) {
      case 1: return _buildVitalsPanel(h, triage);
      case 2: return _buildMedicationsPanel(h);
      case 4: return _buildSleepPanel(h);
      case 5: return _buildActivityPanel(h);
      case 6: return _buildAlertsPanel(agentResults);
      default: return _buildOverviewPanel(h, triage, agentResults, risk);
    }
  }

  Widget _buildOverviewPanel(Map<String, dynamic> h, Map<String, dynamic> triage, Map<String, dynamic> agentResults, String risk) {
    final hr = (h['heart_rate'] as num?)?.toInt() ?? 0;
    final spo2 = (h['spo2'] as num?)?.toInt() ?? 0;
    final steps = (h['steps'] as num?)?.toInt() ?? 0;
    final sleepH = (h['sleep_hours'] as num?)?.toDouble() ?? 0;
    final alerts = ApiService.getAlertsFromAgentResults(agentResults);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              _DashMetricCard('Heart Rate', '$hr bpm', hr > 120 || hr < 50 ? 'Abnormal' : 'Normal range',
                  hr > 120 || hr < 50 ? AppColors.criticalText : AppColors.brandPrimary),
              _DashMetricCard('SpO2', '$spo2%', spo2 < 92 ? 'Low' : 'Excellent',
                  spo2 < 92 ? AppColors.criticalText : AppColors.okText),
              _DashMetricCard('Steps', '$steps', 'Today', Colors.black87),
              _DashMetricCard('Sleep', '${sleepH.toStringAsFixed(1)}h', sleepH < 6 ? 'Below target' : 'On track',
                  sleepH < 6 ? AppColors.warningText : AppColors.okText),
              _DashMetricCard('Risk', risk.toUpperCase(), '${(triage['critical_flags'] as List?)?.length ?? 0} flags',
                  risk == 'high' ? AppColors.criticalText : risk == 'medium' ? AppColors.warningText : AppColors.okText),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Recent Alerts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          for (final alert in alerts) AlertRow(alert: alert),
        ],
      ),
    );
  }

  Widget _buildVitalsPanel(Map<String, dynamic> h, Map<String, dynamic> triage) {
    final hr = (h['heart_rate'] as num?)?.toInt() ?? 0;
    final spo2 = (h['spo2'] as num?)?.toInt() ?? 0;
    final hrv = (h['hrv_percent'] as num?)?.toDouble() ?? 50;
    final fall = h['fall_detected'] as bool? ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vital Signs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _DashMetricCard('Heart Rate', '$hr bpm', hr > 120 || hr < 50 ? 'Abnormal' : 'Normal', hr > 120 || hr < 50 ? AppColors.criticalText : AppColors.okText),
            _DashMetricCard('SpO2', '$spo2%', spo2 < 92 ? 'Low' : 'Normal', spo2 < 92 ? AppColors.criticalText : AppColors.okText),
            _DashMetricCard('HRV', '${hrv.toStringAsFixed(0)}%', hrv < 40 ? 'Below threshold' : 'OK', hrv < 40 ? AppColors.warningText : AppColors.okText),
            _DashMetricCard('Fall', fall ? 'DETECTED' : 'None', '', fall ? AppColors.criticalText : AppColors.okText),
          ]),
        ],
      ),
    );
  }

  Widget _buildMedicationsPanel(Map<String, dynamic> h) {
    final meds = ApiService.getMedicationsFromData(h);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final m in meds)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${m.pillsRemaining} pills', style: TextStyle(color: m.pillsRemaining < 3 ? AppColors.criticalText : Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSleepPanel(Map<String, dynamic> h) {
    final sleepH = (h['sleep_hours'] as num?)?.toDouble() ?? 0;
    final quality = sleepH < 4 ? 'Poor' : sleepH < 6 ? 'Fair' : 'Good';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sleep', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _DashMetricCard('Hours', '${sleepH.toStringAsFixed(1)}h', quality, sleepH < 6 ? AppColors.warningText : AppColors.okText),
        ],
      ),
    );
  }

  Widget _buildActivityPanel(Map<String, dynamic> h) {
    final steps = (h['steps'] as num?)?.toInt() ?? 0;
    final lastMov = (h['last_movement_minutes'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _DashMetricCard('Steps', '$steps', 'Today', Colors.black87),
            _DashMetricCard('Last Movement', '${lastMov}m ago', lastMov > 240 ? 'Sedentary' : 'Active', lastMov > 240 ? AppColors.warningText : AppColors.okText),
          ]),
        ],
      ),
    );
  }

  Widget _buildAlertsPanel(Map<String, dynamic> agentResults) {
    final alerts = ApiService.getAlertsFromAgentResults(agentResults);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (_, i) => AlertRow(alert: alerts[i]),
    );
  }
}

class _DashMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _DashMetricCard(this.title, this.value, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }
}
