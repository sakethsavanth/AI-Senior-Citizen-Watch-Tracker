# plan_v1.md — SeniorCare AI UI Build Instructions for Claude Code

> **This is the single source of truth for building the complete SeniorCare AI UI.**
> Read every section before writing a single line of code.

---

## 0. Project Overview

SeniorCare AI monitors senior citizens whose family lives abroad (e.g. student at UofT, parents
in Menindoma India). Uses Samsung Galaxy Watch → Health SDK → AWS Lambda + Claude AI
(Railtracks) → Twilio calls.

**Two user types:**
- `parent` — Senior citizen (Mr. Sharma). Simple UI, big text, PIN login
- `child` — Remote family member (Arjun). Full dashboard, email login

**Three surfaces — ALL built in Flutter:**
1. Flutter Mobile App — Senior's phone (Android first, role = parent)
2. Flutter Mobile App — Family member's phone (role = child, same codebase)
3. Flutter Web — Family desktop browser (same codebase, responsive layout)

**Tech stack:**
- Framework: Flutter (Dart) — single codebase for all 3 surfaces
- State management: Riverpod (or Provider)
- Navigation: GoRouter
- HTTP: Dio or http package
- Auth: AWS Cognito via amazon_cognito_identity_dart_auth or Amplify Flutter
- Backend: AWS Lambda + API Gateway (REST)
- AI: Claude claude-sonnet-4-6 via Railtracks
- Calls: Twilio Voice SDK

**Flutter project structure:**
```
lib/
  main.dart
  app.dart                    ← MaterialApp + GoRouter
  theme/
    app_theme.dart            ← ALL colors, text styles, component themes
  models/
    user.dart
    medication.dart
    dose_log.dart
    health_data.dart
    alert.dart
  services/
    auth_service.dart         ← Cognito
    api_service.dart          ← all REST calls
    notification_service.dart
  providers/
    auth_provider.dart
    health_provider.dart
    medication_provider.dart
  screens/
    auth/
      role_select_screen.dart
      parent_login_screen.dart
      family_login_screen.dart
    senior/
      senior_home_screen.dart
      medication_tracker_screen.dart
      ai_call_incoming_screen.dart
      ai_call_active_screen.dart
      dose_history_screen.dart
      emergency_screen.dart
    family/
      family_dashboard_screen.dart
      family_alerts_screen.dart
      weekly_report_screen.dart
    web/
      web_dashboard_screen.dart     ← responsive, desktop layout
  widgets/
    phone_metric_card.dart
    medication_card.dart
    pill_progress_bar.dart
    alert_row.dart
    badge_widget.dart
    ai_avatar_widget.dart           ← pulsing animation
    senior_nav_bar.dart
    family_nav_bar.dart
  utils/
    dose_badge_logic.dart           ← badge color/label logic
    date_utils.dart
```

---

## 1. Design System — Flutter ThemeData

### 1.1 app_theme.dart — Define ALL colors here

```dart
// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppColors {
  // Status semantic colors
  static const Color criticalBg     = Color(0xFFFCEBEB);
  static const Color criticalText   = Color(0xFFA32D2D);
  static const Color criticalBorder = Color(0xFFA32D2D);

  static const Color warningBg      = Color(0xFFFAEEDA);
  static const Color warningText    = Color(0xFF854F0B);
  static const Color warningBorder  = Color(0xFF854F0B);

  static const Color okBg           = Color(0xFFEAF3DE);
  static const Color okText         = Color(0xFF3B6D11);
  static const Color okBorder       = Color(0xFF3B6D11);

  static const Color aiActionBg     = Color(0xFFE6F1FB);
  static const Color aiActionText   = Color(0xFF185FA5);
  static const Color aiActionBorder = Color(0xFF185FA5);

  // Role identity
  static const Color parentRoleBg     = Color(0xFFEEEDFE); // purple — senior
  static const Color parentRoleText   = Color(0xFF3C3489);
  static const Color parentRoleBorder = Color(0xFFAFA9EC);

  static const Color childRoleBg      = Color(0xFFEAF3DE); // green — family
  static const Color childRoleText    = Color(0xFF27500A);
  static const Color childRoleBorder  = Color(0xFF97C459);

  // Brand
  static const Color brandPrimary = Color(0xFF185FA5);
  static const Color brandDark    = Color(0xFF042C53); // nav bar / header

  // Pill progress bars
  static const Color pillFull    = Color(0xFF3B6D11);
  static const Color pillLow     = Color(0xFFA32D2D);
  static const Color pillPending = Color(0xFF185FA5);

  // Misc
  static const Color amberLight  = Color(0xFFFAEEDA);
  static const Color phoneFrame  = Color(0xFF2C2C2A);
}

class AppTextStyles {
  // Senior App — larger for elderly
  static const TextStyle seniorTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const TextStyle seniorBody  = TextStyle(fontSize: 14);
  static const TextStyle seniorLabel = TextStyle(fontSize: 12, color: Color(0xFF64748B));

  // Family App / Web
  static const TextStyle title  = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle body   = TextStyle(fontSize: 12);
  static const TextStyle label  = TextStyle(fontSize: 10, color: Color(0xFF64748B));
  static const TextStyle micro  = TextStyle(fontSize: 8,  color: Color(0xFF94A3B8));
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brandPrimary),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.brandDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
```

