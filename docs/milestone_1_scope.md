# Focusmaxxing - Milestone 1 Scoping Document

**Document:** Milestone 1 Technical Implementation Scope  
**Architecture Pattern:** Clean Architecture (Domain, Data, Presentation, Core)  
**Target Milestone:** Milestone 1 - Core Loop, Clean Architecture & ADHD Task Anchor (MVP)  
**Parent Specification:** [docs/requirements.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/requirements.md) & [docs/technical_scoping.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/technical_scoping.md)

---

## 1. Milestone 1 Objectives

Deliver a fully functional, production-grade MVP implementing the core focus loop with zero survey friction, strict ADHD task anchoring, dynamic Android Material You theming, and an offline SQLite persistence engine structured strictly under **Clean Architecture**.

### Deliverable Capabilities
1. **Wall-Clock Synced Timer:** 25-minute Pomodoro timer resilient against backgrounding and process killing.
2. **ADHD 1-Sentence Task Initiation:** Modal input prompting *"What ONE thing are you locking in on?"* with recent-goal chips.
3. **Anti-Impulse 5-Second Hold-to-Cancel:** Gesture button requiring 5 full seconds of continuous hold to terminate a session.
4. **Binary Check-In:** 1-tap post-session dialog (`[ Locked In 🚀 ]` vs `[ Derailed 💀 ]`).
5. **Persistent Android Notification:** Ongoing notification displaying the live countdown and pinned 1-sentence goal.
6. **Unobtrusive Task Backlog:** Swipe-up/modal scratchpad to queue tasks, tap to lock in, and auto-complete upon session finish.
7. **Insights & Streaks:** Daily focus minutes total, active day streak, and rolling 7-day chronological session log.
8. **Testing Pyramid:** Unit tests (Domain/Data/Notifiers), Widget tests, and E2E integration test.

---

## 2. Clean Architecture Layer Breakdown

```
lib/
├── core/
│   ├── errors/
│   │   ├── exceptions.dart           # DatabaseException, CacheException
│   │   └── failures.dart             # DatabaseFailure, CacheFailure (Equatable)
│   ├── database/
│   │   ├── database_helper.dart      # SQLite OpenHelper (sqflite)
│   │   └── tables/                   # Schema DDL definitions
│   ├── notifications/
│   │   └── notification_service.dart # flutter_local_notifications wrapper
│   ├── theme/
│   │   ├── app_theme.dart            # Dynamic Material You & OLED Fallback
│   │   └── app_colors.dart           # Semantic color tokens
│   └── utils/
│       ├── time_formatter.dart       # MM:SS & duration helpers
│       └── date_utils.dart           # Day start/end timestamp helpers
│
├── features/
│   ├── timer/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── session_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── i_session_repository.dart
│   │   │   └── usecases/
│   │   │       ├── start_session_usecase.dart
│   │   │       ├── complete_session_usecase.dart
│   │   │       ├── cancel_session_usecase.dart
│   │   │       └── get_today_sessions_usecase.dart
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── session_model.dart
│   │   │   ├── datasources/
│   │   │   │   └── session_local_data_source.dart
│   │   │   └── repositories/
│   │   │       └── session_repository_impl.dart
│   │   └── presentation/
│   │       ├── notifiers/
│   │       │   └── timer_notifier.dart
│   │       ├── pages/
│   │       │   └── timer_page.dart
│   │       └── widgets/
│   │           ├── timer_dial_widget.dart
│   │           ├── goal_input_dialog.dart
│   │           ├── hold_to_cancel_button.dart
│   │           └── session_checkin_dialog.dart
│   │
│   ├── backlog/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── backlog_task_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── i_backlog_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_pending_tasks_usecase.dart
│   │   │       ├── add_backlog_task_usecase.dart
│   │   │       ├── delete_backlog_task_usecase.dart
│   │   │       └── mark_task_completed_usecase.dart
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── backlog_task_model.dart
│   │   │   ├── datasources/
│   │   │   │   └── backlog_local_data_source.dart
│   │   │   └── repositories/
│   │   │       └── backlog_repository_impl.dart
│   │   └── presentation/
│   │       ├── notifiers/
│   │       │   └── backlog_notifier.dart
│   │       └── widgets/
│   │           ├── backlog_modal_sheet.dart
│   │           └── backlog_task_item.dart
│   │
│   └── insights/
│       ├── domain/
│       │   ├── entities/
│       │   │   └── daily_summary_entity.dart
│       │   ├── repositories/
│       │   │   └── i_insights_repository.dart
│       │   └── usecases/
│       │       └── get_daily_summary_usecase.dart
│       ├── data/
│       │   └── repositories/
│       │       └── insights_repository_impl.dart
│       └── presentation/
│           ├── notifiers/
│           │   └── insights_notifier.dart
│           ├── pages/
│           │   └── insights_page.dart
│           └── widgets/
│               ├── streak_card.dart
│               └── session_history_list.dart
│
├── main_scaffold.dart                # 3-Tab BottomNavigationBar + Backlog Header Icon
└── main.dart                         # MultiProvider root & dynamic theme initialization
```

