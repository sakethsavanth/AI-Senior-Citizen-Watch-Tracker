import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/scenario_provider.dart';
import '../../models/alert.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/alert_row.dart';
import '../../widgets/scenario_picker.dart';

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
    ('Settings', Icons.settings, false),
  ];

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(apiServiceProvider).getAlerts();
    final criticalCount = alerts.where((a) => a.type == AlertType.critical).length;
    final persona = ref.watch(currentPersonaDataProvider);
    final initials = (persona['name'] as String? ?? 'AS')
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join();

    return Scaffold(
      floatingActionButton: const ScenarioPickerFab(),
      appBar: AppBar(
        backgroundColor: AppColors.brandDark,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'SC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'SeniorCare AI',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            if (criticalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.criticalBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$criticalCount Critical Alert${criticalCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.criticalText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.parentRoleBg,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.parentRoleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                Expanded(child: _buildMainContent()),
              ],
            );
          } else {
            return _buildMainContent();
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
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isNew)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 7,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              setState(() => _selectedIndex = index);
              switch (label) {
                case 'Dosage Log':
                  context.go('/dashboard/dosage-log');
                case 'Call History':
                  context.go('/dashboard/call-history');
                case 'Alerts':
                  // Stay in dashboard with alert view
                  break;
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    final healthData = ref.watch(scenarioHealthDataProvider);
    final triage = ref.watch(triageResultProvider);
    final api = ref.watch(apiServiceProvider);
    final alerts = api.getAlerts();

    final hr = healthData['heart_rate'] as int? ?? 72;
    final spo2 = healthData['spo2'] as int? ?? 98;
    final steps = healthData['steps'] as int? ?? 0;
    final risk = triage['overall_risk'] as String? ?? 'low';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashMetricCard('Heart Rate', '$hr bpm',
                  (hr > 120 || hr < 50) ? 'Abnormal' : 'Normal range',
                  (hr > 120 || hr < 50) ? AppColors.criticalText : AppColors.brandPrimary),
              _DashMetricCard('SpO2', '$spo2%',
                  spo2 < 92 ? 'Low!' : 'Excellent',
                  spo2 < 92 ? AppColors.criticalText : AppColors.okText),
              _DashMetricCard('Risk Level', risk.toUpperCase(), '${alerts.length} alerts',
                  risk == 'high' ? AppColors.criticalText : risk == 'medium' ? AppColors.warningText : AppColors.okText),
              _DashMetricCard('Steps Today',
                  steps > 999 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps',
                  'Goal: 5,000', Colors.black87),
            ],
          ),
          const SizedBox(height: 16),

          const Text('Recent Alerts',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          for (final alert in alerts) AlertRow(alert: alert),
        ],
      ),
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
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