---

## 2. Routing — GoRouter

```dart
// lib/app.dart

final router = GoRouter(
  initialLocation: '/auth/role-select',
  routes: [
    // Auth
    GoRoute(path: '/auth/role-select',   builder: (_, __) => const RoleSelectScreen()),
    GoRoute(path: '/auth/parent-login',  builder: (_, __) => const ParentLoginScreen()),
    GoRoute(path: '/auth/family-login',  builder: (_, __) => const FamilyLoginScreen()),

    // Senior App (role = parent)
    GoRoute(path: '/senior/home',        builder: (_, __) => const SeniorHomeScreen()),
    GoRoute(path: '/senior/medications', builder: (_, __) => const MedicationTrackerScreen()),
    GoRoute(path: '/senior/call-incoming', builder: (_, s) => AICallIncomingScreen(
      callData: s.extra as Map<String, dynamic>,
    )),
    GoRoute(path: '/senior/call-active', builder: (_, s) => AICallActiveScreen(
      callData: s.extra as Map<String, dynamic>,
    )),
    GoRoute(path: '/senior/dose-history', builder: (_, __) => const DoseHistoryScreen()),
    GoRoute(path: '/senior/emergency',   builder: (_, __) => const EmergencyScreen()),

    // Family App (role = child)
    GoRoute(path: '/family/home',        builder: (_, __) => const FamilyDashboardScreen()),
    GoRoute(path: '/family/alerts',      builder: (_, __) => const FamilyAlertsScreen()),
    GoRoute(path: '/family/reports',     builder: (_, __) => const WeeklyReportScreen()),

    // Web Dashboard
    GoRoute(path: '/dashboard',          builder: (_, __) => const WebDashboardScreen()),
  ],
);
```

**Route guard logic (in app.dart):**
```dart
redirect: (context, state) {
  final user = ref.read(authProvider);
  if (user == null) return '/auth/role-select';
  if (user.role == 'parent' && !state.uri.path.startsWith('/senior'))
    return '/senior/home';
  if (user.role == 'child' && !state.uri.path.startsWith('/family') &&
      !state.uri.path.startsWith('/dashboard'))
    return '/family/home';
  return null;
},
```

---

## 3. Auth Flow — 3 Screens

### Screen A1: RoleSelectScreen

**File:** `lib/screens/auth/role_select_screen.dart`

**Widget tree:**
```
Scaffold
  body: SafeArea
    Column (mainAxisAlignment: center)
      [Logo Container — 44×44, borderRadius:12, color:brandPrimary]
        Text("SC", color:white, fontWeight:bold)
      SizedBox(height:24)
      Text("SeniorCare AI", style:title 20px bold)
      Text("Keeping your loved ones safe", style:label)
      SizedBox(height:32)
      _RoleButton(
        label: "I am a Parent (Senior)",
        subtitle: "Senior citizen monitoring",
        bgColor: parentRoleBg,
        textColor: parentRoleText,
        borderColor: parentRoleBorder,
        onTap: () => context.go('/auth/parent-login'),
      )
      SizedBox(height:12)
      _RoleButton(
        label: "I am Family / Caregiver",
        subtitle: "Monitor my parent remotely",
        bgColor: childRoleBg,
        textColor: childRoleText,
        borderColor: childRoleBorder,
        onTap: () => context.go('/auth/family-login'),
      )
      SizedBox(height:24)
      TextButton("Already have an account? Sign in")
```

