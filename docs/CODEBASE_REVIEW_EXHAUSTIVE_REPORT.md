# Focusmaxxing: Definitive Exhaustive Codebase Review & Audit Report

**Audit Target**: `focusmaxxing` (`C:\Users\darkn\IdeaProjects\focusmaxxing`)  
**Scope**: Full Flutter/Dart code (`lib/`), Android Native implementation (`android/`), Architecture, State Machines, Lifecycle & Concurrency, Security, and Test Suite (`test/`).  
**Verification Baseline**: `dart analyze` (0 errors), `flutter test` (357 passed).  
**Constraint**: Diagnostic & Discovery Phase (Strictly **0 code modifications** applied).

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Pillar 1: Found Bugs and Issues (Categorized by Severity)](#pillar-1-found-bugs-and-issues)
   - [Critical Severity (11 Issues)](#critical-severity)
   - [High Severity (17 Issues)](#high-severity)
   - [Medium Severity (14 Issues)](#medium-severity)
   - [Low Severity (8 Issues)](#low-severity)
3. [Pillar 2: Bad Architectural Decisions](#pillar-2-bad-architectural-decisions)
4. [Pillar 3: Unmaintainable Code & Code Smells](#pillar-3-unmaintainable-code--code-smells)
5. [Pillar 4: Other Things That Need Work (Platform Fidelity, Testing, Scalability & Security)](#pillar-4-other-things-that-need-work)
6. [Prioritized Master Remediation Roadmap](#prioritized-master-remediation-roadmap)

---

## Executive Summary

A deep, multi-agent architectural and code quality audit was performed across the entire `focusmaxxing` repository. Focusmaxxing is designed as an "Anti-Brainrot App Blocker and ADHD Lock-In Engine", uniting a Flutter client, local SQLite persistence, Android foreground services, and an Android `SYSTEM_ALERT_WINDOW` Flutter overlay.

While the project demonstrates clean coding conventions in isolated layers (e.g., FFI SQLite bindings for deterministic unit testing and immutability in domain entities), the audit uncovered **50 distinct issues**, including **11 Critical bugs** that directly break the core product promises, cause safety hazards, drop focus blocks, wipe Pro user configurations, and trigger re-entrant infinite build loops.

### Key Takeaways
- **The background blocking engine is fundamentally disconnected**: Scheduled Auto-Shield fails 100% of the time when the app is closed due to a missing MethodChannel handler in headless isolates.
- **Life-Safety Risk**: Maximum Focus mode hardcodes only Google and Samsung dialers, blocking emergency calls and incoming phone calls on OnePlus, Xiaomi, Oppo, Motorola, and Sony devices.
- **State Management Anti-Patterns**: `ProxyProvider4` causes an infinite notification and rebuild loop on launch for Pro users, while `BillingNotifier` acts as a God Mediator directly mutating other presentation notifiers.
- **Flawed Core Mechanics**: Timer sessions default to `CANCELLED` in SQLite on crash, breaks drop the shield to `idle` leaving social media unblocked, and audio focus permanently ducks Spotify/podcasts by 75%.
- **Zero Real-World Integration Testing**: Critical path features (native bridges, background alarms, and overnight scheduling) have 0% test coverage and rely entirely on mock objects that bypass native platform reality.

---

## Pillar 1: Found Bugs and Issues

```
+---------------------------------------------------------------------------------------------------------+
| SEVERITY BREAKDOWN                                                                                      |
+-------------------+-------------------------------------------------------------------------------------+
| Critical (11)     | Core blocker failures, infinite loops, safety hazards, Pro wipes, data loss         |
| High (17)         | Audio ducking, BAL violations, exact alarm crashes, gesture loss, stealth bypasses  |
| Medium (14)       | Duplicate notifications, timezone shifts, chronometer drift, race conditions        |
| Low (8)           | Cycle mismatches, memory overhead, microsecond gaps, redundant IPC                  |
+-------------------+-------------------------------------------------------------------------------------+
```

### Critical Severity

#### 1.1 Headless FlutterEngine Lacks MethodChannel Handler — Scheduled Auto-Shield 100% Broken in Background
- **Files & Lines**: 
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:25–56`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L25-L56)
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:60–67`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L60-L67)
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt:52–57`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt#L52-L57)
- **Root Cause**:
  When a scheduled alarm fires while the app is killed or backgrounded, `android_alarm_manager_plus` spawns a headless background Flutter isolate executing `autoShieldStartAlarmCallback`. This callback constructs `MethodChannel('com.focusmaxxing/shield')` and invokes `'startShield'`. However, `MainActivity.configureFlutterEngine()` is **only** executed when the UI `Activity` is running. In a headless alarm execution, no handler is registered on the background engine's binary messenger.
- **Impact**:
  The call immediately throws `MissingPluginException: No implementation found for method startShield on channel com.focusmaxxing/shield`. Line 54 catches and swallows this with `catch (_) {}`. **Scheduled auto-shield NEVER activates or terminates in the background when the app is closed.**

#### 1.2 Native `AutoShieldAlarmReceiver` Is Completely Dead Code
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt:12–98`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt#L12-L98)
  - [`android/app/src/main/AndroidManifest.xml:83–89`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/AndroidManifest.xml#L83-L89)
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:140–163`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L140-L163)
- **Root Cause**:
  `AutoShieldAlarmReceiver` was implemented to read `FlutterSharedPreferences` directly and start `FocusShieldService` natively without Dart VM overhead. However, Dart's `ScheduleAlarmDataSourceImpl` was wired to `AndroidAlarmManagerPlus` with top-level Dart callbacks instead of scheduling Android `PendingIntent` alarms targeting `com.bmrkiewicz.focusmaxxing.START_AUTO_SHIELD`.
- **Impact**:
  The functional native receiver sits as dead code in the APK, while the broken Dart headless alarm pipeline is used instead.

#### 1.3 Re-entrant Infinite Rebuild Loop in `ChangeNotifierProxyProvider4`
- **Files & Lines**:
  - [`lib/main.dart:313–325`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/main.dart#L313-L325)
  - [`lib/features/billing/presentation/notifiers/billing_notifier.dart:75–94, 222–226`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/presentation/notifiers/billing_notifier.dart#L75-L94)
  - [`lib/features/shield/presentation/notifiers/shield_notifier.dart:340–345`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart#L340-L345)
  - [`lib/features/schedule/presentation/notifiers/schedule_notifier.dart:197–203`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/presentation/notifiers/schedule_notifier.dart#L197-L203)
- **Root Cause**:
  `BillingNotifier` is wired via `ProxyProvider4<ShieldNotifier, AudioNotifier, ScheduleNotifier, ThemeNotifier, BillingNotifier>`. Any time an upstream notifier calls `notifyListeners()`, `update` executes and calls `billing.attachShieldNotifier(shield)`. If the user is Pro, this invokes `shieldNotifier?.unlockLifetimePro()`. In `ShieldNotifier.unlockLifetimePro()`, line 345 unconditionally calls `notifyListeners()`.
- **Impact**:
  Because `ShieldNotifier` notifies its listeners, `ProxyProvider4.update` is immediately invoked again synchronously/re-entrantly. This triggers an infinite notification loop that freezes the UI thread and drops all frame rendering for Pro users on app launch.

#### 1.4 Background Activity Launch (BAL) Restriction Violation on Android 10–15
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:304–323`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L304-L323)
- **Root Cause**:
  `dismissOverlayAndReturnToApp` executes `dismissOverlayOnly(appContext)` *before* calling `appContext.startActivity(launchIntent)`. On modern Android (API 29 through 35), background services are prohibited from launching activities unless they possess an active foreground window.
- **Impact**:
  By destroying the overlay window first, `FocusShieldService` revokes its own BAL exemption. Android drops the `startActivity` call with a BAL security violation, leaving the user stranded on the home screen or inside the blocked app instead of returning to Focusmaxxing.

#### 1.5 Life-Safety Hazard: Hardcoded Incomplete Emergency Package Whitelist in Maximum Focus Mode
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:113–125, 499–539`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L113-L125)
- **Root Cause**:
  `EXEMPT_PACKAGES` hardcodes a static list of Samsung and Google dialer/clock packages (`com.google.android.dialer`, `com.samsung.android.dialer`, etc.). OEMs such as Xiaomi (`com.miui.home`, `com.google.android.dialer` is replaced with `com.android.incallui`), OnePlus (`com.oneplus.dialer`), Oppo, Vivo, Motorola, and Sony use proprietary package names.
- **Impact**:
  In Maximum Focus mode on any non-Samsung/non-Pixel device, the full-screen overlay covers the screen during incoming emergency calls and prevents users from dialing emergency services (e.g., 911 / 112).

#### 1.6 Initial Session State Poisoning & Crash Data Loss
- **Files & Lines**:
  - [`lib/features/timer/domain/usecases/start_session_usecase.dart:31–41`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/domain/usecases/start_session_usecase.dart#L31-L41)
  - [`lib/features/timer/presentation/notifiers/timer_notifier.dart:409–434, 618–644`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart#L409-L434)
- **Root Cause**:
  `StartSessionUseCase` initializes new sessions in SQLite as `SessionStatus.cancelled` with `actual_duration_seconds: 0`. When a session finishes its countdown in `TimerNotifier.syncWithWallClock()`, the in-memory state becomes `TimerStatus.completed`, but **no write to SQLite occurs until the user manually taps the check-in dialog**.
- **Impact**:
  If the OS terminates the app (memory pressure, battery saver, swipe from Recents) mid-session or while the check-in dialog is showing, the session remains permanently recorded as `CANCELLED` with 0 duration. Completed focus work is lost and daily streaks break.

#### 1.7 Restorative Break Guard Drops Shield to Idle Before Session Start
- **Files & Lines**:
  - [`lib/features/timer/presentation/notifiers/timer_notifier.dart:527–548`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart#L527-L548)
  - [`lib/features/shield/presentation/notifiers/shield_notifier.dart:395–413`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart#L395-L413)
- **Root Cause**:
  `TimerNotifier.readyToFocusFromBreak()` resets `_status = TimerStatus.idle`. When `ShieldNotifier.syncWithTimer` detects `TimerStatus.idle`, it immediately calls `await repository.stopShieldService(force: true)`.
- **Impact**:
  The shield is completely disarmed before the user starts their next focus block, allowing the user to minimize the app and doomscroll distraction apps without any blocking.

#### 1.8 Free-Tier 2-App Cap Async Concurrency Bypass in `ShieldNotifier`
- **Files & Lines**:
  - [`lib/features/shield/presentation/notifiers/shield_notifier.dart:224–278`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart#L224-L278)
  - [`lib/features/shield/presentation/pages/shield_page.dart:226–238`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/pages/shield_page.dart#L226-L238)
- **Root Cause**:
  `toggleApp` validates `activeAppCount >= freeTierAppCap` against in-memory state *before* awaiting `toggleShieldAppUseCase(...)`. `_shieldedApps` is only updated after the database write finishes. Furthermore, the UI triggers `unawaited(_handleToggleApp(...))` without disabling the switch widgets.
- **Impact**:
  Rapidly tapping multiple app switches triggers concurrent calls where `activeAppCount` is read as $\le 1$. All calls succeed in parallel, bypassing the free-tier cap and letting free users shield unlimited apps.

#### 1.9 Audio Preload Loop Destroys & Overwrites Single Player Instance
- **Files & Lines**:
  - [`lib/features/audio/data/repositories/audio_repository_impl.dart:110–124`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/data/repositories/audio_repository_impl.dart#L110-L124)
- **Root Cause**:
  `preloadAudioAssets` iterates over soundscape file paths and sequentially calls `await _engine.setAsset(path)`. In `just_audio`, calling `setAsset` replaces the loaded media source on the single player instance.
- **Impact**:
  The loop loads asset 0, unloads it to load asset 1, and so forth, until only the last asset remains loaded. Earlier soundscapes are never cached in memory, burning disk I/O and causing audio playback stutter.

#### 1.10 Schedule End-Alarm Callback Kills Running Manual Focus Sessions
- **Files & Lines**:
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:59–67`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L59-L67)
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt:92–95`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt#L92-L95)
- **Root Cause**:
  `autoShieldEndAlarmCallback` sends `{'force': true}` to `stopShield`. Additionally, `AutoShieldAlarmReceiver` stops the service unconditionally upon receiving `ACTION_STOP_AUTO_SHIELD`.
- **Impact**:
  If a user starts a manual focus lock at 16:30 for 60 minutes and their scheduled window ends at 17:00, the schedule end alarm terminates `FocusShieldService` at 17:00, prematurely disarming their active manual focus session.

#### 1.11 Race Condition Irreversibly Wipes Pro Theme Accent on Startup
- **Files & Lines**:
  - [`lib/features/billing/presentation/notifiers/billing_notifier.dart:106–127, 216–218`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/presentation/notifiers/billing_notifier.dart#L106-L127)
  - [`lib/core/theme/theme_notifier.dart:6–10, 58–66`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/theme/theme_notifier.dart#L6-L10)
- **Root Cause**:
  `ThemeNotifier` synchronously restores the saved accent color from disk on launch (e.g. Pro `sunsetOrange`). Meanwhile, `BillingNotifier` initializes with `_unlockStatus = ProUnlockStatusEntity.locked`. If the receipt check is delayed or unverified, line 115 executes `themeNotifier?.validateProAccess(isLifetimePro: false)`.
- **Impact**:
  `validateProAccess` detects that `_currentAccent.isProOnly` is true, resets the accent to `electricEmerald`, and permanently executes `prefs.remove(prefThemeAccentColorKey)`. The user's purchased Pro theme is wiped before Google Play Billing has finished verifying.

---

### High Severity

#### 1.12 Audio Focus Configuration Permanently Ducks Third-Party Media (Spotify/Podcasts)
- **Files & Lines**:
  - [`lib/features/audio/data/datasources/audio_player_engine.dart:20–22, 63–75`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/data/datasources/audio_player_engine.dart#L20-L75)
- **Root Cause**:
  In `AudioPlayerEngine`, the enum wrapper sets:
  ```dart
  static const none = AndroidAudioFocusGainType(
      audio_session.AndroidAudioFocusGainType.gainTransientMayDuck);
  ```
- **Impact**:
  Android OS grants `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`. All active media players (Spotify, YouTube Music, Apple Music, podcasts) receive `AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK` and are permanently attenuated by ~75% throughout the entire 25–60 minute session, violating the PRD requirement that soundscapes mix ambiently without ducking external audio.

#### 1.13 Missing 15-Second Preview Timer & Pro Preview Lockout
- **Files & Lines**:
  - [`lib/features/audio/presentation/notifiers/audio_notifier.dart:286–350`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/presentation/notifiers/audio_notifier.dart#L286-L350)
- **Root Cause**:
  `togglePreview` initiates loop playback with `LoopMode.one` and never starts an auto-stop timer. Furthermore, free users are completely blocked from playing Pro soundscapes (`if (target.isProOnly && !_isProUnlocked) return;`).
- **Impact**:
  Soundscapes loop indefinitely instead of stopping after 15 seconds, and free users are completely barred from sampling Pro soundscapes before buying.

#### 1.14 `SCHEDULE_EXACT_ALARM` Crashes with Uncaught `SecurityException` on Android 13/14+
- **Files & Lines**:
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:148, 158`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L148)
  - [`android/app/src/main/AndroidManifest.xml:13`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/AndroidManifest.xml#L13)
- **Root Cause**:
  `ScheduleAlarmDataSourceImpl.scheduleAlarms` calls `AndroidAlarmManager.periodic(..., exact: true)`. On Android 13+ and Android 14+ (API 34), `SCHEDULE_EXACT_ALARM` is denied by default for new installs. Calling `setExactAndAllowWhileIdle()` without checking `canScheduleExactAlarms()` throws an uncaught `java.lang.SecurityException`.
- **Impact**:
  Enabling a schedule crashes the app with a `ScheduleException` on modern Android versions.

#### 1.15 `START_STICKY` State Obliteration on Low-Memory Process Restart
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:376–395, 413`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L376-L395)
- **Root Cause**:
  `onStartCommand` returns `START_STICKY`. When Android kills the service under memory pressure and restarts it, `intent` is `null`. Because `FocusShieldService` stores blocked packages in an in-memory companion object field (`@Volatile var blockedPackages: Set<String>`) without persisting them to disk, `blockedPackages` resets to `emptySet()`.
- **Impact**:
  The foreground service restarts, displays a persistent notification, but blocks zero applications.

#### 1.16 Detection Blind Spot: Grace Period & 2500ms Sliding Window Drops Events
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:454–458, 503–524, 600–606`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L454-L606)
- **Root Cause**:
  `dismissGraceUntilMs` (4000ms delay) skips the polling loop. The query start is `maxOf(lastProcessedEventTime - 250L, now - 2500L)`. If an app switch occurs at $t = 1.0\text{s}$ during the grace period, it is dropped from the query window at $t = 4.0\text{s}$.
- **Impact**:
  A user can remain inside a blocked application and scroll indefinitely without the shield ever triggering.

#### 1.17 Google Play Store Policy Violation: Direct `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` Dialog
- **Files & Lines**:
  - [`android/app/src/main/AndroidManifest.xml:10`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/AndroidManifest.xml#L10)
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt:189–212`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt#L189-L212)
- **Root Cause**:
  `MainActivity` directly triggers `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with `package:$packageName`. Google Play policies forbid direct dialog requests for non-VoIP/non-IoT apps.
- **Impact**:
  High probability of automatic app rejection upon Google Play Store submission.

#### 1.18 Overlay Window `FLAG_NOT_FOCUSABLE` Bypasses Flutter `PopScope`
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:630`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L630)
  - [`lib/features/shield/presentation/overlay/overlay_main.dart:133–145`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/overlay/overlay_main.dart#L133-L145)
- **Root Cause**:
  `FocusShieldService` sets `flag = defaultFlag` (`FLAG_NOT_FOCUSABLE`), so Android passes key and back gesture events directly through to the underlying window.
- **Impact**:
  The `PopScope(canPop: false)` declared in Flutter is completely bypassed. Users can swipe back to dismiss or interact with the underlying blocked application.

#### 1.19 Database Connection Getter Non-Idempotency and Ghost Failures
- **Files & Lines**:
  - [`lib/core/database/database_helper.dart:43–50`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/database/database_helper.dart#L43-L50)
- **Root Cause**:
  If `currentDb.isOpen` is false, `database` mutates state (`_database = null; _initFuture = null;`) and throws `DatabaseException('Database is closed')`. However, the very next call sees `_database == null` and successfully reinitializes.
- **Impact**:
  Produces erratic errors where the first call crashes a feature, but an immediate retry transparently succeeds.

#### 1.20 Multi-Migration Transaction Atomicity Breakdown
- **Files & Lines**:
  - [`lib/core/database/migrations/migration_runner.dart:13–32`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/database/migrations/migration_runner.dart#L13-L32)
- **Root Cause**:
  When `useTransaction: true` is supplied outside of `openDatabase`, each migration executes in its own isolated transaction block.
- **Impact**:
  If `MigrationV1` succeeds and commits, but `MigrationV2` fails, `MigrationV1` remains committed on disk while the runner aborts, leaving the database in a corrupted intermediate schema.

#### 1.21 Notification Small Icon Renders as Opaque White Square (API 21+)
- **Files & Lines**:
  - [`lib/core/notifications/notification_service.dart:79`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/notifications/notification_service.dart#L79)
  - `android/app/src/main/res/`
- **Root Cause**:
  `NotificationService` initializes with `@mipmap/ic_launcher` (a multi-color adaptive icon) instead of a flat monochrome silhouette on a transparent background.
- **Impact**:
  All notifications render as solid white or grey squares in the Android status bar across physical Android devices.

#### 1.22 Premature Full Target Duration Credited on Running Early Check-In
- **Files & Lines**:
  - [`lib/features/timer/presentation/notifiers/timer_notifier.dart:402–412`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart#L402-L412)
- **Root Cause**:
  `checkInSession` allows checking in while `_status == TimerStatus.running` and sets `actualDuration = _targetDurationSeconds`.
- **Impact**:
  If a user starts a 60-minute session and checks in after 1 minute, they are credited with 60 minutes of deep work.

#### 1.23 `TimerDialWidget` Discontinuity at 12 O'Clock & Destruction of >60m Sessions
- **Files & Lines**:
  - [`lib/features/timer/presentation/widgets/timer_dial_widget.dart:34–70`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/timer_dial_widget.dart#L34-L70)
- **Root Cause**:
  `rawMinutes = (fraction * 60).round()` and `if (snappedMinutes <= 0) snappedMinutes = 60`. Touching 0.5–2.0 minutes right of 12 o'clock snaps the session to 60 minutes. Furthermore, angles clamp strictly to $\le 60$ minutes.
- **Impact**:
  Touching the dial resets 90m or 120m sessions down to 60m, and scrubbing near 12 o'clock erratically jumps to 60m.

#### 1.24 Wall-Clock Drift and Daylight Saving Time (DST) Vulnerability
- **Files & Lines**:
  - [`lib/features/timer/presentation/notifiers/timer_notifier.dart:195, 237–245, 606–610`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart#L195)
- **Root Cause**:
  `targetEnd.difference(DateTime.now())` relies on local device wall-clock time rather than monotonic time (`Stopwatch` or `SystemClock.elapsedRealtime()`).
- **Impact**:
  Manual clock adjustments or autumn DST transitions extend a 25-minute timer to 1 hour 25 minutes, or cause sessions to finish prematurely.

#### 1.25 Periodic Alarm Drifts Over Daylight Saving Time (DST) Transitions
- **Files & Lines**:
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:140–162`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L140-L162)
- **Root Cause**:
  Alarms use `AndroidAlarmManager.periodic(const Duration(days: 1), ...)`. `Duration(days: 1)` is fixed at $86,400,000\text{ ms}$, which shifts by $\pm 1$ hour on 23h and 25h solar DST days.
- **Impact**:
  Scheduled alarms permanently drift by 1 hour following any DST transition.

#### 1.26 Anti-Tampering Bypassed via Plaintext SharedPreferences
- **Files & Lines**:
  - [`lib/features/billing/data/datasources/billing_local_cache_source.dart:83–86`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/data/datasources/billing_local_cache_source.dart#L83-L86)
  - [`lib/features/shield/presentation/notifiers/shield_notifier.dart:26`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart#L26)
  - [`lib/features/schedule/presentation/notifiers/schedule_notifier.dart:14`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/presentation/notifiers/schedule_notifier.dart#L14)
  - [`lib/features/audio/presentation/notifiers/audio_notifier.dart:74–78`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/presentation/notifiers/audio_notifier.dart#L74-L78)
- **Root Cause**:
  Feature notifiers inspect unencrypted plain-text booleans (`'is_lifetime_pro'`, `'is_pro_unlocked'`) rather than validating the XOR encrypted receipt.
- **Impact**:
  Writing `"is_lifetime_pro": true` via ADB or root unlocks all Pro features immediately.

#### 1.27 Pseudo-Cryptographic Signature & Dummy Purchase Verification
- **Files & Lines**:
  - [`lib/features/billing/data/datasources/billing_local_cache_source.dart:37–41, 170–185`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/data/datasources/billing_local_cache_source.dart#L37-L41)
  - [`lib/features/billing/data/repositories/billing_repository_impl.dart:306–313`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/data/repositories/billing_repository_impl.dart#L306-L313)
- **Root Cause**:
  Receipt encryption uses a hardcoded 24-byte XOR key and non-cryptographic FNV-1a checksum. `_verifyPurchaseLocally` only checks if the token string is non-empty without RSA public key verification.
- **Impact**:
  Zero tamper-resistance against mock purchase generators.

#### 1.28 Streak Calculation Grace Period & Backward Streak Freeze Flaws
- **Files & Lines**:
  - [`lib/features/insights/data/repositories/insights_repository_impl.dart:112–140`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/data/repositories/insights_repository_impl.dart#L112-L140)
- **Root Cause**:
  Today without a session is forgiven by the 24h grace period. If yesterday is also missed, `daysSinceLastFreeze >= 6` forgives yesterday as well.
- **Impact**:
  A user can miss two full consecutive days without losing their streak, and freezes are applied backwards without respect to calendar weeks.

---

### Medium Severity

#### 1.29 Duplicate Persistent Foreground Service Notifications
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:180–195`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L180-L195)
  - `flutter_overlay_window.OverlayService`
- **Root Cause**:
  Both `FocusShieldService` (notification 9001) and `OverlayService` (notification 4579) call `startForeground()`.
- **Impact**:
  Two persistent notifications stack up in the notification shade during every session.

#### 1.30 Overnight Schedule Window Boundary Gaps
- **Files & Lines**:
  - [`lib/features/schedule/data/datasources/schedule_alarm_data_source.dart:121–139`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/schedule/data/datasources/schedule_alarm_data_source.dart#L121-L139)
- **Root Cause**:
  When an overnight schedule (e.g. 22:00 to 06:00) is enabled while inside the window (e.g. 23:30), both `nextStart` and `nextEnd` calculate `.add(Duration(days: 1))`.
- **Impact**:
  Activation is delayed by a full 24 hours.

#### 1.31 Battery Drain: 500ms Continuous Binder IPC Over `UsageStatsManager`
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:446–606`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L446-L606)
- **Root Cause**:
  Synchronous Binder transactions query `system_server` every 500ms, and screen-off checks loop continuously every 2,000ms.
- **Impact**:
  Prevents device CPU from entering low-power sleep states, accelerating battery drain.

#### 1.32 No Reboot Recovery for Active Sessions or Scheduled Windows
- **Files & Lines**:
  - [`android/app/src/main/AndroidManifest.xml:73–89`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/AndroidManifest.xml#L73-L89)
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/AutoShieldAlarmReceiver.kt)
- **Root Cause**:
  `AutoShieldAlarmReceiver` lacks an `android.intent.action.BOOT_COMPLETED` intent filter.
- **Impact**:
  Scheduled auto-shield remains inactive after a device reboot until the next scheduled day.

#### 1.33 Home Widget Chronometer Runs Indefinitely into Negative Values
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/widget/GlanceableDialWidgetProvider.kt:40–42`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/widget/GlanceableDialWidgetProvider.kt#L40-L42)
- **Root Cause**:
  `RemoteViews` Chronometer does not stop automatically at 00:00 and continues counting into negative numbers.
- **Impact**:
  If the app is closed when the timer expires, the widget displays `-00:01`, `-00:02` indefinitely.

#### 1.34 Paused Timer Reverts Home Widget to Idle
- **Files & Lines**:
  - [`lib/features/timer/presentation/notifiers/timer_notifier.dart:252–261`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart#L252-L261)
- **Root Cause**:
  Pausing sets `isRunning: false` and `targetEndTimeEpochMs: 0`, switching the widget to `widget_idle_container`.
- **Impact**:
  The widget displays "Lock In", obscuring that a paused session is awaiting resumption.

#### 1.35 Deep Link Ignored When Timer Is Active
- **Files & Lines**:
  - [`lib/main_scaffold.dart:119–122`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/main_scaffold.dart#L119-L122)
- **Root Cause**:
  `_triggerQuickLockIn()` checks `if (timerNotifier.status != TimerStatus.idle) return;`.
- **Impact**:
  Tapping the widget while locked in will not bring the user to their active timer page.

#### 1.36 Missing iOS App Group ID & Widget Name in `WidgetSyncService`
- **Files & Lines**:
  - [`lib/features/widget/data/services/widget_sync_service_impl.dart:48–67`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/widget/data/services/widget_sync_service_impl.dart#L48-L67)
- **Root Cause**:
  `_saveWidgetData` omits `appGroupId` and `_updateWidget` omits `iOSName`.
- **Impact**:
  Widget sync is completely non-operational on iOS devices.

#### 1.37 Timezone Resolution Fallback Skews Scheduled Alarms to UTC
- **Files & Lines**:
  - [`lib/core/notifications/notification_service.dart:68–76, 331–346`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/notifications/notification_service.dart#L68-L346)
- **Root Cause**:
  Catch block defaults `tz.setLocalLocation(tz.UTC)`.
- **Impact**:
  A 9:00 AM EDT reminder fires at 5:00 AM EDT.

#### 1.38 Concurrent Purchase Race Condition in `BillingNotifier`
- **Files & Lines**:
  - [`lib/features/billing/presentation/notifiers/billing_notifier.dart:130–162`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/presentation/notifiers/billing_notifier.dart#L130-L162)
- **Root Cause**:
  Lacks a loading state guard on purchase initiation.
- **Impact**:
  Double-tapping purchase initiates duplicate Google Play Billing flows.

#### 1.39 `SessionCheckInDialog` Missing "Derailed & End All Sessions" Action
- **Files & Lines**:
  - [`lib/features/timer/presentation/widgets/session_checkin_dialog.dart:123–164`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/session_checkin_dialog.dart#L123-L164)
- **Root Cause**:
  "DERAILED" forces the user into a break, while "LOCKED IN & END ALL SESSIONS" marks success.
- **Impact**:
  Users who got distracted cannot end sessions while acknowledging failure.

#### 1.40 Double Cancellation Race in `HoldToCancelButton`
- **Files & Lines**:
  - [`lib/features/timer/presentation/widgets/hold_to_cancel_button.dart:94–114`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/hold_to_cancel_button.dart#L94-L114)
- **Root Cause**:
  Timer expiry and finger release both trigger `cancelSession()`.
- **Impact**:
  Triggers redundant async cancellations and potential race conditions on session IDs.

#### 1.41 Accessibility Fallback Failure in `HoldToCancelButton`
- **Files & Lines**:
  - [`lib/features/timer/presentation/widgets/hold_to_cancel_button.dart:141–148`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/hold_to_cancel_button.dart#L141-L148)
- **Root Cause**:
  Calls `onHoldStart()` and `onHoldEnd()` sequentially with an elapsed time of 0ms.
- **Impact**:
  Accessibility dialog confirmation fails to cancel the session.

#### 1.42 Missing SQLite Transaction in `SessionLocalDataSource`
- **Files & Lines**:
  - [`lib/features/timer/data/datasources/session_local_data_source.dart:26–38`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/data/datasources/session_local_data_source.dart#L26-L38)
- **Root Cause**:
  Session insert and backlog task completion run as separate queries without a wrapping transaction.
- **Impact**:
  Database inconsistencies if an error occurs mid-way.

---

### Low Severity

#### 1.43 Redundant Double IPC State Synchronization
- **Files & Lines**:
  - [`lib/features/shield/data/datasources/shield_native_bridge_source.dart:217, 225`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/data/datasources/shield_native_bridge_source.dart#L217)
  - [`lib/features/shield/presentation/overlay/overlay_main.dart:111–121`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/overlay/overlay_main.dart#L111-L121)
- **Impact**: Double IPC processing on every timer tick.

#### 1.44 Cold-Start Memory Overhead from Unconditional Secondary Engine Pre-Warming
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt:50`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt#L50)
- **Impact**: 30–50MB of RAM allocated unconditionally on startup even if sessions are never run.

#### 1.45 Deprecated `startForeground` Without Explicit Type Parameter
- **Files & Lines**:
  - [`android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt:407`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/shield/FocusShieldService.kt#L407)
- **Impact**: Deprecation warnings on Android 14+.

#### 1.46 Box Breathing Phase Duration Cycle Mismatch
- **Files & Lines**:
  - [`lib/features/shield/presentation/widgets/box_breathing_exercise.dart:24–26, 78–95`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/widgets/box_breathing_exercise.dart#L24-L26)
- **Impact**: 60s total duration divided by 16s cycle ends abruptly at 3.75 cycles.

#### 1.47 Hardcoded SQL Strings Violating Domain Constants
- **Files & Lines**:
  - [`lib/features/timer/data/datasources/session_local_data_source.dart:96–97`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/data/datasources/session_local_data_source.dart#L96-L97)
- **Impact**: Raw string literals `'FOCUS'`, `'LOCKED_IN'` bypass domain enums.

#### 1.48 Unbounded Task Title Length in Backlog Repository
- **Files & Lines**:
  - [`lib/features/backlog/data/repositories/backlog_repository_impl.dart:28–32`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/backlog/data/repositories/backlog_repository_impl.dart#L28-L32)
- **Impact**: Repository layer lacks input length validation.

#### 1.49 Backlog Startup Load Dependent on Modal Opening in Fallback Mode
- **Files & Lines**:
  - [`lib/features/backlog/presentation/notifiers/backlog_notifier.dart:20–25`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/backlog/presentation/notifiers/backlog_notifier.dart#L20-L25)
- **Impact**: Tasks unpopulated until modal sheet opens when using fallback factory.

#### 1.50 `AppDateUtils.getEndOfDay` Microsecond Omission
- **Files & Lines**:
  - [`lib/core/utils/date_utils.dart:6–8`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/core/utils/date_utils.dart#L6-L8)
- **Impact**: Omits 999 microseconds before midnight.

---

## Pillar 2: Bad Architectural Decisions

### 2.1 Split-Brain Triple State Machine
State is maintained independently across three execution environments:
1. Flutter Main Isolate (`TimerNotifier`)
2. Android Kotlin Service (`FocusShieldService`)
3. Overlay Flutter Engine (`HardLockOverlayWidget`)

All three run independent countdown tickers and expiration handlers. Asynchronous communication across MethodChannels causes clock skew, desynchronized notifications, and audio chimes firing out of sync with visual overlays.

### 2.2 God Mediator Pattern via `ProxyProvider4`
In [`lib/main.dart:313–325`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/main.dart#L313-L325), `BillingNotifier` receives direct instances of `ShieldNotifier`, `AudioNotifier`, `ScheduleNotifier`, and `ThemeNotifier`. 
- Presentation controllers should never manage the lifecycle of other presentation controllers.
- **Architectural Fix**: Pro entitlement is a domain concern. Domain use cases or reactive entitlement streams (`WatchProEntitlementUseCase`) should be listened to independently by each feature.

### 2.3 Presentation Notifiers Bypassing Domain Use Cases
Clean Architecture mandates that UI controllers interact with data through Use Cases. However:
- [`lib/features/shield/presentation/notifiers/shield_notifier.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart) bypasses use cases to call `repository.swapShieldApp`, `startShieldService`, `stopShieldService`, and listen to `repository.overlayEvents`.
- [`lib/features/billing/presentation/notifiers/billing_notifier.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/presentation/notifiers/billing_notifier.dart) reads `repository.purchaseStatusStream` directly.

### 2.4 Headless Dart Engine for Alarm Triggers
Spinning up an entire headless Dart VM just to call a native method to start a native service is an anti-pattern. Waking Dart takes 1–3 seconds and 40MB+ of RAM. Alarms should trigger native broadcast receivers directly via `PendingIntent`.

### 2.5 Dual Foreground Services Architecture
Running two foreground services simultaneously (`FocusShieldService` and `OverlayService`) introduces notification clutter and duplicate lifecycle management. `FocusShieldService` should manage the overlay `WindowManager` view directly.

---

## Pillar 3: Unmaintainable Code & Code Smells

### 3.1 Monolithic God Widgets
- [`lib/features/timer/presentation/pages/timer_page.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/pages/timer_page.dart): **1,643 lines of code** with 12 separate widget classes dumped into a single file.
- [`lib/features/shield/presentation/overlay/overlay_main.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/overlay/overlay_main.dart): **783 lines of code** combining IPC bridges, countdown timers, box breathing, and hold-to-cancel gestures.
- [`lib/features/shield/presentation/pages/shield_page.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/pages/shield_page.dart): **693 lines of code** with 10 internal widget classes.

### 3.2 Full-Page Rebuild Storms Under Root `Consumer`
In `timer_page.dart` (lines 533–621), `Consumer<TimerNotifier>` wraps the entire `SingleChildScrollView`. Every second, `syncWithWallClock()` calls `notifyListeners()`, forcing the entire page (app bar, goal pills, dial, soundscape pills, duration presets) to re-evaluate and rebuild.

### 3.3 Monolithic God Notifiers
- [`lib/features/timer/presentation/notifiers/timer_notifier.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart): **726 lines of code** with 9 injected dependencies.
- [`lib/features/shield/presentation/notifiers/shield_notifier.dart`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart): **550 lines of code** handling search, icons, free-tier limits, permissions, and native bridges.

### 3.4 Hardcoded Duplicated Keys and Code Clones
- Preferences keys like `'is_lifetime_pro'` are independently hardcoded in 5 separate files (`ScheduleConstants`, `ShieldNotifier`, `ScheduleNotifier`, `BillingLocalCacheSourceImpl`, and `BillingNotifier`).
- `_SectionHeader` is copy-pasted identically in `shield_page.dart` (line 337) and `insights_page.dart` (line 287).

---

## Pillar 4: Other Things That Need Work

### 4.1 Test Suite Vulnerabilities & False Confidence
1. **Off-Screen Hit Test Failure**:
   In [`test/features/timer/presentation/timer_page_test.dart:612–614`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/test/features/timer/presentation/timer_page_test.dart#L612-L614), `tester.tap` on `mini_player_play_pause` hits offset `(81.0, 614.0)` outside the 800x600 test screen. The tap handler is never executed.
2. **Untested Native Bridges**:
   Background alarm callbacks (`autoShieldStartAlarmCallback`) have **0% test coverage**.
3. **Database Initialization Bypassed**:
   `database_helper_test.dart` uses `DatabaseHelper.setMockDatabase()`, meaning real SQLite table creation, version upgrades, and foreign keys are never executed in tests.

### 4.2 Android 14/15 Compliance & Google Play Safety
- **FGS `specialUse` Risk**:
  Declaring `foregroundServiceType="specialUse"` requires strict justification video submissions during Play Store review. Failure to justify will result in rejection.
- **Dynamic Emergency Dialer Resolution**:
  Hardcoded emergency packages must be replaced with dynamic queries using `TelecomManager.defaultDialerPackage` and `Intent(Intent.ACTION_DIAL)`.

### 4.3 Active Session Tombstone & Crash Recovery
If the app is killed mid-session, upon restart `TimerNotifier` starts in `idle` mode without checking SQLite for an interrupted active session. An explicit recovery/tombstone pipeline is required.

---

## Prioritized Master Remediation Roadmap

```
+----------------------------------------------------------------------------------------------------------+
| REMEDIATION MATRIX                                                                                       |
+----------------------------------------------------------------------------------------------------------+
| PHASE 1: Critical Fixes & Stability                                                                      |
| - Wire background alarms to native AutoShieldAlarmReceiver PendingIntents (bypass headless Dart isolate)  |
| - Break ProxyProvider4 infinite loop: guard unlockLifetimePro and decouple BillingNotifier               |
| - Fix AndroidAudioFocusGainType.none ducking mapping in AudioPlayerEngine                                |
| - Fix BAL restriction violation in FocusShieldService: keep overlay visible until Activity launch        |
| - Add dynamic emergency dialer resolution in Maximum Focus mode                                          |
| - Guard StartSessionUseCase: write accurate completion state upon session finish                         |
| - Atomic mutex on ShieldNotifier.toggleApp to enforce free-tier 2-app cap                                |
|                                                                                                          |
| PHASE 2: Core Infrastructure & Bug Hardening                                                             |
| - Add monochrome ic_notification.xml for Android status bar                                             |
| - Fix UsageStats sliding window event detection in FocusShieldService                                    |
| - Fix DatabaseHelper non-idempotent closed state exception                                               |
| - Wrap MigrationRunner in a single atomic transaction                                                    |
| - Fix overnight schedule calculation and DST drift                                                       |
| - Unify Pro verification to validate cryptographic receipt rather than plaintext SharedPreferences      |
|                                                                                                          |
| PHASE 3: Architecture & Monolith Decomposition                                                           |
| - Decompose timer_page.dart (1,643 lines) into isolated widget components                                |
| - Decompose overlay_main.dart (783 lines) into distinct controller and view layers                       |
| - Remove direct repository access from ShieldNotifier and BillingNotifier                                |
| - Replace ProxyProvider4 with domain entitlement stream (WatchProEntitlementUseCase)                    |
|                                                                                                          |
| PHASE 4: Platform Optimization & Test Quality                                                            |
| - Fix off-screen hit-test viewport in timer_page_test.dart                                               |
| - Write unit tests for alarm callbacks, overnight windows, and streak freeze boundaries                  |
| - Add BroadcastReceiver for SCREEN_OFF to suspend UsageStats polling during deep sleep                   |
| - Implement crash tombstone recovery for active sessions upon app cold start                             |
+----------------------------------------------------------------------------------------------------------+
```
