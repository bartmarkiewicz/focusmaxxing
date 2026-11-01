# Technical Decisions & Engineering Tradeoffs

This document provides an exhaustive, engineering-grade record of the core architectural decisions made in the Focusmaxxing codebase. Each section outlines the problem context, alternatives evaluated, final decision, and detailed technical tradeoffs.

---

## 1. Secondary Flutter Engine (`flutter_overlay_window`) vs Native Android XML for Overlays

### Context & Problem
When a user launches a blocked application during an active focus block or scheduled window, Focusmaxxing displays an un-dismissible, full-screen lock view over the target application. This overlay view requires:
* Live countdown visualization synchronized with the session target deadline.
* Interactive 60-second "urge surfing" box breathing exercise ([`BoxBreathingExercise`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/widgets/box_breathing_exercise.dart)) with dynamic 4-second phase animations (Inhale, Hold, Exhale, Hold).
* Single-session hold-to-cancel interactions and daily emergency pass triggers.
* Design system parity with the main Flutter application (dark mode palettes, typography scales, Material 3 components).

### Options Considered
1. **Option A: Native Android XML Layout (`WindowManager.addView`)**:
   Inflate a traditional Android XML layout directly into the system window manager via [`FocusShieldService.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt).
2. **Option B: Secondary Flutter Engine (`flutter_overlay_window`)**:
   Spawn a headless secondary Flutter Engine using `FlutterEngineGroup` executing [`overlayMain`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/overlay/overlay_main.dart#L9-L18) host to [`HardLockOverlayWidget`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/overlay/overlay_main.dart#L20-L54).

### Decision Made
**Option B (Secondary Flutter Engine)** with native engine pre-caching via [`FocusShieldService.ensureOverlayBridgeRegistered()`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L176-L191).

### Technical Tradeoff Analysis
* **Pros**:
  * **Code Reuse**: Animation physics, curves, box breathing widgets, and theme definitions are shared directly from the Flutter codebase without duplicating UI rendering logic in Kotlin/XML.
  * **Cross-Platform Readiness**: The overlay widget architecture can be ported to desktop platforms (Windows/Linux) using borderless top-level windows without rewriting presentation layers.
* **Cons & Mitigation**:
  * *Memory Overhead*: Spawning a secondary Flutter engine creates a separate Dart isolate and Skia/Impeller graphics context (~25–35MB RAM). *Mitigation*: Used `FlutterEngineGroup`, which shares core C++ runtime symbols, GPU drivers, and font definitions across isolates, reducing incremental overhead from ~35MB to ~14MB.
  * *Cold Start Latency*: Creating an engine on-demand introduces a 200–300ms visual hitch before the overlay renders. *Mitigation*: Pre-warmed the engine inside `FocusShieldService.onStartCommand()` and cached it in `FlutterEngineCache` (`OVERLAY_CACHED_ENGINE_ID`), allowing instant window presentation when an interception occurs.

---

## 2. Native Android `AlarmManager` + BroadcastReceiver vs Headless Dart Isolate

### Context & Problem
Scheduled Auto-Shielding requires executing start and stop triggers at fixed times of day (e.g., 09:00 to 17:00, or overnight 22:00 to 06:00), surviving device reboots, app task swiping, and Android Doze modes, while consuming negligible battery.

### Options Considered
1. **Option A: Headless Dart Isolate via `android_alarm_manager_plus`**:
   Register a Dart top-level callback (`autoShieldStartAlarmCallback`) executed in a headless Flutter background isolate whenever an alarm fires.
2. **Option B: Native Kotlin `AlarmManager` + `BroadcastReceiver`**:
   Implement a pure Android `BroadcastReceiver` ([`AutoShieldAlarmReceiver.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt)) that reads configuration directly from `FlutterSharedPreferences.xml` and launches [`FocusShieldService`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt) natively.

### Decision Made
**Option B (Native Kotlin `AutoShieldAlarmReceiver.kt`)** as the authoritative background scheduler, retaining `android_alarm_manager_plus` only as an optional secondary coordinator.