**_RoleButton widget:**
```dart
Container(
  width: 280,
  padding: const EdgeInsets.symmetric(horizontal:16, vertical:14),
  decoration: BoxDecoration(
    color: bgColor,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: borderColor, width: 1),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Text(label, style: TextStyle(color:textColor, fontWeight:FontWeight.w600, fontSize:14)),
    Text(subtitle, style: TextStyle(color:textColor.withOpacity(0.7), fontSize:11)),
  ]),
)
```

---

### Screen A2: ParentLoginScreen

**File:** `lib/screens/auth/parent_login_screen.dart`

**RULE: No email field. Big UI for elderly. PIN-only.**

**Widget tree:**
```
Scaffold
  body: SafeArea
    Padding(horizontal:24)
      Column
        Text("Welcome back", style: seniorTitle)
        Text("Senior login", style: seniorLabel)
        SizedBox(16)
        [Phone number pill — purple bg, shows "+91 98765 43210"]
        SizedBox(16)
        Text("Enter your PIN", style: label)
        SizedBox(12)
        [PIN circles row — 4 circles, filled purple when entered]
        SizedBox(24)
        [Numpad — 3×4 grid]
          GridView of NumberKey widgets (40×40, gray bg, rounded)
          Keys: 1-9, blank, 0, del
        SizedBox(16)
        TextButton("Use Face ID instead")
```

**PIN state:**
```dart
final List<int> _pin = [];

void _onKeyTap(String key) {
  if (key == 'del') {
    if (_pin.isNotEmpty) setState(() => _pin.removeLast());
  } else if (_pin.length < 4) {
    setState(() => _pin.add(int.parse(key)));
    if (_pin.length == 4) _submitPin();
  }
}
```

**PIN circles:**
```dart
Row(children: List.generate(4, (i) =>
  Container(
    width: 28, height: 28,
    margin: const EdgeInsets.symmetric(horizontal:8),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: i < _pin.length ? AppColors.parentRoleText : Colors.transparent,
      border: Border.all(
        color: AppColors.parentRoleBorder, width: 1.5,
      ),
    ),
  )
))
```

**Backend:** POST /auth/login { phone, pin } → JWT with custom:role=parent

---

### Screen A3: FamilyLoginScreen

**File:** `lib/screens/auth/family_login_screen.dart`

**Widget tree:**
```
Scaffold
  body: SafeArea
    Padding(horizontal:24)
      Column
        Text("Family login", style: title 18px bold)
        Text("Monitor your parent remotely", style: label)
        SizedBox(20)
        TextField(hint:"Email", style: standard)
        SizedBox(8)
        TextField(hint:"Password", obscureText:true)
        SizedBox(16)
        ElevatedButton("Sign In", color: okText #3B6D11, fullWidth)
        SizedBox(16)
        [Divider with "— or —"]
        SizedBox(16)
        [Invite code container — green bg, rounded]
          Text("Have an invite code?", bold)
          TextField("Enter SMS code from parent")
        SizedBox(16)
        TextButton("New here? Set up monitoring")
```

**Backend:** POST /auth/login { email, password } OR { invite_code } → JWT with custom:role=child

---

## 4. Senior App — 6 Screens

### Screen S1: SeniorHomeScreen (UPDATED)

**File:** `lib/screens/senior/senior_home_screen.dart`

**Changes from v1:** streak badge, pill bar, renamed button, nav rename

**Widget tree:**
```
Scaffold
  bottomNavigationBar: SeniorNavBar(currentIndex: 0)
  body: SafeArea
    Padding(16)
      Column
        Row(mainAxisAlignment: spaceBetween)
          Column
            Text("Good morning, Mr. Sharma", style: seniorTitle)
            Text("Sat, March 14", style: seniorLabel)
          StatusBadge("7 day streak", AppColors.okBg, AppColors.okText)
        SizedBox(12)
        [Vitals 2×2 Grid]
          GridView(crossAxisCount:2, childAspectRatio:1.6)
            VitalCard("Heart Rate", "72", "bpm", AppColors.brandPrimary)
            VitalCard("SpO2", "98", "%", AppColors.okText)
            VitalCard("Steps", "3,241", "", Colors.black87)
            VitalCard("Sleep", "7.2", "h", Colors.black87)
        SizedBox(12)
        [Medication Card — Card widget]
          Text("Next Medication", style: label bold)
          Row(spaceBetween)
            Column
              Text("Metformin 500mg", style: body bold)
              Text("8:00 PM tonight • 12 pills left", style: micro)
            StatusBadge("Taken", okBg, okText)
          PillProgressBar(value: 0.85, color: AppColors.pillFull)
        SizedBox(16)
        ElevatedButton("Call Arjun", brandPrimary, fullWidth, height:48)
```

