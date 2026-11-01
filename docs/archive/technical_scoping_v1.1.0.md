# Focusmaxxing - Technical Scoping Document

> [!WARNING]
> **DEPRECATED & ARCHIVED DOCUMENTATION (v1.1.0)**  
> This specification represents the early technical architecture baseline and is **superseded** by the comprehensive, modular architecture specifications in [`docs/architecture/`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/architecture).  
> For current architectural documentation, see [`docs/architecture/system_overview.md`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/architecture/system_overview.md).

**Document Version:** 1.1.0 (Archived)  
**Status:** Superseded by [`docs/architecture/`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/architecture)  
**Target Platform:** Android (API 26+ / Android 8.0 through Android 14+), iOS (Phase 2)  
**Framework:** Flutter (Dart 3.x)  
**Architecture:** Classic Flutter Clean Architecture (`core/`, `features/{feature}/{data, domain, presentation}`)  
**State Management:** `provider` + `ChangeNotifier`  
**Local Persistence:** SQLite via `sqflite`  
**Theme Standard:** Android Dynamic Material You via `dynamic_color`  
**Native Bridge:** Android Kotlin `MethodChannel` & Background Foreground Service  
**Testing Strategy:** Comprehensive Testing Suite (Unit, Widget, and E2E Integration Tests)

---

## 1. System Architecture & Directory Structure

### 1.1 High-Level Architecture Diagram

```
+-----------------------------------------------------------------------------------+
|                           Presentation Layer (Clean Arch)                         |
|   [TimerPage / Widgets]   [ShieldPage]    [BacklogModalSheet]   [InsightsPage]    |
|   TimerChangeNotifier     ShieldChangeNotifier  TaskChangeNotifier                |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                             Domain Layer (Clean Arch)                             |
|   Entities: SessionEntity, BacklogTaskEntity, ShieldedAppEntity                   |
|   Use Cases: StartFocusSession, CheckInSession, ToggleAppShield, AddBacklogTask   |
|   Repository Interfaces: ISessionRepository, IBacklogRepository, IShieldRepository|
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                              Data Layer (Clean Arch)                              |
|   Repository Implementations: SessionRepositoryImpl, BacklogRepositoryImpl        |
|   Data Sources: SQLiteDatabaseHelper, LocalPreferencesSource, NativeShieldSource |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                                 Core Layer                                        |
|   Database (sqflite), Dynamic Material You Theme, Constants, Utils                |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                        Native Android Layer (Kotlin)                              |
|   FocusShieldService (Foreground Service)                                        |
|   - UsageStatsManager Poller (Checks active package every 500ms)                  |
|   - SystemAlertWindow OverlayManager (Launches Hard Lock view)                    |
|   - flutter_local_notifications (Live countdown & persistent goal anchor)         |
+-----------------------------------------------------------------------------------+
```

### 1.2 Directory Layout (`lib/`)

```
lib/
├── core/
│   ├── database/             # SQLite open helper, schema DDL, and migrations
│   ├── theme/                # Dynamic Material You color scheme & dark theme
│   ├── notifications/        # flutter_local_notifications service
│   ├── audio/                # just_audio & audio_session engine
│   └── constants/            # Strings, keys, dimensions
├── features/
│   ├── timer/
│   │   ├── data/             # SessionModel, SessionLocalDataSource, SessionRepositoryImpl
│   │   ├── domain/           # SessionEntity, Timer UseCases, ISessionRepository
│   │   └── presentation/     # TimerPage, TimerDialWidget, GoalInputDialog, TimerNotifier
│   ├── shield/
│   │   ├── data/             # ShieldedAppModel, NativeBridgeSource, ShieldRepositoryImpl
│   │   ├── domain/           # ShieldedAppEntity, Shield UseCases, IShieldRepository
│   │   └── presentation/     # ShieldPage, PresetCards, InstalledAppList, ShieldNotifier
│   ├── backlog/
│   │   ├── data/             # BacklogTaskModel, BacklogDataSource, BacklogRepositoryImpl
│   │   ├── domain/           # BacklogTaskEntity, Task UseCases, IBacklogRepository
│   │   └── presentation/     # BacklogBottomSheet, TaskTile, BacklogNotifier
│   └── insights/
│       ├── data/             # Metrics aggregation source
│       ├── domain/           # Streak and summary entities
│       └── presentation/     # InsightsPage, StreakCard, SessionHistoryTile, InsightsNotifier
└── main.dart
```