---

## 3. Detailed Component Specifications

### 3.1 Domain Layer (Pure Dart, Zero External Framework Dependencies)
* **Entities:** Must extend `Equatable` to ensure value comparison purity.
  * `SessionEntity`:
    * Fields: `id`, `taskGoal`, `sessionType` (`FOCUS`, `SHORT_BREAK`), `targetDurationSeconds`, `actualDurationSeconds`, `startTimeEpochMs`, `endTimeEpochMs`, `status` (`LOCKED_IN`, `DERAILED`, `CANCELLED`).
  * `BacklogTaskEntity`:
    * Fields: `id`, `title`, `isCompleted`, `completedSessionId`, `createdAt`, `completedAt`.
  * `DailySummaryEntity`:
    * Fields: `date`, `totalFocusMinutes`, `completedSessionsCount`, `currentStreakDays`.
* **Repository Interfaces (`Either<Failure, T>` using `dartz`):**
  * `ISessionRepository`:
    * `Future<Either<Failure, int>> createSession(SessionEntity session)`
    * `Future<Either<Failure, void>> updateSessionStatus(int sessionId, String status, int actualDurationSeconds)`
    * `Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(int startMs, int endMs)`
  * `IBacklogRepository`:
    * `Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks()`
    * `Future<Either<Failure, int>> addTask(String title)`
    * `Future<Either<Failure, void>> deleteTask(int id)`
    * `Future<Either<Failure, void>> markCompleted(int id, int sessionId)`

---

### 3.2 Data Layer (Persistence & SQLite Mapping)
* **Database Helper (`sqflite`):**
  * Database file: `focusmaxxing.db`, version: `1`.
  * Creates `sessions` and `backlog_tasks` tables.
* **Models (Data Transfer Objects):**
  * `SessionModel`: Extends `SessionEntity`. Implements `fromMap(Map<String, dynamic> map)`, `toMap()`, and `toEntity()`.
  * `BacklogTaskModel`: Extends `BacklogTaskEntity`. Implements `fromMap(Map<String, dynamic> map)`, `toMap()`, and `toEntity()`.
* **Data Sources:**
  * `SessionLocalDataSource`: Raw SQLite CRUD operations wrapped with try/catch throwing `DatabaseException`.
  * `BacklogLocalDataSource`: Raw SQLite queries throwing `DatabaseException`.
* **Repository Implementations:**
  * Maps `DatabaseException` to `Left(DatabaseFailure(e.message))`.
  * Converts data models into domain entities and returns `Right(entity)`.

---

### 3.3 Presentation Layer (UI & State Management)