**SeniorNavBar:**
```dart
BottomNavigationBar(
  currentIndex: currentIndex,
  selectedItemColor: AppColors.brandPrimary,
  unselectedItemColor: Colors.grey,
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.medication), label: 'Meds'),
    BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Family'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
)
```

**Data:** GET /api/senior-summary?senior_id from JWT

---

### Screen S2: MedicationTrackerScreen (UPDATED)

**File:** `lib/screens/senior/medication_tracker_screen.dart`

**Changes from v1:** Missed badge, pill bars, history link

**Medication card model:**
```dart
// lib/models/medication.dart
enum DoseStatus { taken, missed, pending, low }

class Medication {
  final String id, name, dosage;
  final String scheduledTime;
  final int pillsRemaining;
  final DoseStatus status;
  final String? takenAt; // "08:07" if taken
}
```

**Badge logic (lib/utils/dose_badge_logic.dart):**
```dart
BadgeData getDoseBadge(Medication med) {
  final now = TimeOfDay.now();
  final scheduled = parseTime(med.scheduledTime);

  if (med.status == DoseStatus.taken)
    return BadgeData("Done ${med.takenAt}", AppColors.okBg, AppColors.okText);

  if (isAfterTime(now, scheduled) && med.status != DoseStatus.taken)
    return BadgeData("Missed", AppColors.criticalBg, AppColors.criticalText);

  if (med.pillsRemaining < 5)
    return BadgeData("Low", AppColors.warningBg, AppColors.warningText);

  return BadgeData("Pending", AppColors.aiActionBg, AppColors.aiActionText);
}
```

**Widget tree per medication:**
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: _getBorderColor(med), width: 0.5),
  ),
  child: Column(children:[
    Row(mainAxisAlignment: spaceBetween, children:[
      Column(children:[
        Text(med.name, style: body bold),
        Text("${med.scheduledTime} • ${med.pillsRemaining} pills",
          style: micro,
          color: med.status==missed ? criticalText : gray,
        ),
      ]),
      StatusBadge(from: getDoseBadge(med)),
    ]),
    PillProgressBar(
      value: med.pillsRemaining / 30.0,
      color: _getPillBarColor(med),
    ),
  ]),
)
```

**PillProgressBar widget:**
```dart
// lib/widgets/pill_progress_bar.dart
class PillProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color color;

  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
```

---

### Screen S3: AICallIncomingScreen (UNCHANGED)

**File:** `lib/screens/senior/ai_call_incoming_screen.dart`

```
Scaffold(backgroundColor: white)
  body: Center
    Column(mainAxisAlignment: center)
      AIAvatarWidget(size:80, pulsing:false)
      SizedBox(16)
      Text("SeniorCare AI", style: seniorTitle)
      Text("Health Check Call", style: label)
      SizedBox(12)
      Container(speechBubble style)
        Text('"Good morning Mr. Sharma! Did you take your Lisinopril today?"')
      SizedBox(32)
      Row(mainAxisAlignment: center)
        CallActionButton(icon:Icons.call_end, color:criticalBg, label:"Decline",
          onTap: () => context.pop())
        SizedBox(40)
        CallActionButton(icon:Icons.call, color:okBg, label:"Answer",
          onTap: () => context.go('/senior/call-active', extra: callData))
```

---

### Screen S4: AICallActiveScreen — NEW ⭐ WOW DEMO SCREEN

**File:** `lib/screens/senior/ai_call_active_screen.dart`

**IMPORTANT: Must have pulsing animation on avatar border.**

```
Scaffold
  body: SafeArea
    Column(mainAxisAlignment: center)
      AIAvatarWidget(size:80, pulsing:true)   ← pulsing animation
      SizedBox(8)
      CallTimerWidget()                        ← "SeniorCare AI — 0:34"
      SizedBox(20)
      [AI Speech bubble — aiActionBg container, rounded]
        Text("AI is asking:", style: label blue bold)
        Text('"Did you take your Lisinopril at 2 PM today?"')
      SizedBox(20)
      Row
        Expanded
          OutlinedButton("Yes, taken",
            style: okBg bg, okText text, border:okBorder)
          onTap: _confirmDoseTaken
        SizedBox(12)
        Expanded
          OutlinedButton("No, missed",
            style: criticalBg bg, criticalText text, border:criticalBorder)
          onTap: _reportDoseMissed
      SizedBox(16)
      TextButton("End Call", style: red text)
