import '../mock_data.dart';
import '../models/medication.dart';
import '../models/alert.dart';
import '../models/dose_log.dart';

/// Stubbed API service — returns mock data for demo.
/// Replace with real HTTP calls when backend is connected.
class ApiService {
  Future<Map<String, dynamic>> getSeniorSummary(String seniorId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'senior_id': seniorId,
      'heart_rate': normalHeartRate,
      'spo2': normalSpo2,
      'steps': normalSteps,
      'sleep_hours': normalSleepHours,
      'pills_remaining': normalPillsRemaining,
      'streak_days': normalStreakDays,
      'adherence_pct': normalAdherencePct,
    };
  }

  Future<List<Medication>> getMedications(String seniorId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockMedications;
  }

  Future<void> confirmDose({
    required String seniorId,
    required String medId,
    required String confirmedBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<List<Alert>> getAlerts(String seniorId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockAlerts;
  }

  Future<DoseLog> getDoseLog(String seniorId, String week) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockDoseLog;
  }
}
