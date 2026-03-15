# seniorcare-ui — Complete Frontend Documentation

> **ElderHarmony** Flutter/Dart frontend for the AI-powered elderly care system.
> Role-based mobile + web app for seniors, family members, and a web dashboard.

---

## Table of Contents

1. [Project Configuration](#project-configuration)
2. [lib/ — Application Source Code](#lib--application-source-code)
   - [Entry Point & Routing](#entry-point--routing)
   - [Mock Data Layer](#mock-data-layer)
   - [models/](#models)
   - [providers/](#providers)
   - [services/](#services)
   - [theme/](#theme)
   - [utils/](#utils)
   - [screens/](#screens)
     - [screens/auth/](#screensauth)
     - [screens/senior/](#screenssenior)
     - [screens/family/](#screensfamily)
     - [screens/web/](#screensweb)
   - [widgets/](#widgets)
3. [test/](#test)
4. [web/](#web)
5. [android/](#android)
6. [UI Bugs & Errors](#ui-bugs--errors)

---

## Project Configuration

### `pubspec.yaml`
- **Package name:** `seniorcare_ui`
- **SDK:** Dart `^3.8.1`
- **Key dependencies:**
  - `go_router: ^13.0.0` — Declarative routing with role-based guards and redirects.
  - `flutter_riverpod: ^2.5.0` — State management (ChangeNotifierProvider for auth).
  - `http: ^1.2.0` — HTTP client (not currently used; API calls are mocked).
  - `fl_chart: ^0.67.0` — Bar charts for weekly reports (steps chart).
  - `shared_preferences: ^2.2.0` — Local persistence (declared but not actively used yet).
  - `intl: ^0.19.0` — Internationalization/date formatting.
- **Dev dependencies:** `flutter_test`, `flutter_lints: ^5.0.0`

### `analysis_options.yaml`
- Includes `package:flutter_lints/flutter.yaml` for recommended lint rules.
- No custom rule overrides enabled.

---

## lib/ — Application Source Code

### Entry Point & Routing

#### `lib/main.dart`
- **Purpose:** Application entry point.
- **How it works:** Calls `runApp()` wrapping the app in Riverpod's `ProviderScope` for state management, then renders `SeniorCareApp`.
- **Key detail:** `ProviderScope` is the root widget that enables all Riverpod providers throughout the app.

#### `lib/app.dart`
- **Purpose:** Defines `SeniorCareApp` (the `MaterialApp.router`) and the full GoRouter configuration.
- **Router provider:** `routerProvider` is a Riverpod `Provider<GoRouter>` that reads `authProvider` for redirect logic.
- **Redirect logic:**
  - If user is **not logged in** and not on an `/auth/*` route → redirect to `/auth/role-select`.
  - If user **is logged in** and is on an `/auth/*` route → redirect based on role: `parent` → `/senior/home`, `child` → `/family/home`.
- **15 defined routes:**

| Route Path | Screen | Role |
|---|---|---|
| `/auth/role-select` | `RoleSelectScreen` | All |
| `/auth/parent-login` | `ParentLoginScreen` | Senior |
| `/auth/family-login` | `FamilyLoginScreen` | Family |
| `/senior/home` | `SeniorHomeScreen` | Senior |
| `/senior/medications` | `MedicationTrackerScreen` | Senior |
| `/senior/call-incoming` | `AICallIncomingScreen` | Senior |
| `/senior/call-active` | `AICallActiveScreen` | Senior |
| `/senior/dose-history` | `DoseHistoryScreen` | Senior |
| `/senior/emergency` | `EmergencyScreen` | Senior |
| `/family/home` | `FamilyDashboardScreen` | Family |
| `/family/alerts` | `FamilyAlertsScreen` | Family |
| `/family/reports` | `WeeklyReportScreen` | Family |
| `/dashboard` | `WebDashboardScreen` | Web |
| `/dashboard/dosage-log` | `DosageLogScreen` | Web |
| `/dashboard/call-history` | `CallHistoryScreen` | Web |

- **Route extras:** `/senior/call-incoming` and `/senior/call-active` expect `state.extra` to be `Map<String, String>` (callData with `question` and `fromLLM` keys).

---

### Mock Data Layer

#### `lib/mock_data.dart`
- **Purpose:** Hardcoded constants that serve as the entire data layer. All screens pull from these values instead of a real API.
- **Constants defined:**
  - `seniorName` = `'Mr. Sharma'`, `familyName` = `'Arjun'`
  - **Normal vitals:** `normalHeartRate` (72), `normalSpo2` (98), `normalSteps` (3241), `normalSleep` (7.2), `normalPillCount` (12)
  - **Critical vitals:** `criticalHeartRate` (128), `criticalSpo2` (87), `criticalSteps` (200), `criticalIdleMinutes` (380)
  - **Weekly report:** `weeklyAvgHR` (71), `weeklyAdherence` (95), `weeklyAvgSleep` (7.1), `weeklyAvgSteps` ('3.2k'), `weeklySteps` (7-element list), `weeklyAISummary` (multi-line AI-generated text), `weekDoseStatus` (7-day status list)
  - **Location/streak:** `location` ('Living Room'), `normalStreakDays` (7), `normalAdherencePct` (95)
  - `mockMedications` — List of 3 `Medication` objects: Metformin (taken), Lisinopril (missed), Aspirin (pending).
  - `mockAlerts` — List of 4 `Alert` objects: critical (SpO2 drop), aiAction (auto-refill), warning (Lisinopril missed), info (morning vitals normal).
  - `mockDoseLog` — `DoseLog` with 3 `DoseEntry` items covering taken, missed (with AI note), and pending states.
  - `mockCallHistory` — List of 4 Maps with `time`, `target`, `reason`, `duration`, `outcome` keys.

---

### models/

#### `lib/models/alert.dart`
- **`AlertType` enum:** `critical`, `aiAction`, `warning`, `info` — categorizes alert severity.
- **`Alert` class:** Holds `type` (AlertType), `message` (String), `time` (String), `hasCta` (bool), `ctaLabel` (String?) for call-to-action buttons.

#### `lib/models/dose_log.dart`
- **`DoseEntry` class:** `medName`, `scheduledTime`, `takenAt?`, `status` (DoseStatus), `aiNote?`. Represents one dose event.
- **`DoseLog` class:** `date` (String), `entries` (List of DoseEntry). Groups dose events by day.

#### `lib/models/health_data.dart`
- **`HealthData` class:** Maps directly to the backend's `HealthPayload` dataclass.
- **Fields:** `heartRate`, `spo2`, `steps`, `sleepHours`, `pillCount`, `lastMovementMinutes`, `hrvPercent?`, `fallDetected`, `moodScore?`.
- Mirrors the data contract shared between frontend and backend.

#### `lib/models/medication.dart`
- **`DoseStatus` enum:** `taken`, `missed`, `pending`, `low` — medication status states.
- **`Medication` class:** `id`, `name`, `dosage`, `scheduledTime`, `pillsRemaining`, `status` (DoseStatus), `takenAt?`.

#### `lib/models/user.dart`
- **`User` class:** `id`, `role` (String: `'parent'`/`'child'`), `name`, `phone`, `email?`.
- Determines route access: `parent` role → senior screens, `child` role → family/web screens.

---

### providers/

#### `lib/providers/auth_provider.dart`
- **`AuthNotifier` (extends `ChangeNotifier`):**
  - `_user` — Nullable `User`. Null means logged out.
  - `loginAsParent()` → Creates `User(id: 'senior_001', role: 'parent', name: 'Mr. Sharma', phone: '555-0101')`.
  - `loginAsChild()` → Creates `User(id: 'child_001', role: 'child', name: 'Arjun Sharma', phone: '555-0102', email: 'arjun@example.com')`.
  - `logout()` → Sets `_user = null`, notifies listeners.
- **Exposed as:** `authProvider = ChangeNotifierProvider<AuthNotifier>((_) => AuthNotifier())`.
- The GoRouter reads this provider for redirect decisions.

---

### services/

#### `lib/services/api_service.dart`
- **`ApiService` class:** Fully stubbed API layer returning mock data with `Future.delayed` (500ms simulated latency).
- **Methods:**
  - `getSeniorSummary()` → Returns a Map with mock vitals, medications, alerts.
  - `getMedications()` → Returns `mockMedications`.
  - `confirmDose(String medId)` → Returns `{'success': true}`.
  - `getAlerts()` → Returns `mockAlerts`.
  - `getDoseLog()` → Returns `mockDoseLog`.
- **Not yet connected** to the real backend API Gateway.

---

### theme/

#### `lib/theme/app_theme.dart`
- **`AppColors`** — Semantic color constants organized by alert severity and role:
  - **Critical:** `criticalBg` (red-50), `criticalText` (red-700), `criticalBorder` (red-400)
  - **AI Action:** `aiActionBg` (purple-50), `aiActionText` (purple-700), `aiActionBorder` (purple-400)
  - **Warning:** `warningBg` (amber-50), `warningText` (amber-700), `warningBorder` (amber-400)
  - **OK/Success:** `okBg` (green-50), `okText` (green-700), `okBorder` (green-400)
  - **Role colors:** `parentRoleBg`/`parentRoleText` (purple), `childRoleBg`/`childRoleText` (green)
  - **Brand:** `brandPrimary` (indigo-600), `brandDark` (slate-900)
  - **Pill colors:** `pillFull` (green), `pillPending` (blue), `pillLow` (red)
- **`AppTextStyles`** — Two font-size tiers:
  - **Senior styles:** Larger fonts for elderly readability (title: 18px, seniorBody: 16px min 14px)
  - **Family/Web styles:** Smaller, denser fonts (title: 14px, body: 12px, micro: 9px)
- **`buildAppTheme()`** — Returns a `ThemeData` with custom `ColorScheme`, `AppBarTheme`, `BottomNavigationBarTheme`, and `ElevatedButtonTheme`.

---

### utils/

#### `lib/utils/dose_badge_logic.dart`
- **`BadgeData` class:** `label`, `bgColor`, `textColor` — data for rendering a status badge.
- **`getDoseBadge(Medication med)`** — Pure function returning the appropriate badge:
  - `taken` → label "Done {time}", green colors
  - `missed` → label "Missed", red colors
  - `pillsRemaining < 5` → label "Low", warning colors
  - default (pending) → label "Pending", blue colors

---

### screens/

#### screens/auth/

##### `lib/screens/auth/role_select_screen.dart`
- **Purpose:** Initial screen where user chooses their role.
- **UI:** App logo/name, two large buttons — "I'm a Senior" → `/auth/parent-login` and "I'm a Family Member" → `/auth/family-login`.
- **Bottom link:** "Already have an account? Sign in" — **currently a no-op (`onPressed: () {}`)**.

##### `lib/screens/auth/parent_login_screen.dart`
- **Purpose:** PIN-based login for seniors.
- **UI:** 4-dot PIN indicator, numeric keypad (1-9, 0, backspace), "Use Face ID instead" option.
- **Logic:** PIN validation against hardcoded `'1234'`. On match → calls `authProvider.loginAsParent()` → navigates to `/senior/home`. Incorrect PIN shows SnackBar error.
- **Back arrow:** navigates to `/auth/role-select`.
- **"Use Face ID instead"** — **currently a no-op**.

##### `lib/screens/auth/family_login_screen.dart`
- **Purpose:** Email/password login for family members.
- **UI:** Email field, password field, invite code field ("Optional"), "Sign In" button.
- **Logic:** No validation. Calls `authProvider.loginAsChild()` → navigates to `/family/home` regardless of input.
- **Back arrow:** navigates to `/auth/role-select`.
- **"New here? Set up monitoring"** — **currently a no-op**.

---

#### screens/senior/

##### `lib/screens/senior/senior_home_screen.dart`
- **Purpose:** Main dashboard for the senior user.
- **UI:**
  - Greeting header: "Good afternoon, Mr. Sharma" with "All Good" badge.
  - 2×2 vitals grid using `VitalCard` widgets: Heart Rate (72 bpm), SpO₂ (98%), Steps (3,241), Sleep (7.2h).
  - Next medication card showing upcoming med name, dosage, time, pills remaining, and `PillProgressBar`.
  - "Call Arjun" ElevatedButton → navigates to `/senior/call-incoming` with `callData` extra.
- **Nav:** `SeniorNavBar(currentIndex: 0)`.

##### `lib/screens/senior/medication_tracker_screen.dart`
- **Purpose:** Lists all medications with status and actions.
- **UI:**
  - Header "My Medications" with pill count badge.
  - Auto-refill success banner (green, for Lisinopril).
  - List of `MedicationCard` widgets for each `mockMedication`.
  - "Mark as Taken" ElevatedButton — **currently a no-op (`onPressed: () {}`)**.
  - "View dose history" TextButton → navigates to `/senior/dose-history`.
- **Nav:** `SeniorNavBar(currentIndex: 1)`.

##### `lib/screens/senior/ai_call_incoming_screen.dart`
- **Purpose:** Simulates an incoming AI call to the senior.
- **UI:** Gray overlay, `AIAvatarWidget`, speech bubble displaying the AI question from `callData['question']`.
- **Actions:**
  - "Decline" → navigate to `/senior/home`.
  - "Answer" (green phone icon) → navigate to `/senior/call-active` passing `callData`.
- **Data:** Receives `callData` (Map<String, String>) via `GoRouter` `state.extra`.

##### `lib/screens/senior/ai_call_active_screen.dart`
- **Purpose:** Active AI call screen with dose confirmation.
- **UI:** Pulsing `AIAvatarWidget`, `CallTimerWidget`, AI question bubble, two action buttons.
- **Actions:**
  - "Yes, taken" → SnackBar "Dose confirmed" → navigate to `/senior/home`.
  - "No, missed" → SnackBar "Marked as missed" → navigate to `/senior/home`.
  - "End Call" (red button) → navigate to `/senior/home`.
- **Data:** Receives `callData` via `GoRouter` `state.extra`.

##### `lib/screens/senior/dose_history_screen.dart`
- **Purpose:** Shows a week-by-week dose calendar and entry log.
- **UI:**
  - Week calendar strip (M–S) with color-coded circles: green check (taken), red "!" (missed), gray "-" (future/none).
  - Dose entry rows from `mockDoseLog.entries`, each color-coded by status.
  - AI notes shown in red under entries that have them.
- **Nav:** `SeniorNavBar(currentIndex: 1)`.

##### `lib/screens/senior/emergency_screen.dart`
- **Purpose:** Emergency alert screen triggered by critical health events.
- **UI:** Red-tinted background, alert box "Alert Sent to Arjun", "Are you OK, Mr. Sharma?" heading.
- **Actions:**
  - "Yes, I am fine" → navigate to `/senior/home`.
  - "Need Help Now" — **currently a no-op (`onPressed: () {}`)**.
- **Vitals display:** Shows critical values (HR 128, SpO₂ 87%) using `VitalCard` widgets.

---

#### screens/family/

##### `lib/screens/family/family_dashboard_screen.dart`
- **Purpose:** Family member's overview of the senior's status.
- **UI:**
  - Header "Dad's Health" with "All Good" badge.
  - Parent card: Name, location ("Living Room • 2m ago"), streak ("7 day streak"), adherence ("95%"), vital chips (HR, SpO₂, Steps).
  - "Today's Activity" section: 4 activity rows with color-coded dots.
  - "Video Call Mr. Sharma" button — **currently a no-op (`onPressed: () {}`)**.
- **Nav:** `FamilyNavBar(currentIndex: 0)`.

##### `lib/screens/family/family_alerts_screen.dart`
- **Purpose:** List of all alerts for the family member.
- **UI:** AppBar with title "Alerts", `ListView.builder` rendering `AlertRow` for each `mockAlert`.
- **Bug:** `AlertRow` widgets are rendered **without** `onCtaTap` callback, so CTA buttons (like "Call 911 now" on critical alerts) are **not functional**.
- **Nav:** `FamilyNavBar(currentIndex: 2)`.

##### `lib/screens/family/weekly_report_screen.dart`
- **Purpose:** Weekly health summary with charts.
- **UI:**
  - Header "Weekly Report" with date range "Mar 7 – Mar 14, 2026".
  - 2×2 metric grid: Avg HR (71 bpm), Adherence (95%), Avg Sleep (7.1h), Avg Steps (3.2k).
  - AI Summary box (purple bg) with generated weekly analysis text.
  - "Steps this week" bar chart using `fl_chart` `BarChart` with 7 bars (Mon–Sun).
- **Nav:** `FamilyNavBar(currentIndex: 1)`.

---

#### screens/web/

##### `lib/screens/web/web_dashboard_screen.dart`
- **Purpose:** Full web dashboard for family members (responsive layout).
- **UI:**
  - AppBar: "SeniorCare AI" branding, "1 Critical Alert" badge, user avatar "AS".
  - Responsive: >900px shows sidebar + content; ≤900px shows content only with Drawer.
  - **Sidebar (9 items):** Overview, Vitals, Medications, Dosage Log (NEW), Sleep, Activity, Alerts, Call History (NEW), Settings.
  - **Main content:** 5 `_DashMetricCard` widgets (Heart Rate, SpO₂, Dose Streak, Last AI Call, Steps Today) + Recent Alerts list.
- **Navigation:** Only "Dosage Log" and "Call History" sidebar items navigate to sub-routes (`/dashboard/dosage-log`, `/dashboard/call-history`). **All other sidebar items only highlight but don't change content.**
- **StatefulWidget** with `_selectedIndex` for sidebar highlighting.

##### `lib/screens/web/dosage_log_screen.dart`
- **Purpose:** Detailed dosage log view for the web dashboard.
- **UI:**
  - AppBar "Dosage Log" with back arrow → `/dashboard`.
  - Week picker: "Week of Mar 10 – 16, 2026" with adherence percentage.
  - Week calendar strip (Mon–Sun) with color-coded circles.
  - Dose entries from `mockDoseLog.entries`: colored rows by status (green=taken, red=missed, blue=pending), AI notes in red.
- **Helper methods:** `_getRowColor()` and `_getTextColor()` use Dart 3 switch expressions on `DoseStatus`.

##### `lib/screens/web/call_history_screen.dart`
- **Purpose:** AI call history log for the web dashboard.
- **UI:**
  - AppBar "Call History" with back arrow → `/dashboard`.
  - `ListView.separated` of `mockCallHistory` entries.
  - Each row: AI avatar circle, time, target name, reason, duration, outcome badge (green for "Confirmed", blue for others).

---

### widgets/

#### `lib/widgets/activity_row.dart`
- **Purpose:** Single row showing a timestamped activity event.
- **UI:** Small colored dot + text description.
- **Props:** `dotColor` (Color), `text` (String).
- **Used in:** `FamilyDashboardScreen`.

#### `lib/widgets/ai_avatar_widget.dart`
- **Purpose:** Animated circular AI avatar with optional pulsing effect.
- **StatefulWidget** with `SingleTickerProviderStateMixin` for animation.
- **Props:** `size` (double), `pulsing` (bool, default false).
- **Animation:** `AnimationController` (1500ms) drives a `Tween<double>(0→12)` controlling `BoxShadow` spread/blur for the pulse effect.
- **Used in:** `AICallIncomingScreen`, `AICallActiveScreen`.

#### `lib/widgets/alert_row.dart`
- **Purpose:** Color-coded alert card with severity indicator and optional CTA button.
- **Props:** `alert` (Alert), `onCtaTap` (VoidCallback?, optional).
- **UI:** Left border colored by severity, type label (CRITICAL/AI ACTION/WARNING/INFO), message text, optional CTA button.
- **Helper methods:** `_getBgColor()`, `_getBorderColor()`, `_getTypeLabel()` — all use Dart 3 switch expressions on `AlertType`.
- **Used in:** `FamilyAlertsScreen`, `WebDashboardScreen`.

#### `lib/widgets/badge_widget.dart`
- **Purpose:** Small colored status badge (pill-shaped label).
- **Props:** `label` (String), `bgColor` (Color), `textColor` (Color).
- **Used in:** `SeniorHomeScreen`, `FamilyDashboardScreen`, `MedicationCard`, `CallHistoryScreen`.

#### `lib/widgets/call_timer_widget.dart`
- **Purpose:** Live call duration timer.
- **StatefulWidget** with `Timer.periodic` (1s interval).
- **Display:** "SeniorCare AI — M:SS" format, incrementing every second.
- **Cleanup:** Timer cancelled in `dispose()`.
- **Used in:** `AICallActiveScreen`.

#### `lib/widgets/family_nav_bar.dart`
- **Purpose:** Bottom navigation bar for family-role screens.
- **4 tabs:** Home (`/family/home`), Dosage (`/family/reports`), Alerts (`/family/alerts`), Settings (placeholder no-op).
- **Props:** `currentIndex` (int) for active tab highlighting.
- **Note:** "Dosage" tab label navigates to the `WeeklyReportScreen` at `/family/reports`, not a dedicated dosage view.

#### `lib/widgets/medication_card.dart`
- **Purpose:** Card showing a single medication's name, schedule, status badge, and pill progress bar.
- **Props:** `med` (Medication).
- **UI:** Name + time/pills row, `StatusBadge` (via `getDoseBadge()`), `PillProgressBar` (pills/30 ratio).
- **Color logic:** Border color varies by status; pill bar color varies by remaining ratio.
- **Used in:** `MedicationTrackerScreen`.

#### `lib/widgets/phone_metric_card.dart`
- **Actual class name:** `VitalCard` (file is named `phone_metric_card.dart`).
- **Purpose:** Displays a single health metric (label, value, unit) in a card.
- **Props:** `label`, `value`, `unit` (Strings), `color` (Color).
- **Used in:** `SeniorHomeScreen`, `EmergencyScreen`.

#### `lib/widgets/pill_progress_bar.dart`
- **Purpose:** Thin horizontal progress bar showing pill count ratio.
- **Props:** `value` (double, 0.0–1.0), `color` (Color).
- **UI:** 4px height, gray background, colored `FractionallySizedBox` fill, clamped to [0, 1].
- **Used in:** `MedicationCard`, `SeniorHomeScreen`.

#### `lib/widgets/senior_nav_bar.dart`
- **Purpose:** Bottom navigation bar for senior-role screens.
- **4 tabs:** Home (`/senior/home`), Meds (`/senior/medications`), Family (placeholder no-op), Settings (placeholder no-op).
- **Props:** `currentIndex` (int).

---

## test/

#### `test/widget_test.dart`
- **Purpose:** Basic smoke test verifying app launch.
- **Test:** Pumps `SeniorCareApp`, asserts `find.text('SeniorCare AI')` exists.
- **Import issue:** Imports from `package:seniorcare_ui/main.dart` but `SeniorCareApp` is defined in `app.dart` — relies on Dart's transitive visibility from the import, which may not resolve correctly.

---

## web/

#### `web/index.html`
- Standard Flutter web bootstrap file. Sets `$FLUTTER_BASE_HREF` placeholder, loads `flutter_bootstrap.js`.
- Title: "seniorcare_ui".

#### `web/manifest.json`
- PWA manifest for the web app.

#### `web/icons/`
- App icons for web/PWA.

---

## android/

- Standard Flutter Android project structure with Kotlin Gradle DSL (`build.gradle.kts`).
- `settings.gradle.kts`, `gradle.properties`, `app/build.gradle.kts`, Gradle wrapper.

---

## UI Bugs & Errors

### Critical — Core Functionality Broken

| # | File | Element | Issue |
|---|---|---|---|
| 1 | `screens/senior/medication_tracker_screen.dart` | **"Mark as Taken" button** | `onPressed: () {}` — no-op. **Core medication tracking feature is completely non-functional.** Senior cannot mark doses as taken. |
| 2 | `screens/senior/emergency_screen.dart` | **"Need Help Now" button** | `onPressed: () {}` — no-op. **Emergency help request does nothing.** This is a safety-critical feature. |
| 3 | `screens/family/family_alerts_screen.dart` | **Alert CTA buttons** | `AlertRow` is used without passing `onCtaTap` callback. CTA buttons like "Call 911 now" on critical alerts will have `onTap: null` and are **not tappable**. |
| 4 | `screens/family/family_dashboard_screen.dart` | **"Video Call" button** | `onPressed: () {}` — no-op. Family member cannot initiate video calls. |

### Medium — Navigation / Placeholder Gaps

| # | File | Element | Issue |
|---|---|---|---|
| 5 | `widgets/senior_nav_bar.dart` | **"Family" tab (index 2)** | `break;` — no-op. Tapping "Family" in the bottom nav does nothing. |
| 6 | `widgets/senior_nav_bar.dart` | **"Settings" tab (index 3)** | `break;` — no-op. Tapping "Settings" does nothing. |
| 7 | `widgets/family_nav_bar.dart` | **"Settings" tab (index 3)** | `break;` — no-op. Tapping "Settings" does nothing. |
| 8 | `screens/web/web_dashboard_screen.dart` | **Sidebar items** | Vitals, Medications, Sleep, Activity, Alerts, and Settings sidebar items only update `_selectedIndex` (highlight) but don't navigate or change the main content. Only "Dosage Log" and "Call History" have working navigation. |

### Low — Placeholder / UX

| # | File | Element | Issue |
|---|---|---|---|
| 9 | `screens/auth/role_select_screen.dart` | **"Already have an account? Sign in"** | `onPressed: () {}` — no-op. Dead link. |
| 10 | `screens/auth/parent_login_screen.dart` | **"Use Face ID instead"** | `onPressed: () {}` — no-op. Feature not implemented. |
| 11 | `screens/auth/family_login_screen.dart` | **"New here? Set up monitoring"** | `onPressed: () {}` — no-op. Dead link. |
| 12 | `widgets/family_nav_bar.dart` | **"Dosage" tab label** | Label says "Dosage" but navigates to `/family/reports` (`WeeklyReportScreen`) which shows general weekly health metrics — not a dedicated dosage view. Misleading label. |
| 13 | `test/widget_test.dart` | **Import** | Imports `SeniorCareApp` from `package:seniorcare_ui/main.dart`, but the class is defined in `app.dart`. May cause compile error if Dart doesn't resolve the transitive import. |

### Summary

- **5 buttons are completely non-functional** (no-op handlers) — including 2 safety/health critical ones.
- **4 nav bar tabs** are placeholders that do nothing when tapped.
- **6 of 9 web sidebar items** don't show different content.
- **Alert CTA buttons** (e.g. "Call 911 now") are rendered but not wired to any action.
- **1 label mismatch** in the family nav bar ("Dosage" → weekly reports).