```

**AIAvatarWidget — pulsing animation:**
```dart
// lib/widgets/ai_avatar_widget.dart
class AIAvatarWidget extends StatefulWidget {
  final double size;
  final bool pulsing;
}

class _AIAvatarWidgetState extends State<AIAvatarWidget>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.aiActionBg,
          border: Border.all(color: AppColors.brandPrimary, width: 2),
          boxShadow: widget.pulsing ? [
            BoxShadow(
              color: AppColors.brandPrimary.withOpacity(0.4),
              blurRadius: _animation.value,
              spreadRadius: _animation.value / 2,
            )
          ] : [],
        ),
        child: Center(
          child: Text("AI",
            style: TextStyle(color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold, fontSize: widget.size * 0.25)),
        ),
      ),
    );
  }
}
```

**Backend on response:**
```dart
Future<void> _confirmDoseTaken() async {
  await apiService.confirmDose(
    seniorId: authProvider.seniorId,
    medId: callData['med_id'],
    confirmedBy: 'call',
  );
  // show success snackbar then pop
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dose confirmed. Family notified.'),
        backgroundColor: AppColors.okText)
    );
    context.go('/senior/home');
  }
}
```

---

### Screen S5: DoseHistoryScreen — NEW

**File:** `lib/screens/senior/dose_history_screen.dart`

```
Scaffold
  appBar: AppBar("Dose History", actions:[adherence badge "95%"])
  body:
    Column
      [Week calendar strip — Row of 7 DayIndicator widgets]
        Each: Column(letter label + Circle(color based on status))
      Divider
      [Dose list — ListView of DoseGroupWidget]
        DoseGroupWidget("Metformin 500mg")
          DoseRow(time:"8:00 AM", takenAt:"8:07 AM", status:taken)  ← green
        DoseGroupWidget("Lisinopril 10mg")
          DoseRow(time:"2:00 PM", takenAt:null, status:missed)       ← red
          Text("AI called at 2:32 PM", style:micro red)
        DoseGroupWidget("Aspirin 75mg")
          DoseRow(time:"8:00 PM", takenAt:null, status:pending)      ← blue
```

**DayIndicator widget:**
```dart
Column(children:[
  Text(dayLetter, style: micro),
  Container(
    width: 20, height: 20, margin: EdgeInsets.only(top:2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _getCircleColor(status),
    ),
    child: Center(child: Text(_getCircleLabel(status),
      style: TextStyle(fontSize:7, color:_getCircleTextColor(status)))),
  ),
])
```

**Data:** GET /api/dose-log?senior_id=&week=2026-03-10

---

### Screen S6: EmergencyScreen (UNCHANGED)

```
Scaffold(backgroundColor: criticalBg.withOpacity(0.3))
  body: SafeArea
    Padding(16)
      Text("Emergency", style: seniorTitle)
      Container(criticalBg, rounded)
        Text("Alert Sent to Arjun", critical bold)
        Text("No movement for 6h. Family notified.")
      SizedBox(16)
      Text("Are you okay?", style: seniorBody bold)
      ElevatedButton("Yes, I am fine", okText green, fullWidth)
      SizedBox(8)
      ElevatedButton("Need Help Now", criticalText red, fullWidth)
      SizedBox(16)
      Text("Vitals now", style: label bold)
      Row
        VitalCard("Heart Rate", "128", "bpm", criticalText)
        VitalCard("SpO2", "87%", "", criticalText)
```

---

## 5. Family App — 3 Screens

### Screen F1: FamilyDashboardScreen (UPDATED)

**File:** `lib/screens/family/family_dashboard_screen.dart`

**Changes from v1:** streak+adherence, AI call in timeline, pill warning row

```
Scaffold
  bottomNavigationBar: FamilyNavBar(currentIndex:0)
  body: SafeArea
    Padding(16)
      Row(spaceBetween)
        Text("Dad's Health", style:title bold)
        StatusBadge("All Good", okBg, okText)
      SizedBox(12)
      [Parent Card — Card]
        Row
          CircleAvatar("MS", bg:aiActionBg, text:brandPrimary)
          Column
            Text("Mr. Sharma", bold)
            Text("Menindoma, India • 2m ago", micro)
          Column(crossAxisAlignment:end)
            Text("7 day streak", micro green)
            Text("95% adherence", micro)
        SizedBox(8)
        Row
          VitalChip("HR", "72")
          VitalChip("SpO2", "98%")
          VitalChip("Steps", "3.2k")
      SizedBox(12)
      Text("Today's Activity", style: label bold)
      [Activity timeline — Column of ActivityRow widgets]
        ActivityRow(color:okText,      "8:07 AM — Metformin taken")
        ActivityRow(color:brandPrimary, "10:30 AM — 30 min walk")
        ActivityRow(color:brandPrimary, "1:04 PM — AI call: confirmed dose")
        ActivityRow(color:warningText,  "Lisinopril: 3 pills — refill ordered")
      SizedBox(16)
      ElevatedButton("Video Call Mr. Sharma", brandPrimary, fullWidth)