---

## 2. Timer Timing Engine & Lifecycle Synchronization

* **Wall-Clock Target Sync:**
  * When a session starts: `targetEndTime = DateTime.now().add(duration)`.
  * Foreground: `Timer.periodic(const Duration(milliseconds: 200))` renders the remaining UI time via `targetEndTime.difference(DateTime.now())`.
  * Backgrounding / Screen Off: App pauses UI timer with zero background CPU drain.
  * Resuming: Immediate calculation against `DateTime.now()`. If `now >= targetEndTime`, transitions immediately to completion.
* **Persistent Lock-In Notification:**
  * Handled via `flutter_local_notifications` on Android.
  * Channel: `focusmaxxing_ongoing_timer` (`importance: High`, `ongoing: true`, `onlyAlertOnce: true`).
  * Displays: User's 1-sentence goal and countdown chronometer.
* **Anti-Impulse 5-Second Hold-to-Cancel (Two-Step Barrier):**
  * Tapping Pause while running reveals the Resume and Hold-to-Cancel buttons.
  * Cancel action requires a continuous 5-second `GestureDetector.onLongPress` hold with progressive haptic feedback.
  * Cancelling marks the session as `CANCELLED` in SQLite and releases native shields (differentiated from full sessions marked `DERAILED`).

---

## 3. Native Android Brainrot Shield Architecture

### 3.1 The Interception Loop
* **Detection Engine:**
  * Android `UsageStatsManager.queryEvents(startTime, endTime)` polled every 500ms in native Kotlin service `FocusShieldService`.
  * Zero use of prohibited Accessibility Services or invasive Device Admin.
* **Hard Lock Overlay (`SYSTEM_ALERT_WINDOW`):**
  * Launches full-screen overlay with `FLAG_NOT_TOUCH_MODAL | FLAG_LAYOUT_IN_SCREEN | FLAG_FULLSCREEN`.
  * Displays: Active 1-sentence goal, remaining focus countdown, and single action button `[ Return to Focusmaxxing ]`.
  * Zero emergency bypass or snooze options.
* **Restorative Break Guard:**
  * Shields remain active during the 5-minute break.
  * When break hits 00:00, shields **remain locked** until the user explicitly opens Focusmaxxing and taps `[ Lock In ]` for the next session.

---

## 4. Database Schema (SQLite via `sqflite`)

```sql
-- Focus & Rest Sessions
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_goal TEXT NOT NULL,
    session_type TEXT NOT NULL, -- 'FOCUS', 'SHORT_BREAK', 'LONG_BREAK'
    target_duration_seconds INTEGER NOT NULL,
    actual_duration_seconds INTEGER NOT NULL,
    start_time_epoch_ms INTEGER NOT NULL,
    end_time_epoch_ms INTEGER NOT NULL,
    status TEXT NOT NULL, -- 'LOCKED_IN', 'DERAILED', 'CANCELLED'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Backlog Tasks (Ultra-Minimal Scratchpad)
CREATE TABLE backlog_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0, -- 0 or 1
    completed_session_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY(completed_session_id) REFERENCES sessions(id)
);

-- Shielded Apps
CREATE TABLE shielded_apps (
    package_name TEXT PRIMARY KEY,
    app_name TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    is_preset INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 5. Visual Styling: Dynamic Android Material You

* Integrated via `dynamic_color` package (`DynamicColorBuilder`).
* Automatically extracts `ColorScheme` from the user's Android 12+ system wallpaper palette.
* Fallback dark theme: High-contrast deep slate (`#0A0B0E`) with vibrant emerald accents (`#00E676`) for focus mode, and stark warning crimson for the Hard Lock shield.

---

## 6. Native Billing Architecture (`in_app_purchase`)

* Single Non-Consumable Product ID: `focusmaxxing_lifetime_pro` ($9.99 flat).
* Zero subscriptions, zero recurring backend fees.
* Enforces the 2-app free cap on the client side; unlocking Pro removes the package cap.

---

## 7. Testing Strategy: Comprehensive Testing Suite

### 7.1 Unit Tests (`flutter_test` / `sqflite_common_ffi`)
* **State Notifiers / Controllers:**
  * `TimerNotifier`: Test wall-clock time sync, state transitions (`idle` -> `running` -> `breakRunning`), 5-second hold countdown cancellation, and completion checks.
  * `TaskNotifier`: Test adding backlog tasks, recent goal caching (top 3 chips), and auto-strikethrough logic.
  * `ShieldNotifier`: Test package whitelist/blacklist, free tier 2-app limit enforcement, and Pro status toggle.