#### A. State Notifiers (`ChangeNotifier`)
1. **`TimerNotifier`:**
   * **States:** `TimerStatus.idle`, `TimerStatus.running`, `TimerStatus.paused`, `TimerStatus.completed`, `TimerStatus.breakRunning`, `TimerStatus.breakCompleted`.
   * **Wall-Clock Synchronization:**
     * `DateTime? _targetEndTime`
     * Computes remaining seconds: `_targetEndTime.difference(DateTime.now()).inSeconds`.
     * Ticking loop: Uses a 200ms `Timer.periodic` while active to ensure smooth UI updates and detect the exact second boundary.
   * **Goal Anchor:** Holds current `String? currentTaskGoal` and caches the last 3 goals in `SharedPreferences` for quick chips.
   * **Hold-to-Cancel Logic:**
     * Manages `double cancelHoldProgress` (0.0 to 1.0) over a 5000ms duration.
     * If released before 5000ms: resets progress to 0.0 with zero state side-effects.
     * If held for full 5000ms: triggers cancellation usecase, marks session `DERAILED`, dismisses notification, and returns to `idle`.
   * **Notifications:** Calls `NotificationService.showOngoingTimer(...)` on start, updates on pause/resume, and cancels on complete.
2. **`BacklogNotifier`:**
   * Loads pending tasks on initialization.
   * Exposes `addTask(String title)`, `deleteTask(int id)`, and `selectTaskAsGoal(BacklogTaskEntity task)`.
3. **`InsightsNotifier`:**
   * Computes today's focus minutes and active streak.
   * Manages `isStreakEnabled` (master toggle to hide/show streaks).
   * Manages `includeWeekendsInStreak` (bool, default: `false` so weekends are exempt by default; user can toggle to `true` to require 7-day streaks).
   * Manages `isDailyReminderEnabled` (bool, default: `false` to prevent notification spam) and schedules daily recurring reminder via `flutter_local_notifications` when toggled `true`.
   * Loads 7-day chronological session list.

#### B. Widgets & Screens
* **`TimerPage`:**
  * Central circular countdown dial (`TimerDialWidget`) showing remaining `MM:SS` and active task goal anchor.
  * Start button (idle) -> Pause/Resume buttons + `HoldToCancelButton` (running).
* **`GoalInputDialog`:**
  * Clean Material 3 modal sheet with auto-focused text field (max 60 chars).
  * Horizontal chip list displaying recent 3 goals for 1-tap reuse.
  * Primary button: `[ Lock In ]`.
* **`HoldToCancelButton`:**
  * Custom animated button wrapped in `GestureDetector(onLongPressStart, onLongPressEnd)`.
  * Renders a circular fill or progress bar tracking the 5-second hold.
* **`SessionCheckInDialog`:**
  * Non-dismissible barrier dialog:
    * `[ Locked In 🚀 ]` (status: `LOCKED_IN`)
    * `[ Derailed 💀 ]` (status: `DERAILED`)
* **`BacklogModalSheet`:**
  * Unobtrusive bottom sheet accessible via Timer header icon.
  * Top input field with `Add` icon button.
  * List of tasks with `Dismissible` (swipe-to-delete) and `ListTile` tap callback to assign task as current goal.

---

### 3.4 Core Layer
* **Dynamic Material You Theme (`dynamic_color`):**
  * `DynamicColorBuilder` wrapping `MaterialApp`.
  * Fallback dark theme: `#0A0B0E` (Surface), `#00E676` (Primary Emerald Accent for Focus), `#FF5252` (Warning/Cancel Accent).
* **Persistent Notification Service (`flutter_local_notifications`):**
  * Android Channel: `focusmaxxing_timer_channel` (Importance: High, Priority: High).
  * Notification configuration: `ongoing: true`, `onlyAlertOnce: true`, `showWhen: true`, `usesChronometer: false`.

---

## 4. Testing Plan for Milestone 1

### 4.1 Unit Tests (`test/features/...`)
* **TimerNotifier Unit Tests:**
  * Verify initial state is `TimerStatus.idle`.
  * Verify starting session sets `_targetEndTime` and transitions to `running`.
  * Verify wall-clock calculation recovers correct remaining time after simulated delay.
  * Verify 5-second hold threshold triggers session cancellation and marks status `DERAILED`.