```

**FamilyNavBar:**
```dart
BottomNavigationBar(items: [
  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
  BottomNavigationBarItem(icon: Icon(Icons.medication_liquid), label: 'Dosage'),
  BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
  BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
])
```

---

### Screen F2: FamilyAlertsScreen (UPDATED)

**File:** `lib/screens/family/family_alerts_screen.dart`

**Changes from v1:** Added AI Action type

**Alert types:**
```dart
enum AlertType { critical, aiAction, warning, info }

class Alert {
  final AlertType type;
  final String message;
  final String time;
  final bool hasCta;
  final String? ctaLabel;
}
```

**AlertRow widget (CRITICAL RULE: no borderRadius when using left border):**
```dart
// lib/widgets/alert_row.dart
class AlertRow extends StatelessWidget {
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _getBgColor(alert.type),
        border: Border(
          left: BorderSide(color: _getBorderColor(alert.type), width: 2),
        ),
        // NO borderRadius — single-side border requires border-radius: 0
      ),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          Text(_getTypeLabel(alert.type),
            style: TextStyle(color: _getBorderColor(alert.type),
              fontWeight: FontWeight.w600, fontSize:10)),
          Text(alert.time, style: TextStyle(fontSize:9,
            color: _getBorderColor(alert.type))),
        ]),
        SizedBox(height:4),
        Text(alert.message,
          style: TextStyle(fontSize:11, color: _getTextColor(alert.type))),
        if (alert.hasCta) ...[
          SizedBox(height:6),
          Container(
            color: AppColors.criticalText,
            padding: const EdgeInsets.symmetric(vertical:4, horizontal:8),
            child: Text(alert.ctaLabel!, style: const TextStyle(
              color:Colors.white, fontSize:9, fontWeight:FontWeight.w600)),
          ),
        ],
      ]),
    );
  }

  Color _getBgColor(AlertType t) => switch(t) {
    AlertType.critical => AppColors.criticalBg,
    AlertType.aiAction => AppColors.aiActionBg,
    AlertType.warning  => AppColors.warningBg,
    AlertType.info     => AppColors.okBg,
  };
}
```

---

### Screen F3: WeeklyReportScreen (UNCHANGED)

```
Scaffold
  bottomNavigationBar: FamilyNavBar(currentIndex:1)
  body:
    Padding(16)
      Text("Weekly Report", title bold)
      Text("Mar 7 – Mar 14, 2026", micro)
      SizedBox(12)
      GridView(crossAxisCount:2)
        MetricCard("Avg HR", "74", "bpm")
        MetricCard("Adherence", "95%", "", green)
        MetricCard("Avg Sleep", "6.8h", "")
        MetricCard("Avg Steps", "3.4k", "")
      SizedBox(12)
      [AI Summary box — aiActionBg container]
        Text("AI Summary", aiActionText bold small)
        Text("Stable week. Sleep up 12%. 1 missed dose Wed — AI intervened.")
      SizedBox(12)
      Text("Steps this week", label)
      [Bar chart — use fl_chart package]
        BarChart with 7 bars, Thu highlighted in brandPrimary
