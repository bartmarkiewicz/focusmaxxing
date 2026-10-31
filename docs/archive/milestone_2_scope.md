# Focusmaxxing - Milestone 2 Technical Scoping Document

**Document:** Milestone 2 Technical Implementation Scope  
**Feature:** The Brainrot Shield Engine & Flutter-First App Blocker Architecture  
**Target Platform:** Android (API 26+ / Android 8.0 through Android 14+)  
**Architecture:** Pure Flutter Clean Architecture + `flutter_overlay_window` + Minimal Native UsageStats Hook  
**Parent PRD:** [docs/requirements.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/requirements.md)  
**Technical Companion:** [docs/technical_scoping.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/technical_scoping.md)  
**Milestone 1 Scope:** [docs/milestone_1_scope.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/milestone_1_scope.md)

---

## 1. Milestone 2 Objectives & Flutter-First Vision

Deliver the core technological differentiator of Focusmaxxing: **The Brainrot Shield**—an active OS-level application interception engine that physically prevents compulsive doomscrolling during focus blocks and rest periods.

Crucially, **100% of the user interface (including the Hard Lock overlay itself) is written in Flutter (Dart)**, utilizing Flutter's secondary engine entry-point (`flutter_overlay_window`) so that design tokens, Material 3 theming, tabular countdown figures, and animations remain unified without writing separate Android XML layouts.

### Deliverable Capabilities
1. **Pure Flutter Hard Lock Overlay (`flutter_overlay_window`):** The full-screen intervention view is a native Flutter widget (`@pragma("vm:entry-point") void overlayMain()`) styled with our exact Design System tokens.
2. **Flutter Inter-Engine State Synchronization:** Real-time data streaming (`shareData` / `overlayListener`) pushing live countdown seconds and active 1-sentence goals to the overlay widget.
3. **Flutter Installed App Discovery (`installed_apps`):** Discovers installed third-party apps, resolves package names, and streams raw PNG icon bytes directly into Dart `AppInfo` models.
4. **Lightweight Native Usage Poller (~60 lines Kotlin):** An ultra-lean Android foreground service polling `UsageStatsManager` every 500ms on a background coroutine with zero CPU/RAM bloat, triggering `FlutterOverlayWindow.showOverlay()`.
5. **Restorative Break Guard:** Shields remain continuously active during 5-minute rest breaks and hold the lock past `00:00` until the user returns to Focusmaxxing and taps `[ Lock In ]`.
6. **Free Tier Enforcement (2-App Cap):** Clean Architecture state management enforcing the 2-app free limit with an upgrade bottom sheet offering `[ Swap Free App ]` or Lifetime Pro.

---

## 2. Flutter-First System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        MAIN FLUTTER ENGINE                             │
│                                                                        │
│   TimerNotifier ──(ticks/states)──> ShieldNotifier                     │
│                                           │                            │
│                  ┌────────────────────────┴───────────────────────┐    │
│                  │                                                │    │
│                  v (MethodChannel)                                v    │
│   ┌───────────────────────────────┐           ┌──────────────────────┐ │
│   │ FocusShieldService (Native)   │           │ FlutterOverlayWindow │ │
│   │ • 500ms UsageStats Poller     │           │ .shareData(jsonState)│ │
│   └──────────────┬────────────────┘           └───────────┬──────────┘ │
└──────────────────┼────────────────────────────────────────┼────────────┘
                   │                                        │ (Inter-Engine IPC)
                   v (Trigger overlay)                      v
┌────────────────────────────────────────────────────────────────────────┐
│                      SECONDARY FLUTTER ENGINE                          │
│                                                                        │
│   @pragma("vm:entry-point") void overlayMain()                         │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │ HardLockOverlayWidget (100% Flutter Material 3 Widget)         │   │
│   │ • Subscribes to FlutterOverlayWindow.overlayListener           │   │
│   │ • Renders 1-sentence goal, tabular countdown, lock copy       │   │
│   │ • [ Return to Focusmaxxing ] button -> brings app to front     │   │
│   └────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Flutter Overlay Implementation (`flutter_overlay_window`)

### 3.1 Overlay Entry Point (`lib/features/shield/presentation/overlay/overlay_main.dart`)

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HardLockOverlayWidget(),
  ));
}

class HardLockOverlayWidget extends StatefulWidget {
  const HardLockOverlayWidget({super.key});

  @override
  State<HardLockOverlayWidget> createState() => _HardLockOverlayWidgetState();
}