* **Domain Layer Use Cases:**
  * Test execution logic for `StartFocusSession`, `CheckInSession`, `AddBacklogTask`, and `ToggleAppShield`.
* **Data Layer & SQLite Repositories:**
  * Use `sqflite_common_ffi` to test `SessionRepositoryImpl` and `BacklogRepositoryImpl` against an in-memory SQLite database.
  * Verify CRUD operations, date-range session queries, and streak calculation algorithms.

### 7.2 Widget Tests (`flutter_test`)
* **`TimerPage` & `TimerDialWidget`:**
  * Test countdown rendering, Start/Pause button visibility, and the 5-second press-and-hold cancellation progress ring.
* **`GoalInputDialog`:**
  * Verify 60-character limit, text field input, recent-goal chip selection, and submit trigger.
* **`BacklogBottomSheet`:**
  * Test adding a task via text field, swipe-to-delete dismissal, and tapping a task to populate the active timer goal.
* **`ShieldPage`:**
  * Verify rendering of Quick-Shield presets, installed app list rendering, and the 2-app cap upgrade dialog.

### 7.3 End-to-End (E2E) Integration Tests (`integration_test`)
* Automated real-device flows verifying cross-layer integration:
  1. **Full Focus Cycle:** Launch app -> tap Start -> enter 1-sentence goal -> run accelerated timer -> complete session -> tap `[ Locked In 🚀 ]` -> verify SQLite record and streak increment.
  2. **Hold-to-Cancel Verification:** Start session -> tap Cancel (assert no exit) -> hold Cancel for 5 seconds -> verify session marked `DERAILED` in SQLite.
  3. **Backlog Sheet Flow:** Open Backlog sheet -> add task -> tap task to lock in -> verify goal is populated on Timer screen.
  4. **Break Guard Transition:** Complete focus session -> verify break mode starts -> advance break to 00:00 -> verify apps remain locked until `[ Lock In ]` is tapped.

---

## 8. Android Manifest & Permissions Checklist

```xml
<!-- Required for app detection -->
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />

<!-- Required for hard lock overlay -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<!-- Required for timer persistence and countdown notification -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Billing -->
<uses-permission android:name="com.android.vending.BILLING" />

<!-- Audio -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

---

## 9. Technical Milestones & Implementation Tasks

### Milestone 1: Core Loop, Clean Architecture & ADHD Task Anchor (MVP)
* [ ] Setup Flutter project dependencies (`provider`, `sqflite`, `path`, `shared_preferences`, `dynamic_color`, `flutter_local_notifications`).
* [ ] Scaffold Classic Clean Architecture folders (`core/`, `features/{timer, shield, backlog, insights}/{data, domain, presentation}`).
* [ ] Create SQLite database helper (`sqflite`), schema tables, and migrations.
* [ ] Implement `TimerNotifier` with wall-clock delta sync and 5-second hold-to-cancel logic.
* [ ] Build 3-Tab UI navigation structure + modal Backlog bottom sheet.
* [ ] Implement 1-Sentence Goal dialog with recent-goal chips.
* [ ] Build binary check-in dialog (`[ Locked In 🚀 / Derailed 💀 ]`) and session logging.
* [ ] Write unit tests for notifiers and repositories, and widget tests for Timer & Backlog.

### Milestone 2: Brainrot Shield Native Engine
* [ ] Implement native Kotlin `FocusShieldService` with `UsageStatsManager` poller.
* [ ] Implement native `SYSTEM_ALERT_WINDOW` overlay view with zero-bypass logic.
* [ ] Setup Flutter `MethodChannel("com.focusmaxxing/shield")` communication.
* [ ] Build Shield Tab: Installed apps query, preset social cards, and active toggle storage.
* [ ] Implement Restorative Break Guard persistence (apps stay locked through break and break expiry).
* [ ] Write widget tests for Shield Page and integration tests for app blocking.

### Milestone 3: Audio, Lifetime Pro Billing & Launch Polish
* [ ] Integrate `just_audio` and `audio_session` with bundled audio loops and mixing.
* [ ] Integrate `in_app_purchase` for `focusmaxxing_lifetime_pro` (enforce 2-app free cap).
* [ ] Complete E2E integration test suite (`integration_test`).
* [ ] Release build verification and Google Play bundle packaging.
