# Focusmaxxing - Milestone 3 Technical Scoping Document

**Document:** Milestone 3 Technical Implementation Scope  
**Feature Set:** Ambient Audio, One-Time Lifetime Pro Billing, Scheduled Auto-Shield, Widgets & Store Polish  
**Target Platform:** Android (API 26+ / Android 8.0 through Android 14+)  
**Architecture:** Pure Flutter Clean Architecture + `just_audio` + `in_app_purchase` + `home_widget`  
**Parent PRD:** [docs/requirements.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/requirements.md)  
**Technical Companion:** [docs/technical_scoping.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/technical_scoping.md)  
**Milestone 1 Scope:** [docs/milestone_1_scope.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/milestone_1_scope.md)  
**Milestone 2 Scope:** [docs/milestone_2_scope.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/milestone_2_scope.md)

---

## 1. Overview & Phased Execution Strategy

To ensure high engineering velocity, strict quality control, and clean verification, Milestone 3 is broken down into **5 independent, sequentially executable sub-phases**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   MILESTONE 3 IMPLEMENTATION ROADMAP                   │
├────────────────────────────────────────────────────────────────────────┤
│  Phase 3.1: Offline Audio Engine & Background Soundscapes              │
│  ├── just_audio + audio_session mixing pipeline                        │
│  └── Bundled OGG seamless loops (Brown noise, 40Hz, Rain)              │
│                                  │                                     │
│                                  v                                     │
│  Phase 3.2: Native In-App Billing (One-Time Lifetime Pro Unlock)       │
│  ├── in_app_purchase single non-consumable ($9.99 flat)                │
│  └── Client-side receipt caching, restore purchase, & gate unblocking  │
│                                  │                                     │
│                                  v                                     │
│  Phase 3.3: Scheduled Auto-Shield Engine                               │
│  ├── Work/Study hours scheduler (e.g., Mon-Fri 09:00 - 17:00)          │
│  └── Automated background arming of FocusShieldService                 │
│                                  │                                     │
│                                  v                                     │
│  Phase 3.4: Home Screen Quick-Launch Widgets                           │
│  ├── home_widget Android AppWidget integration                         │
│  └── 1x1 Quick Lock-In trigger & 2x2 glanceable focus dial             │
│                                  │                                     │
│                                  v                                     │
│  Phase 3.5: Final Polish, Theming & Google Play Packaging              │
│  ├── Adaptive icons, splash screen, OLED accent themes                 │
│  └── R8 / ProGuard rules, AAB bundle generation, & full E2E pass       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Phase 3.1: Offline Audio Engine & Background Soundscapes

### 2.1 Objectives & Deliverables
* Provide neurodivergent-friendly ambient audio that stimulates cognitive focus and drowns out household noise.
* Support seamless gapless looping and **audio mixing** so users can play brown noise simultaneously over their Spotify/YouTube Music playlists.
* Kept strictly inside the Settings / Config section in Tab 3 to preserve the Timer screen as a sacred, distraction-free space.

### 2.2 Audio Pipeline Specification (`just_audio` + `audio_session`)
* **Audio Session Configuration (Mixing & Background Playback):**
  ```dart
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
    androidWillPauseWhenDucked: false,
  ));
  ```
* **Bundled Assets (High-efficiency OGG Vorbis, 64kbps, seamless loop cut):**
  * `assets/audio/brown_noise_loop.ogg` (~1.2MB, low-frequency white noise alternative)
  * `assets/audio/gamma_40hz_loop.ogg` (~900KB, isochronic cognitive entrainment)
  * `assets/audio/rain_canvas_loop.ogg` (~1.4MB, gentle natural ambient)
  * `assets/audio/chime_complete.ogg` (~120KB, rewarding completion chime)

### 2.3 Clean Architecture Structure (`lib/features/audio/`)
* **Domain:**
  * `SoundscapeEntity` (id, title, assetPath, isProOnly).
  * `IAudioRepository` interface (`playLoop`, `stopLoop`, `setVolume`, `preloadAssets`).
  * Use Cases: `PlaySoundscapeUseCase`, `StopSoundscapeUseCase`, `SetAudioVolumeUseCase`.
* **Data:**
  * `AudioRepositoryImpl` wrapping `AudioPlayer` from `just_audio`.
  * Handles loop configuration: `player.setLoopMode(LoopMode.one)`.