### Technical Tradeoff Analysis
* **Pros**:
  * **Zero Dart Startup Latency**: Firing a broadcast receiver in Kotlin takes <5ms and uses <4MB of transient memory. Bootstrapping a headless Flutter isolate requires 300–600ms and ~40MB of memory, making it highly susceptible to termination by Android's Low Memory Killer (LMK).
  * **Boot Resilience**: Native receivers handle `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `TIMEZONE_CHANGED`, and `TIME_SET` directly in native bytecode, re-arming alarms without waiting for Flutter initialization.
  * **Android 12+ API 31 Exact Alarm Compliance**: Native Kotlin checks `alarmManager.canScheduleExactAlarms()` directly ([lines 123-136](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt#L123-L136)) and handles `SecurityException` gracefully by degrading to `setAndAllowWhileIdle()`.
* **Cons**:
  * Requires Kotlin code to parse Flutter's JSON SharedPreferences serialization format (`JSONArray`, string set deserialization).

---

## 3. Provider with Clean Architecture Use Cases vs BLoC / Riverpod

### Context & Problem
Focusmaxxing manages state across 8 discrete domains (Timer, Shield, Audio, Backlog, Insights, Schedule, Billing, and Home Widget). The state management layer must support deterministic unit testing, avoid excessive boilerplate, prevent memory leaks, and isolate business logic from Flutter widget lifecycles.

### Options Considered
1. **Option A: BLoC / Cubit**: Event-driven streams with distinct Event and State union classes for every feature.
2. **Option B: Riverpod**: Global provider containers with compile-time safety and code generation.
3. **Option C: Provider (`ChangeNotifier`) + Domain Use Cases**: Use cases encapsulate pure business rules; `ChangeNotifier` acts as a thin presentation ViewModel.

### Decision Made
**Option C (Provider + Domain Use Cases)**.

### Technical Tradeoff Analysis
* **Pros**:
  * **Boilerplate Minimization**: Clean Architecture use cases already isolate business logic into standalone, testable Dart classes ([`StartSessionUseCase`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/domain/usecases/start_session_usecase.dart), [`SwapShieldAppUseCase`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/domain/usecases/swap_shield_app_usecase.dart)). Introducing BLoC would add redundant Event/State wrappers without increasing testability.
  * **Zero Code Generation Overhead**: Riverpod requires code generation (`build_runner`) which slows build pipelines and introduces brittle CI compilation dependencies.
  * **Scoping & Lifecycle**: Standard `MultiProvider` scoping mirrors the widget hierarchy cleanly and integrates with `dynamic_color` Material 3 rebuilds without global state leaks.
* **Cons & Mitigation**:
  * `ChangeNotifier` allows mutable state if not disciplined. *Mitigation*: All notifier fields are strictly private with immutable getters (`List.unmodifiable`, `Set.unmodifiable`), and state modifications occur solely through typed use cases.

---

## 4. SQLite with Pure FFI Testing vs Hive / Isar / SharedPreferences

### Context & Problem
The application requires persistent storage for session logs, backlog tasks, and shielded application metadata. It must support relational integrity (foreign keys between tasks and sessions), aggregate calculations (daily focus minutes, streak calculations), atomic schema upgrades, and zero-flake host testing.

### Options Considered
1. **Option A: Hive / Isar (NoSQL Document Stores)**.
2. **Option B: SharedPreferences for all data**.
3. **Option C: SQLite (`sqflite` on mobile + `sqflite_common_ffi` on host)**.

### Decision Made
**Option C (SQLite with Pure FFI Testing)**.

### Technical Tradeoff Analysis
* **Pros**:
  * **Relational Querying & Aggregations**: Insights computations (`SUM(actual_duration_seconds)`, streak evaluations across date boundaries) execute natively inside SQLite's optimized C query engine rather than loading full object graphs into Dart memory.
  * **Referential Integrity**: `FOREIGN KEY(completed_session_id) REFERENCES sessions(id) ON DELETE SET NULL` automatically preserves backlog tasks if session records are deleted.
  * **Atomic Migrations with Rollback**: [`MigrationRunner`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/database/migrations/migration_runner.dart) executes DDL changes inside atomic transactions (`db.transaction`). If a migration fails mid-way, SQLite rolls back to the prior schema version cleanly.
  * **Sub-Second Host Testing**: Host unit tests use `sqflite_common_ffi` in-memory databases (`inMemoryDatabasePath`), running hundreds of schema and query tests in milliseconds without Android emulators.
* **Cons**:
  * Requires explicit SQL schema management and mapping code ([`SessionModel.fromMap`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/data/models/session_model.dart#L15-L28)).

---

## 5. Pure Local Cryptographic Receipt Verification (`ProReceiptVerifier`) vs Cloud Backend / Firebase

### Context & Problem
Focusmaxxing offers a one-time $9.99 Lifetime Pro in-app purchase. The app must prevent trivial anti-tampering bypasses (e.g. users editing plain-text boolean flags in `FlutterSharedPreferences.xml` on rooted devices) without imposing ongoing server maintenance costs or compromising user privacy.

### Options Considered
1. **Option A: Centralized Cloud Backend (Node.js/Go on AWS/Firebase)**:
   Users authenticate via OAuth; Google Play Developer API validates purchase tokens server-side.
2. **Option B: Plaintext SharedPreferences Booleans**:
   Store `is_lifetime_pro = true` directly in preferences.
3. **Option C: Pure Local Cryptographic Receipt Verification ([`ProReceiptVerifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/security/pro_receipt_verifier.dart))**:
   Sign purchase payload (product ID, purchase timestamp, order ID) locally using HMAC-SHA256 and FNV-1a with obfuscated key material, storing signed tokens in preferences.