```

---

## 6. Web Dashboard — Flutter Web

### Screen W1: WebDashboardScreen (UPDATED)

**File:** `lib/screens/web/web_dashboard_screen.dart`

**Layout:** Responsive Row. On wide screen (>900px): sidebar + main. On narrow: drawer.

```
Scaffold
  appBar: AppBar(
    backgroundColor: brandDark,
    title: Row
      [SC logo box]
      Text("SeniorCare AI", brandLight)
      Spacer()
      Container(criticalBg) Text("1 Critical Alert")
      CircleAvatar("AS")
  )
  body: Row
    [Sidebar — 120px wide]
      NavigationRail or custom Column
      Items:
        SidebarItem("Overview", active: true)
        SidebarItem("Vitals")
        SidebarItem("Medications")
        SidebarItem("Dosage Log", isNew: true)   ← NEW
        SidebarItem("Sleep")
        SidebarItem("Activity")
        SidebarItem("Alerts")
        SidebarItem("Call History", isNew: true)  ← NEW
        SidebarItem("Settings")
    VerticalDivider(width:1)
    [Main area — Expanded]
      Padding(12)
        [5 metric cards — Row]
          DashMetricCard("Heart Rate", "72 bpm", "Normal range", brandPrimary)
          DashMetricCard("SpO2", "98%", "Excellent", okText)
          DashMetricCard("Dose Streak", "7 days", "95% adherence", okText)
          DashMetricCard("Last AI Call", "1:04 PM", "Confirmed dose", brandPrimary)
          DashMetricCard("Steps Today", "3,241", "Goal: 5,000", Colors.black87)
        SizedBox(12)
        Text("Recent Alerts", style: label bold)
        [Alert feed — 4 rows]
          DashAlertRow(critical, "No movement 6h — SpO2 87%", "2h ago", cta:"Call Now")
          DashAlertRow(aiAction, "AI called Mr. Sharma. Confirmed dose 1:04 PM", "1:04 PM")
          DashAlertRow(warning,  "Lisinopril low (3 pills). Refill placed.", "Yesterday")
          DashAlertRow(info,     "Morning medication 8:07 AM", "8:07 AM")
```

---

## 7. Connection Flow Widget

**Show this between Senior and Family sections on the mockup overview page:**

```dart
// Connection flow chip row
Wrap(
  spacing: 8, runSpacing: 8,
  alignment: WrapAlignment.center,
  children: [
    FlowChip("Login (Cognito)",     AppColors.parentRoleBg, AppColors.parentRoleBorder, AppColors.parentRoleText),
    _Arrow(),
    FlowChip("Samsung Watch",       Colors.white, Colors.grey, Colors.black87),
    _Arrow(),
    FlowChip("Health SDK",          Colors.white, Colors.grey, Colors.black87),
    _Arrow(),
    FlowChip("Senior App",          Colors.white, Colors.grey, Colors.black87),
    _Arrow(),
    FlowChip("API Gateway",         Colors.white, Colors.grey, Colors.black87),
    _Arrow(),
    FlowChip("Railtracks + Claude", AppColors.aiActionBg, AppColors.aiActionBorder, AppColors.aiActionText),
    _Arrow(),
    FlowChip("Twilio Call",         AppColors.criticalBg, AppColors.criticalBorder, AppColors.criticalText),
    _Arrow(),
    FlowChip("Family App",          Colors.white, Colors.grey, Colors.black87),
  ],
)
```

---

## 8. API Service

```dart
// lib/services/api_service.dart
class ApiService {
  final String baseUrl = 'https://your-api-id.execute-api.region.amazonaws.com/prod';
  String? _jwtToken;