* **Presentation:**
  * `AudioNotifier` (`ChangeNotifier`):
    * Manages active soundscape (`none`, `brown_noise`, `gamma_40hz`, `rain`).
    * Manages volume slider (`0.0` to `1.0`, default `0.5`).
    * Exposes `isPlaying` and preview play toggle.
  * `SoundscapeConfigTile` (Settings widget):
    * Radio tile selector with live preview button and volume slider.
    * Displays Pro padlock badge on premium loops if Lifetime Pro is locked.

### 2.4 Testing Plan for Phase 3.1
* **Unit Tests (`test/features/audio/audio_notifier_test.dart`):**
  * Test selecting soundscape starts playback and updates active state.
  * Test volume slider dispatches clamped values to repository.
  * Test selecting 'None' stops player.
* **Widget Tests (`test/presentation/audio/soundscape_config_tile_test.dart`):**
  * Verify rendering of preview button and volume slider.

---

## 3. Phase 3.2: Native In-App Billing (One-Time Lifetime Pro Unlock)

### 3.1 Objectives & Deliverables
* Implement a single, non-consumable, one-time in-app purchase ($9.99 flat) via Google Play Billing.
* Zero recurring subscriptions, zero third-party revenue middlemen (no RevenueCat), and 100% offline-tolerant purchase state caching.
* Provide an immediate "Restore Purchases" button and Google Play Family Library compatibility.
* Unlock all gated features upon purchase:
  1. **Unlimited Shielded Apps** (lifts 2-app free cap).
  2. **All Neurodivergent Audio Loops** (Brown noise, 40Hz, Rain).
  3. **Scheduled Auto-Shield** (Phase 3.3).
  4. **Home Screen Widgets** (Phase 3.4).

### 3.2 In-App Purchase Architecture (`in_app_purchase`)
* **Product ID:** `focusmaxxing_lifetime_pro` (Single Non-Consumable).
* **Purchase Lifecycle Flow:**
  ```
  [ User taps "Unlock Lifetime Pro ($9.99)" ]
                │
                v
  [ InAppPurchase.buyNonConsumable(purchaseParam) ]
                │
                v
  [ Google Play Native Sheet: Payment Approved ]
                │
                v
  [ purchaseStream emits PurchaseDetails(status: purchased) ]
                │
                v
  [ Local Verification: Verify purchaseToken & productID ]
                │
                v
  [ Persist to Encrypted SharedPreferences: is_pro_unlocked = true ]
                │
                v
  [ Complete Transaction: InAppPurchase.completePurchase() ]
                │
                v
  [ Notify BillingNotifier, ShieldNotifier, AudioNotifier ]
  ```

### 3.3 Clean Architecture Structure (`lib/features/billing/`)
* **Domain:**
  * `ProUnlockStatusEntity` (isUnlocked, purchaseDateMs, orderId).
  * `IBillingRepository` interface (`getProDetails`, `purchaseLifetimePro`, `restorePurchases`, `isProPurchased`).
  * Use Cases: `GetProductDetailsUseCase`, `PurchaseLifetimeProUseCase`, `RestorePurchasesUseCase`.
* **Data:**
  * `BillingRepositoryImpl` wrapping `InAppPurchase.instance`.
  * Local Cache: `SharedPreferences` storing encrypted `is_pro_unlocked` boolean.
* **Presentation:**
  * `BillingNotifier` (`ChangeNotifier`):
    * Tracks purchase status: `initial`, `loading`, `purchased`, `error`.
    * Exposes `buyLifetimePro()` and `restorePurchases()`.
  * `LifetimeProBanner` (Widget in Shield tab and Settings tab):
    * High-contrast card with gold accent (`#FFB800`).
    * Displays: *"Unlock Unlimited Shielding & Audio for $9.99"*.
  * `ProSupporterBadge` (Rendered in header when unlocked).

### 3.4 Testing Plan for Phase 3.2
* **Unit Tests (`test/features/billing/billing_notifier_test.dart`):**
  * Test initial status reflects cached Pro purchase state.
  * Test purchase success dispatches `isProUnlocked = true` and unlocks dependent notifiers.
  * Test restore purchases fetches valid past purchase and updates local state.
* **Widget Tests (`test/presentation/billing/lifetime_pro_banner_test.dart`):**
  * Verify banner displays $9.99 price when locked.
  * Verify banner transitions to "⭐ Lifetime Pro Unlocked" badge when purchased.

