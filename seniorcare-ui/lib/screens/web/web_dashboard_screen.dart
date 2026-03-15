import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../mock_data.dart';
import '../../widgets/alert_row.dart';

class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
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
    return Scaffold(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.criticalBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '1 Critical Alert',
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
                'AS',
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
              if (label == 'Dosage Log') {
                context.go('/dashboard/dosage-log');
              } else if (label == 'Call History') {
                context.go('/dashboard/call-history');
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5 metric cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashMetricCard(
                  'Heart Rate', '72 bpm', 'Normal range', AppColors.brandPrimary),
              _DashMetricCard(
                  'SpO2', '98%', 'Excellent', AppColors.okText),
              _DashMetricCard(
                  'Dose Streak', '7 days', '95% adherence', AppColors.okText),
              _DashMetricCard('Last AI Call', '1:04 PM', 'Confirmed dose',
                  AppColors.brandPrimary),
              _DashMetricCard(
                  'Steps Today', '3,241', 'Goal: 5,000', Colors.black87),
            ],
          ),
          const SizedBox(height: 16),

          // Recent Alerts
          const Text(
            'Recent Alerts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          for (final alert in mockAlerts) AlertRow(alert: alert),
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
