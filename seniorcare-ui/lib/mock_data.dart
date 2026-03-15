import 'models/medication.dart';
import 'models/alert.dart';
import 'models/dose_log.dart';

// Senior profile
const seniorName = 'Mr. Sharma';
const familyName = 'Arjun';
const location = 'Menindoma, India';
const seniorPhone = '+91 98765 43210';

// Normal vitals
const normalHeartRate = 72;
const normalSpo2 = 98;
const normalSteps = 3241;
const normalSleepHours = 7.2;
const normalPillsRemaining = 12;
const normalStreakDays = 7;
const normalAdherencePct = 95;

// Critical vitals
const criticalHeartRate = 128;
const criticalSpo2 = 87;
const criticalSteps = 200;
const criticalLastMovementMins = 380;
const criticalSleepHours = 4.1;
const criticalPillsRemaining = 3;

// 3 medications
final mockMedications = [
  const Medication(
    id: 'met',
    name: 'Metformin 500mg',
    dosage: '500mg',
    scheduledTime: '8:00 AM',
    pillsRemaining: 12,
    status: DoseStatus.taken,
    takenAt: '8:07',
  ),
  const Medication(
    id: 'lis',
    name: 'Lisinopril 10mg',
    dosage: '10mg',
    scheduledTime: '2:00 PM',
    pillsRemaining: 3,
    status: DoseStatus.missed,
  ),
  const Medication(
    id: 'asp',
    name: 'Aspirin 75mg',
    dosage: '75mg',
    scheduledTime: '8:00 PM',
    pillsRemaining: 22,
    status: DoseStatus.pending,
  ),
];

// 4 alerts (one of each type)
final mockAlerts = [
  const Alert(
    type: AlertType.critical,
    message: 'No movement 6h. SpO2 87%.',
    time: '2h ago',
    hasCta: true,
    ctaLabel: 'Call Dad Now',
  ),
  const Alert(
    type: AlertType.aiAction,
    message: 'AI called Mr. Sharma. Confirmed dose 1:04 PM.',
    time: '1:04 PM',
  ),
  const Alert(
    type: AlertType.warning,
    message: 'Lisinopril low (3 pills). Refill ordered.',
    time: 'Yesterday',
  ),
  const Alert(
    type: AlertType.info,
    message: 'Morning medication confirmed.',
    time: '8:07 AM',
  ),
];

// Weekly report
final weeklySteps = [2800, 3100, 3400, 4200, 3241, 2900, 3100];
const weeklyAvgHR = 74;
const weeklyAdherence = 95;
const weeklyAvgSleep = 6.8;
const weeklyAvgSteps = '3.4k';
const weeklyAISummary =
    'Stable week. Sleep up 12%. 1 missed dose Wed \u2014 AI intervened.';

// Dose history (7 days Mon-Sun)
final weekDoseStatus = [
  'taken',
  'taken',
  'taken',
  'missed',
  'taken',
  'taken',
  'pending',
];

// Dose log entries for today
final mockDoseLog = DoseLog(
  date: '2026-03-15',
  entries: [
    const DoseEntry(
      medName: 'Metformin 500mg',
      scheduledTime: '8:00 AM',
      takenAt: '8:07 AM',
      status: DoseStatus.taken,
    ),
    const DoseEntry(
      medName: 'Lisinopril 10mg',
      scheduledTime: '2:00 PM',
      status: DoseStatus.missed,
      aiNote: 'AI called at 2:32 PM',
    ),
    const DoseEntry(
      medName: 'Aspirin 75mg',
      scheduledTime: '8:00 PM',
      status: DoseStatus.pending,
    ),
  ],
);

// Call history for web dashboard
final mockCallHistory = [
  {
    'time': '1:04 PM',
    'target': 'Mr. Sharma',
    'reason': 'Medication check \u2014 Lisinopril',
    'duration': '0:34',
    'outcome': 'Confirmed',
  },
  {
    'time': '9:15 AM',
    'target': 'Mr. Sharma',
    'reason': 'Morning wellness check',
    'duration': '1:12',
    'outcome': 'All good',
  },
  {
    'time': 'Yesterday 3:30 PM',
    'target': 'Arjun (Family)',
    'reason': 'Low pill alert \u2014 Lisinopril',
    'duration': '0:45',
    'outcome': 'Notified',
  },
  {
    'time': 'Yesterday 8:00 AM',
    'target': 'Mr. Sharma',
    'reason': 'Morning medication reminder',
    'duration': '0:28',
    'outcome': 'Confirmed',
  },
];