---

## 4. Phase 3.3: Scheduled Auto-Shield Engine

### 4.1 Objectives & Deliverables
* Allow users to define recurring work/study hours (e.g., Monday through Friday from 09:00 to 17:00).
* During scheduled hours, the Brainrot Shield automatically arms and blocks selected social apps in the background, even without starting an active Pomodoro timer.
* Pro feature: Requires `focusmaxxing_lifetime_pro` unlock.

### 4.2 Scheduling Architecture (`android_alarm_manager_plus`)
* **Alarm Scheduling:**
  * Schedules an exact recurring alarm at `startTime` (e.g. 09:00) using Android `AlarmManager.setExactAndAllowWhileIdle()`.
  * Schedules a termination alarm at `endTime` (e.g. 17:00).
* **Alarm Callback (`@pragma("vm:entry-point") void autoShieldAlarmCallback()`):**
  * Triggered in background by Android OS.
  * Initializes native channel and starts `FocusShieldService` with active blocked packages.
  * Shows status bar notification: *"Scheduled Auto-Shield Active (09:00 - 17:00)"*.

### 4.3 Clean Architecture Structure (`lib/features/schedule/`)
* **Domain:**
  * `ScheduleConfigEntity` (isEnabled, startHour, startMinute, endHour, endMinute, activeDays: List<int>).
  * `IScheduleRepository` interface (`getSchedule`, `saveSchedule`, `armAlarms`, `cancelAlarms`).
  * Use Cases: `GetScheduleUseCase`, `SaveScheduleUseCase`, `ToggleAutoShieldUseCase`.
* **Data:**
  * `ScheduleRepositoryImpl` storing JSON configuration in `SharedPreferences` and scheduling via `android_alarm_manager_plus`.
* **Presentation:**
  * `ScheduleNotifier` (`ChangeNotifier`):
    * Manages active schedule toggles, time pickers, and weekday selection chips.
  * `ScheduleConfigSection` (Settings widget):
    * Master toggle switch.
    * Start / End time selectors (`showTimePicker`).
    * Day-of-week chip selector (Mon through Sun).

### 4.4 Testing Plan for Phase 3.3
* **Unit Tests (`test/features/schedule/schedule_notifier_test.dart`):**
  * Test schedule validation (start time must precede end time).
  * Test toggling schedule arms/cancels background alarms.
* **Widget Tests (`test/presentation/schedule/schedule_config_section_test.dart`):**
  * Test time picker dialog interaction and chip selection updates.

---

## 5. Phase 3.4: Home Screen Quick-Launch Widgets

### 5.1 Objectives & Deliverables
* Provide instant, glanceable focus triggers directly on the Android home screen so users can lock in without navigating through the app launcher.
* **Widget Variant 1 (1x1 Quick-Launch Pill):** 1-tap launcher that immediately pops up the 1-Sentence Goal modal.
* **Widget Variant 2 (2x2 Glanceable Progress Dial):** Displays today's completed focus minutes, active streak flame, and a "Lock In" action button.

### 5.2 Widget Architecture (`home_widget`)
* **Android Native AppWidget Provider:**
  * `android/app/src/main/res/layout/widget_quick_lockin.xml` (1x1 layout)
  * `android/app/src/main/res/layout/widget_glanceable_dial.xml` (2x2 layout)
* **Background Data Push:**
  * Whenever a focus session is completed in `TimerNotifier`, the app calls:
    ```dart
    await HomeWidget.saveWidgetData<int>('today_minutes', totalMinutes);
    await HomeWidget.saveWidgetData<int>('active_streak', currentStreak);
    await HomeWidget.updateWidget(name: 'GlanceableDialWidgetProvider');
    ```
* **Widget Tap Callback:**
  * Deep-links directly to `focusmaxxing://lockin`, opening the Goal Input Modal immediately upon app resume.

### 5.3 Testing Plan for Phase 3.4
* **Unit Tests (`test/features/widget/widget_sync_test.dart`):**
  * Verify `TimerNotifier` and `InsightsNotifier` dispatch correct string keys to `HomeWidget`.
* **Manual Verification:**
  * Place 1x1 and 2x2 widgets on Android home screen, verify tap actions and live counter updates.

---

## 6. Phase 3.5: Final Polish, Theming & Google Play Packaging

