import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/parent_login_screen.dart';
import 'screens/auth/family_login_screen.dart';
import 'screens/senior/senior_home_screen.dart';
import 'screens/senior/medication_tracker_screen.dart';
import 'screens/senior/ai_call_incoming_screen.dart';
import 'screens/senior/ai_call_active_screen.dart';
import 'screens/senior/dose_history_screen.dart';
import 'screens/senior/emergency_screen.dart';
import 'screens/family/family_dashboard_screen.dart';
import 'screens/family/family_alerts_screen.dart';
import 'screens/family/weekly_report_screen.dart';
import 'screens/web/web_dashboard_screen.dart';
import 'screens/web/dosage_log_screen.dart';
import 'screens/web/call_history_screen.dart';
import 'screens/senior/mood_input_screen.dart';
import 'screens/senior/family_contacts_screen.dart';
import 'screens/family/health_records_screen.dart';
import 'screens/web/agent_results_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authProvider);

  return GoRouter(
    initialLocation: '/auth/role-select',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final user = authNotifier.user;
      final path = state.uri.path;

      // Allow auth paths when logged out
      if (user == null && path.startsWith('/auth')) return null;
      if (user == null) return '/auth/role-select';

      // Block auth paths when logged in
      if (path.startsWith('/auth')) {
        return user.role == 'parent' ? '/senior/home' : '/family/home';
      }

      // Role-based routing guard
      if (user.role == 'parent' && !path.startsWith('/senior')) {
        return '/senior/home';
      }
      if (user.role == 'child' &&
          !path.startsWith('/family') &&
          !path.startsWith('/dashboard')) {
        return '/family/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/role-select',
        builder: (_, __) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/auth/parent-login',
        builder: (_, __) => const ParentLoginScreen(),
      ),
      GoRoute(
        path: '/auth/family-login',
        builder: (_, __) => const FamilyLoginScreen(),
      ),
      GoRoute(
        path: '/senior/home',
        builder: (_, __) => const SeniorHomeScreen(),
      ),
      GoRoute(
        path: '/senior/medications',
        builder: (_, __) => const MedicationTrackerScreen(),
      ),
      GoRoute(
        path: '/senior/call-incoming',
        builder: (_, s) => AICallIncomingScreen(
          callData: s.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/senior/call-active',
        builder: (_, s) => AICallActiveScreen(
          callData: s.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/senior/dose-history',
        builder: (_, __) => const DoseHistoryScreen(),
      ),
      GoRoute(
        path: '/senior/emergency',
        builder: (_, __) => const EmergencyScreen(),
      ),
      GoRoute(
        path: '/senior/mood',
        builder: (_, __) => const MoodInputScreen(),
      ),
      GoRoute(
        path: '/senior/family-contacts',
        builder: (_, __) => const FamilyContactsScreen(),
      ),
      GoRoute(
        path: '/family/home',
        builder: (_, __) => const FamilyDashboardScreen(),
      ),
      GoRoute(
        path: '/family/alerts',
        builder: (_, __) => const FamilyAlertsScreen(),
      ),
      GoRoute(
        path: '/family/reports',
        builder: (_, __) => const WeeklyReportScreen(),
      ),
      GoRoute(
        path: '/family/health-records',
        builder: (_, __) => const HealthRecordsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const WebDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/dosage-log',
        builder: (_, __) => const DosageLogScreen(),
      ),
      GoRoute(
        path: '/dashboard/call-history',
        builder: (_, __) => const CallHistoryScreen(),
      ),
      GoRoute(
        path: '/dashboard/agent-results',
        builder: (_, __) => const AgentResultsScreen(),
      ),
    ],
  );
});