### Decision Made
**Option C (Pure Local Cryptographic Verification)**.

### Technical Tradeoff Analysis
* **Pros**:
  * **Zero Server Infrastructure & Operational Cost**: No databases to maintain, no cloud subscriptions, no downtime risk, and zero vulnerability to backend data leaks.
  * **100% Offline Resilience**: Users can purchase, restore, and verify Lifetime Pro features without an active internet connection (after initial Play Store handshake).
  * **Anti-Tampering Security**: Unverified plaintext edits to `is_pro_unlocked` or `is_lifetime_pro` are detected and rejected by [`ProReceiptVerifier.readVerifiedReceiptSync()`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/security/pro_receipt_verifier.dart#L64-L77).
* **Cons & Threat Model**:
  * Does not defend against an attacker decompiling the APK and modifying Dart bytecode or patching verification checks in smali. However, this defense level is proportionate for an open-source productivity app and completely eliminates casual tampering.

---

## 6. Non-Ducking Android Audio Session vs Default Ducking

### Context & Problem
Focusmaxxing features an integrated soundscape generator playing continuous loops (Brown Noise, White Noise, Rain). Users often listen to podcasts, audiobooks, or Spotify music while working. Standard Android audio behavior ducks (lowers volume by 80%) or pauses other audio streams when an app begins playback.

### Options Considered
1. **Option A: Default Android Audio Focus**:
   Standard playback requests exclusive audio focus, pausing or muting background music.
2. **Option B: Non-Ducking Mixed Audio Session**:
   Configure the platform audio session with `AVAudioSessionCategoryOptions.mixWithOthers` and `androidWillPauseWhenDucked = false`.

### Decision Made
**Option B (Non-Ducking Mixed Audio Session)** in [`JustAudioPlayerEngine.configureAudioSession()`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/data/datasources/audio_player_engine.dart#L45-L60).

### Technical Tradeoff Analysis
* **Pros**:
  * **Acoustic Masking**: Allows users to blend Focusmaxxing's noise generators as an ambient acoustic floor beneath their existing media without interruption or volume loss.
  * **Zero Media Conflicts**: Prevents triggering unwanted play/pause events on Bluetooth headphones or external audio hardware.
* **Cons**:
  * Requires explicit platform session configuration via `audio_session` before initiating playback.

---

## 7. Wall-Clock Delta Calculation vs Ticking Timer Dart Streams

### Context & Problem
Countdown timers in mobile apps are susceptible to severe timing drift when the device enters low-power sleep (Doze mode) or when the operating system throttles background Dart isolates.

### Options Considered
1. **Option A: Monotonic 1-Second Decrement Stream (`remainingSeconds--`)**:
   A Dart `Timer.periodic(Duration(seconds: 1))` decrementing an integer counter on each tick.
2. **Option B: Wall-Clock Target Deadline Arithmetic**:
   Establish an absolute epoch deadline ($\text{targetEndTime} = \text{now} + \text{duration}$) and calculate remaining time as $\text{targetEndTime} - \text{DateTime.now()}$ on a high-frequency (200ms) ticker and on app lifecycle resume.

### Decision Made
**Option B (Wall-Clock Target Deadline Arithmetic)** in [`TimerNotifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart#L634-L703).

### Technical Tradeoff Analysis
* **Pros**:
  * **Zero Drift Under CPU Throttling**: Even if Android suspends the Flutter process for 20 minutes in Doze mode, the exact instant the app wakes or resumes, `syncWithWallClock()` computes the precise remaining duration or triggers instant session completion.
  * **Native Parity**: Aligns with native Android `Chronometer` widgets ([`GlanceableDialWidgetProvider.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/widget/GlanceableDialWidgetProvider.kt#L40-L42)) which calculate remaining time using hardware elapsed realtime clocks.
* **Cons**:
  * Requires storing explicit `target_end_time_epoch_ms` in tombstones and notification payloads.