### 6.1 Adaptive Icons & Native Splash Screen
* **Adaptive App Icon (`flutter_launcher_icons`):**
  * High-contrast electric lock glyph on OLED Midnight background.
  * Monochromatic icon asset for Android 13+ Material You dynamic theming.
* **Native Splash Screen (`flutter_native_splash`):**
  * Zero blank white frames on cold launch.
  * Instant OLED Midnight (`#090A0D`) surface with centered emerald brand icon.

### 6.2 Pro Aesthetic Accent Variants
* In Settings, Lifetime Pro users can customize their focus accent color:
  * **Electric Emerald** (`#00E676`, Default Focus)
  * **Cyber Amber** (`#FFAB00`, High Intensity)
  * **Hyper Violet** (`#B388FF`, Deep Meditative Flow)
  * **Glacier Blue** (`#38B6FF`, Rest Mode Standard)

### 6.3 Android Release Optimization & ProGuard Rules
* Update `android/app/proguard-rules.pro`:
  ```pro
  # Flutter Overlay Window keep rules
  -keep class flutter.overlay.window.** { *; }

  # Just Audio / Media rules
  -keep class com.ryanheise.just_audio.** { *; }

  # In-App Purchase rules
  -keep class com.android.vending.billing.** { *; }
  ```
* Enable code shrinking, resource shrinking, and R8 obfuscation in `android/app/build.gradle.kts`.
* Execute production bundle build:
  ```bash
  flutter build appbundle --release
  ```

---

## 7. Dependencies to Add for Milestone 3 (`pubspec.yaml`)

```yaml
dependencies:
  # Existing Milestone 1 & 2 dependencies...
  
  # Phase 3.1: Audio
  just_audio: ^0.9.38
  audio_session: ^0.1.19

  # Phase 3.2: In-App Purchases
  in_app_purchase: ^3.2.0

  # Phase 3.3: Scheduled Alarms
  android_alarm_manager_plus: ^4.0.3

  # Phase 3.4: Home Screen Widgets
  home_widget: ^0.6.0

dev_dependencies:
  # Packaging & Icons
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.4.0
```

---

## 8. Milestone 3 Step-by-Step Execution Plan

```
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 3.1: Audio Soundscapes Engine                                    │
│ [ ] Add just_audio and audio_session to pubspec.yaml                   │
│ [ ] Add bundled OGG assets (brown_noise, gamma_40hz, rain, chime)      │
│ [ ] Implement AudioRepositoryImpl with gapless looping & audio mixing  │
│ [ ] Implement AudioNotifier and Settings SoundscapeConfigTile          │
│ [ ] Write unit & widget tests for audio features                       │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3.2: Native In-App Billing (Lifetime Pro)                        │
│ [ ] Add in_app_purchase to pubspec.yaml                                │
│ [ ] Create BillingRepositoryImpl with encrypted SharedPreferences cache│
│ [ ] Implement BillingNotifier with purchase & restore flows            │
│ [ ] Wire Pro unlock state to ShieldNotifier (unlimited apps)           │
│ [ ] Build LifetimeProBanner and ProSupporterBadge in UI                │
│ [ ] Write unit & widget tests for billing                              │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3.3: Scheduled Auto-Shield                                       │
│ [ ] Add android_alarm_manager_plus and configure AndroidManifest       │
│ [ ] Implement ScheduleRepositoryImpl & exact alarm scheduler           │
│ [ ] Implement ScheduleNotifier and Settings time picker UI             │
│ [ ] Verify background arming of FocusShieldService during work hours   │
│ [ ] Write unit & widget tests for scheduling                           │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3.4: Home Screen Widgets                                         │
│ [ ] Add home_widget to pubspec.yaml                                    │
│ [ ] Build 1x1 Quick Lock-In and 2x2 Glanceable Dial Android XML layouts│
│ [ ] Wire TimerNotifier and InsightsNotifier to push HomeWidget data   │
│ [ ] Verify widget tap deep-links to 1-Sentence Goal Modal              │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3.5: Release Polish & Store Packaging                            │
│ [ ] Configure flutter_launcher_icons (adaptive + monochrome)           │
│ [ ] Configure flutter_native_splash (OLED Midnight theme)              │
│ [ ] Implement Pro theme accent color picker in Settings                │
│ [ ] Configure ProGuard / R8 rules and build release AAB bundle         │
│ [ ] Execute full end-to-end integration test suite                     │
└────────────────────────────────────────────────────────────────────────┘
```