* **SessionRepositoryImpl Unit Tests:**
  * In-memory SQLite testing using `sqflite_common_ffi`.
  * Verify inserting session returns valid auto-increment ID.
  * Verify query filtering by date range correctly aggregates today's focus time.
* **BacklogNotifier Unit Tests:**
  * Verify adding task updates pending list.
  * Verify deleting task removes item from SQLite and notifyListeners is dispatched.

### 4.2 Widget Tests (`test/presentation/...`)
* **`TimerDialWidgetTest`:**
  * Pump widget with 25:00 remaining -> verify text `25:00` is displayed.
  * Pump widget with goal string -> verify goal text is rendered.
* **`GoalInputDialogTest`:**
  * Enter text in text field -> verify input limit 60 characters.
  * Tap recent goal chip -> verify text field auto-populates.
* **`HoldToCancelButtonTest`:**
  * Long press simulation: verify progress increments over time.
  * Release at 2 seconds -> verify cancellation callback is NOT fired.
  * Hold for 5 seconds -> verify cancellation callback IS fired.

### 4.3 Integration Test (`integration_test/focus_flow_test.dart`)
* Full end-to-end device execution:
  1. Boot app into `TimerPage`.
  2. Tap Start -> Enter goal *"Finish clean architecture"* -> Tap Lock In.
  3. Verify countdown begins and ongoing notification is dispatched.
  4. Complete session -> verify Check-In dialog appears.
  5. Tap `[ Locked In 🚀 ]` -> navigate to Insights tab -> verify session is logged with correct minutes.

---

## 5. Required Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.2
  sqflite: ^2.3.3+1
  path: ^1.9.0
  shared_preferences: ^2.2.3
  equatable: ^2.0.5
  dartz: ^0.10.1
  dynamic_color: ^1.7.0
  flutter_local_notifications: ^17.2.1+2

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  sqflite_common_ffi: ^2.3.3
```

---

## 6. Implementation Step-by-Step Checklist

- [ ] **Step 1: Dependencies & Android Setup**
  - Update `pubspec.yaml` with required packages and run `flutter pub get`.
  - Configure `android/app/build.gradle` (minSdkVersion 26, desugaring if required).
- [ ] **Step 2: Core Infrastructure**
  - Implement `core/errors/failures.dart` & `exceptions.dart`.
  - Implement `core/database/database_helper.dart` with SQLite schema.
  - Implement `core/notifications/notification_service.dart`.
  - Implement `core/theme/app_theme.dart` with `dynamic_color`.
- [ ] **Step 3: Backlog Feature (Clean Architecture)**
  - Implement `BacklogTaskEntity`, `IBacklogRepository`, and use cases.
  - Implement `BacklogTaskModel`, `BacklogLocalDataSource`, and `BacklogRepositoryImpl`.
  - Implement `BacklogNotifier` and `BacklogModalSheet`.
- [ ] **Step 4: Timer Feature (Clean Architecture)**
  - Implement `SessionEntity`, `ISessionRepository`, and use cases.
  - Implement `SessionModel`, `SessionLocalDataSource`, and `SessionRepositoryImpl`.
  - Implement `TimerNotifier` (wall-clock sync, 5s hold-to-cancel, recent goals).
  - Implement `TimerDialWidget`, `GoalInputDialog`, `HoldToCancelButton`, and `SessionCheckInDialog`.
  - Implement `TimerPage`.
- [ ] **Step 5: Insights Feature & Navigation Scaffold**
  - Implement `DailySummaryEntity` and aggregation query logic.
  - Implement `InsightsNotifier` and `InsightsPage`.
  - Implement `MainScaffold` with 3-tab navigation and header Backlog modal trigger.
- [ ] **Step 6: Automated Test Suite**
  - Write unit tests for repositories, use cases, and notifiers.
  - Write widget tests for dial, dialog, and cancel button.
  - Write `integration_test/focus_flow_test.dart`.
  - Execute `flutter test` and verify 100% pass rate.