class _HardLockOverlayWidgetState extends State<HardLockOverlayWidget> {
  String _taskGoal = "Deep Work";
  int _remainingSeconds = 1500;
  bool _isBreakMode = false;

  @override
  void initState() {
    super.initState();
    // Real-time inter-engine stream from main app
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String) {
        final state = jsonDecode(data);
        setState(() {
          _taskGoal = state['goal'] ?? _taskGoal;
          _remainingSeconds = state['remainingSeconds'] ?? _remainingSeconds;
          _isBreakMode = state['isBreak'] ?? _isBreakMode;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFF090A0D), // Midnight OLED Surface
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: Color(0xFFFF3B30)),
              const SizedBox(height: 16),
              Text(
                _isBreakMode ? "RECHARGE YOUR BRAIN" : "LOCKED IN",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isBreakMode
                    ? "Social feeds remain locked during your break."
                    : '"$_taskGoal"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Color(0xFF8B92A4)),
              ),
              const SizedBox(height: 32),
              Text(
                "$minutes:$seconds",
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () async {
                    // Brings main Focusmaxxing app to foreground
                    await FlutterOverlayWindow.closeOverlay();
                  },
                  child: const Text(
                    "RETURN TO FOCUSMAXXING",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 4. Installed Apps Discovery in Flutter (`installed_apps`)

Instead of writing custom `PackageManager` loops in Kotlin, Milestone 2 utilizes the `installed_apps` Flutter package:

```dart
// lib/features/shield/data/datasources/shield_installed_apps_source.dart
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

abstract class IShieldInstalledAppsSource {
  Future<List<AppInfo>> getInstalledApplications();
}

class ShieldInstalledAppsSourceImpl implements IShieldInstalledAppsSource {
  @override
  Future<List<AppInfo>> getInstalledApplications() async {
    // Automatically excludes system apps and fetches high-res icon byte arrays
    final apps = await InstalledApps.getInstalledApps(
      true, // withIcon
      true, // checkSystemApps (excludes system apps)
    );
    return apps;
  }
}
```

---

## 5. Minimal Native Android Detection Hook (`FocusShieldService.kt`)

The native companion is strictly reduced to an ultra-lean ~60-line Kotlin service whose sole job is to query `UsageStatsManager` and trigger `FlutterOverlayWindow`:

```kotlin
package com.example.focusmaxxing.shield

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import flutter.overlay.window.FlutterOverlayWindowPlugin

class FocusShieldService : Service() {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private var blockedPackages = listOf<String>()
    private var isShieldActive = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        blockedPackages = intent?.getStringArrayListExtra("BLOCKED_PACKAGES") ?: listOf()
        isShieldActive = true

        startForeground(1001, createNotification())
        startPollingLoop()
        return START_STICKY
    }

    private fun startPollingLoop() {
        scope.launch {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            while (isShieldActive) {
                val now = System.currentTimeMillis()
                val events = usageStatsManager.queryEvents(now - 2000, now)
                val event = UsageEvents.Event()
                var currentPackage: String? = null

                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                        currentPackage = event.packageName
                    }
                }

                if (currentPackage != null && blockedPackages.contains(currentPackage)) {
                    // Triggers the pure Flutter overlay widget!
                    withContext(Dispatchers.Main) {
                        FlutterOverlayWindowPlugin.showOverlay(
                            this@FocusShieldService,
                            100, // height percentage
                            100, // width percentage
                            "overlayMain"
                        )
                    }
                }
                delay(500) // 500ms interval for zero battery impact
            }
        }
    }

    override fun onDestroy() {
        isShieldActive = false
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        val channelId = "focus_shield_channel"
        // Standard notification creation
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Brainrot Shield Active")
            .setContentText("Focus session in progress")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()
    }
}
```

---

## 6. Clean Architecture Layer Breakdown (`lib/features/shield/`)

```
lib/features/shield/
├── domain/
│   ├── entities/
│   │   ├── shielded_app_entity.dart      # Package name, title, iconBytes, active flag
│   │   └── shield_permission_status.dart # Usage access & overlay booleans
│   ├── repositories/
│   │   └── i_shield_repository.dart      # Domain interface
│   └── usecases/
│       ├── get_shielded_apps_usecase.dart
│       ├── toggle_shield_app_usecase.dart
│       ├── get_installed_apps_usecase.dart
│       ├── check_shield_permissions_usecase.dart
│       ├── request_permission_usecase.dart
│       └── sync_shield_with_overlay_usecase.dart
│
├── data/
│   ├── models/
│   │   └── shielded_app_model.dart       # fromMap, toMap, toEntity
│   ├── datasources/
│   │   ├── shield_local_data_source.dart # SQLite database (shielded_apps table)
│   │   ├── shield_installed_apps_source.dart # package:installed_apps
│   │   └── shield_native_bridge_source.dart # MethodChannel for starting service
│   └── repositories/
│       └── shield_repository_impl.dart   # Implements IShieldRepository
│
└── presentation/
    ├── notifiers/
    │   └── shield_notifier.dart          # Manages 2-app free cap, search, and IPC state
    ├── pages/
    │   └── shield_page.dart              # Main Shield Tab (Tab 2)
    ├── widgets/
    │   ├── permission_banner_widget.dart # Contextual permission warning with deep link
    │   ├── quick_preset_card.dart        # 1-tap presets (Instagram, TikTok, Reddit, etc.)
    │   ├── installed_app_tile.dart       # Searchable list tile with MemoryImage icon
    │   └── upgrade_modal_sheet.dart      # 2-app free cap paywall & "Swap Free App"
    └── overlay/
        └── overlay_main.dart             # Pure Flutter Hard Lock Overlay entry point
```

---

## 7. Edge Cases, Hardware & OS Resilience Specifications

### 7.1 Mid-Session Permission Revocation (Graceful Degradation)
* If a user navigates to Android Settings during an active focus block and revokes Usage Access or Overlay permissions:
  * The active focus timer **continues running uninterrupted** without data loss.
  * The background detection loop safely catches the `SecurityException` and transitions the native shield into `DEGRADED_PAUSED` state.
  * Dispatches a high-priority persistent notification: *"Shield Paused: Permission revoked. Tap to restore focus protection."*
  * Tapping the notification opens Focusmaxxing to the Shield tab with the permission banner highlighted.

### 7.2 Multi-Window Split-Screen & Picture-in-Picture (PiP) Takeover
* On large phones, foldables, and tablets, if a user launches a blocked app (e.g. YouTube or TikTok) in Android Split-Screen or a floating PiP window:
  * `FlutterOverlayWindow.showOverlay(100, 100)` executes full-screen (`MATCH_PARENT` x `MATCH_PARENT`).
  * The overlay floats above all split-screen window panes and PiP surfaces, completely blocking touch input and video viewing until the user taps `[ Return to Focusmaxxing ]`.

### 7.3 Dynamic App Inventory Synchronization
* Whenever the user navigates to the Shield tab (Tab 2):
  * Asynchronously invokes `InstalledApps.getInstalledApps()` in the background to detect newly installed apps or deleted packages.
  * Automatically purges uninstalled packages from the SQLite `shielded_apps` table.
  * Supports pull-to-refresh for immediate manual re-scans.

### 7.4 Mobile Web Browser Loophole Defense
* To close the loophole of users opening social media via mobile web:
  * Web browsers (Google Chrome, Firefox, Brave, Samsung Internet) are listed as standard selectable apps in the Shield tab.
  * Includes a dedicated **"Web Browsers" Quick-Preset card** allowing users to lock down all web browsers during focus sessions with a single tap.

### 7.5 Direct "Swap Free App" Interaction Workflow
* When a Free Tier user attempts to toggle a 3rd app:
  * `UpgradeModalSheet` opens explaining the 2-app free cap and promoting the $9.99 Lifetime Pro unlock.
  * Tapping `[ Swap Free App ]` opens a focused sub-sheet displaying the two currently active apps with radio buttons.
  * Selecting one and tapping `[ Confirm Swap ]` immediately deactivates the chosen app and activates the newly selected app. Zero payment required; completes in 2 taps.

### 7.6 Android OEM Battery Optimization (Doze Mode Defense)
* Aggressive OEM battery killers (Samsung One UI, Xiaomi HyperOS) can kill background services during screen-off intervals.
* The Shield tab's permission banner includes an **"Unrestricted Battery"** item:
  * Deep-links directly to `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  * Contextual explanation explains that granting unrestricted battery ensures the shield never sleeps during long focus blocks.

```yaml
dependencies:
  # Milestone 1 dependencies...
  flutter:
    sdk: flutter
  provider: ^6.1.2
  sqflite: ^2.3.3+1
  path: ^1.9.0
  shared_preferences: ^2.2.3
  equatable: ^2.0.5
  dartz: ^0.10.1
  dynamic_color: ^1.7.0
  flutter_local_notifications: ^17.2.1+2

  # Milestone 2 additions:
  flutter_overlay_window: ^0.5.1   # Pure Flutter overlay over other apps
  installed_apps: ^2.0.0           # Query installed third-party apps & icons in Dart
```

---

## 8. Testing Suite for Milestone 2

### 8.1 Unit Tests (`test/features/shield/...`)
* **`ShieldNotifierTest`:**
  * Test adding apps up to the 2-app free cap succeeds.
  * Test attempting to toggle a 3rd app on the Free tier emits an upgrade event and rejects activation.
  * Test activating Pro status lifts the 2-app limit and allows unlimited app selections.
  * Test search query filtering correctly filters the `allInstalledApps` list by app title.
* **`ShieldRepositoryImplTest`:**
  * Test querying SQLite `shielded_apps` returns active records.
  * Test updating app active flag dispatches to both SQLite and updates native lists.

### 8.2 Widget Tests (`test/presentation/shield/...`)
* **`ShieldPageTest`:**
  * Pump widget with missing permissions -> assert `PermissionBannerWidget` is visible with `[ Fix Now ]`.
  * Pump widget with granted permissions -> assert banner is hidden.
  * Tap a Quick-Preset card -> assert selection state updates.
  * Enter text in app search bar -> assert list filters in real-time.
* **`HardLockOverlayWidgetTest`:**
  * Pump `HardLockOverlayWidget` -> verify goal headline, tabular figures countdown, and `[ RETURN TO FOCUSMAXXING ]` button.
* **`UpgradeModalSheetTest`:**
  * Verify 2-app cap explanation text and $9.99 Lifetime Pro button.
  * Tap `[ Swap Free App ]` -> verify list of active apps with radio selectors.

---

## 9. Implementation Checklist for Milestone 2

- [ ] **Step 1: Flutter Dependencies & Android Manifest Setup**
  - Add `flutter_overlay_window` and `installed_apps` to `pubspec.yaml`.
  - Add `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, and `FOREGROUND_SERVICE` to `AndroidManifest.xml`.
- [ ] **Step 2: Hard Lock Flutter Overlay Entry Point**
  - Implement `overlay_main.dart` with `HardLockOverlayWidget` and `overlayListener`.
  - Register `@pragma("vm:entry-point") void overlayMain()` in Flutter.
- [ ] **Step 3: Lean Kotlin Background Poller (~60 lines)**
  - Implement `FocusShieldService.kt` to poll `UsageStatsManager` and trigger `FlutterOverlayWindow.showOverlay()`.
  - Wire `MethodChannel("com.focusmaxxing/shield")` in `MainActivity.kt`.
- [ ] **Step 4: Shield Domain & Data Layers (Clean Architecture)**
  - Implement `ShieldedAppEntity`, `ShieldPermissionStatus`, and `IShieldRepository`.
  - Implement `ShieldInstalledAppsSourceImpl` using `package:installed_apps`.
  - Implement `ShieldLocalDataSource` with SQLite queries on `shielded_apps`.
  - Implement `ShieldRepositoryImpl`.
- [ ] **Step 5: Shield Presentation Layer & UI**
  - Implement `ShieldNotifier` with 2-app free cap and search filter.
  - Build `PermissionBannerWidget` with direct Android intent routing.
  - Build `QuickPresetCard` grid for top social feeds.
  - Build searchable `InstalledAppTile` list with `Image.memory(app.iconBytes)`.
  - Build `UpgradeModalSheet` with Lifetime Pro unlock and `[ Swap Free App ]` flow.
  - Implement `ShieldPage` in Tab 2.
- [ ] **Step 6: Timer <-> Shield Synchronization**
  - Connect `TimerNotifier` events to `ShieldNotifier`:
    - Focus start -> starts shield service & syncs goal.
    - Timer tick -> calls `FlutterOverlayWindow.shareData()` with live remaining seconds.
    - Break mode -> updates overlay copy to Rest Mode; keeps apps locked.
    - Break expired (00:00) -> keeps apps locked until next session starts.
    - Cancel/Complete -> closes overlay and terminates service.
- [ ] **Step 7: Automated Tests**
  - Write unit tests for `ShieldNotifier` and `ShieldRepositoryImpl`.
  - Write widget tests for `ShieldPage`, `HardLockOverlayWidget`, and `UpgradeModalSheet`.
  - Run `flutter test` and verify 100% pass rate.