  void setToken(String token) => _jwtToken = token;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_jwtToken',
    'Content-Type': 'application/json',
  };

  Future<Map> login({String? phone, String? pin, String? email,
      String? password, String? inviteCode}) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (phone != null) 'phone': phone,
        if (pin != null) 'pin': pin,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (inviteCode != null) 'invite_code': inviteCode,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map> getSeniorSummary(String seniorId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/senior-summary?senior_id=$seniorId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<List> getMedications(String seniorId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/medications?senior_id=$seniorId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<void> confirmDose({required String seniorId, required String medId,
      required String confirmedBy}) async {
    await http.post(Uri.parse('$baseUrl/api/dose/confirm'),
      headers: _headers,
      body: jsonEncode({
        'senior_id': seniorId,
        'med_id': medId,
        'confirmed_by': confirmedBy,
      }),
    );
  }

  Future<List> getDoseLog(String seniorId, String week) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/dose-log?senior_id=$seniorId&week=$week'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<List> getAlerts(String seniorId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/alerts?senior_id=$seniorId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }
}
```

---

## 9. pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^13.0.0
  flutter_riverpod: ^2.5.0
  http: ^1.2.0
  fl_chart: ^0.67.0         # bar charts for weekly report
  shared_preferences: ^2.2.0
  intl: ^0.19.0              # date formatting
  amazon_cognito_identity_dart_auth: ^3.6.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

---

## 10. Mock Data (for demo without backend)

```dart
// lib/mock_data.dart
final normalDay = {
  "senior_id": "senior_001",
  "heart_rate": 72, "spo2": 98, "steps": 3241,
  "last_movement_mins": 15, "sleep_hours": 7.2,
  "pills_remaining": 12, "missed_doses": 0,
  "streak_days": 7, "adherence_pct": 95,
};

final criticalAlert = {
  "senior_id": "senior_001",
  "heart_rate": 128, "spo2": 87, "steps": 200,
  "last_movement_mins": 380, "sleep_hours": 4.1,
  "pills_remaining": 3, "missed_doses": 2,
};
```

---

## 11. Screen Inventory — 13 Screens

| Screen | File | Status | Priority |
|---|---|---|---|
| A1: Role Select | auth/role_select_screen.dart | NEW | P0 |
| A2: Parent Login | auth/parent_login_screen.dart | NEW | P0 |
| A3: Family Login | auth/family_login_screen.dart | NEW | P0 |
| S1: Senior Home | senior/senior_home_screen.dart | Updated | P0 |
| S2: Medication Tracker | senior/medication_tracker_screen.dart | Updated | P0 |
| S3: AI Incoming Call | senior/ai_call_incoming_screen.dart | Unchanged | P0 |
| S4: AI Call Active | senior/ai_call_active_screen.dart | NEW ⭐ | P0 |
| S5: Dose History | senior/dose_history_screen.dart | NEW | P1 |
| S6: Emergency Alert | senior/emergency_screen.dart | Unchanged | P0 |
| F1: Family Dashboard | family/family_dashboard_screen.dart | Updated | P0 |
| F2: Family Alerts | family/family_alerts_screen.dart | Updated | P0 |
| F3: Weekly Report | family/weekly_report_screen.dart | Unchanged | P1 |
| W1: Web Dashboard | web/web_dashboard_screen.dart | Updated | P0 |

---

## 12. Build Order for Claude Code

```
Step 1:  lib/theme/app_theme.dart — ALL colors + text styles
Step 2:  lib/widgets/ — all shared widgets (PillProgressBar, AIAvatarWidget,
         AlertRow, StatusBadge, VitalCard, SeniorNavBar, FamilyNavBar)
Step 3:  lib/models/ — Medication, DoseLog, Alert, HealthData, User
Step 4:  lib/services/api_service.dart
Step 5:  lib/app.dart — GoRouter setup
Step 6:  Auth screens: A1 → A2 → A3
Step 7:  Senior screens: S1 → S2 → S3 → S4 (WOW) → S5 → S6
Step 8:  Family screens: F1 → F2 → F3
Step 9:  Web dashboard: W1 (responsive layout)
Step 10: Wire navigation + auth state
Step 11: Connect to mock_data.dart for demo
```

---

## 13. Critical Rules — Do Not Violate

1. **Senior App text minimum 14px.** Use seniorBody/seniorTitle styles. Max 2 actions per screen.
2. **AlertRow: no borderRadius when using left Border.** Flutter's Border() with single side
   does NOT work with borderRadius — use BoxDecoration with Border() only, no borderRadius.
3. **PillProgressBar on every medication card.** Green >50%, Red <20%, Blue = pending.
4. **DoseBadge logic:** past-due + not taken = Missed (red). Future = Pending (blue).
   Confirmed = Done HH:MM (green). Pills < 5 = Low (amber).
5. **FamilyNavBar = Home | Dosage | Alerts | Settings.** NOT Reports.
6. **AI Action alert = blue** (aiActionBg). Only when Claude/Twilio took autonomous action.
7. **AIAvatarWidget pulsing = AnimationController 1500ms repeat reverse:true.**
   Use BoxShadow with animated blurRadius for pulse glow effect.
8. **Every API call uses seniorId from JWT / authProvider.** Never hardcode seniorId.
9. **Web dashboard = 5 DashMetricCards:** HR, SpO2, Dose Streak, Last AI Call, Steps.
10. **Dosage Log and Call History sidebar items are real screens**, not placeholders.
11. **Flutter Web responsive:** use LayoutBuilder to switch between sidebar (>900px)
    and drawer (<900px) for the web dashboard.
12. **Use GoRouter for all navigation.** No Navigator.push() directly.
    Pass data via extra parameter for call screens.

---

*Generated from SeniorCare AI UI v2 — Flutter edition — 13 screens, March 2026*
