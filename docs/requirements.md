# Focusmaxxing - Product Requirements Document (PRD)

**Document Version:** 1.0.0  
**Status:** Approved / In Inception  
**Target Platforms:** Android (Primary), iOS (Cross-platform Flutter)  

---

## 1. Executive Summary & Vision

**Focusmaxxing** is a clean, lightning-fast, distraction-free productivity mobile application built for knowledge workers, students, and individuals navigating ADHD or executive dysfunction. 

The core mission of Focusmaxxing is to dismantle the barriers to getting into deep work (frictionless entry) while aggressively protecting users from dopamine traps during break periods ("anti-brainrot" break hygiene).

### Core Pillars
1. **Zero Cognitive Friction:** Instant startup. Zero fluff. Minimum clicks from app launch to active focus session.
2. **Anti-Brainrot Break Hygiene:** Rest periods are actively guided away from high-stimulus traps (e.g., TikTok, Instagram Reels, YouTube Shorts) toward restorative physiological breaks (walking, stretching, reading, breathwork).
3. **Compassionate Productivity (ADHD-Friendly):** Configurable, non-punitive mechanisms. Optional streaks (can be toggled off to prevent guilt/dropout spirals).
4. **Actionable Self-Reflection & Metrics:** Simple 1–5 qualitative ratings post-focus and post-rest, combined with transparent usage analytics.
5. **Monetizable Foundation:** A viable freemium model offering high-utility power features, advanced analytics, distraction blocking, and audio soundscapes.

---

## 2. Target Audience & Problem Space

### 2.1 Target Personas
* **The ADHD / Neurodivergent Worker:** Struggles with task initiation, hyperfocus regulation, time blindness, and dopamine-seeking derailment during downtime.
* **The Distracted Knowledge Worker / Student:** Constantly tempted by algorithmic social feeds; needs quick structure without cumbersome project management overhead.
* **The High-Performance "Maxxer":** Wants granular session tracking, deep work metrics, and optimization without bloat.

### 2.2 Key Problems Solved
* **Start Friction:** Most timer apps require picking a project, tagging, setting categories, or viewing ads before starting.
* **Break Derailment ("Brainrot Breaks"):** A standard 5-minute break often spirals into 45 minutes of algorithmic social media scrolling, returning the user to work with depleted dopamine and reduced cognitive energy.
* **Streak Shame Spirals:** Rigorous, unbending streak counters frequently cause ADHD individuals to abandon productivity systems entirely after a single missed day.

---

## 3. Core Functional Requirements (MVP / Phase 1)

### 3.1 Instant Start Pomodoro Engine
* **One-Tap Initiation:** 
  * Launching the app opens directly to the timer interface.
  * Starting a session must require no more than **one tap** (`[Start Focus]`).
* **Timer States:**
  * `Idle`: Clear display of focus time (default: 25:00), primary "Start" CTA, and quick-setting icons.
  * `Running Focus`: Minimalist countdown, subtle pulsing or progress arc, pause button, and reset/cancel option.
  * `Paused Focus`: Indicator of paused state, resume CTA, and pause duration accumulator.
  * `Focus Completed`: Audio chime/beep and immediate prompt for productivity reflection.
* **Controls & Session Handling:**
  * Ability to pause and resume.
  * Background pause logging (number of pauses and cumulative pause duration recorded for metrics).
  * Wake Lock: Option to keep screen on while timer is actively running.

### 3.2 Post-Focus Reflection & Rating
* **Productivity Rating Dialog:**
  * Triggered automatically upon focus timer completion.
  * Scale: **1 to 5 Stars / Numeric Scale** measuring perceived focus quality:
    * `1` - Heavily distracted / Struggled to focus
    * `2` - Low focus / Frequent mind-wandering
    * `3` - Moderate focus / Acceptable progress
    * `4` - Solid focus / Good deep work
    * `5` - Flow state / Maximum deep work
  * Frictionless input: Tapping a score automatically records and transitions directly to the Rest Period screen. Optional skip/auto-advance timer (e.g., 10 seconds).

### 3.3 Rest Period & Anti-Brainrot System
* **Rest Period Initiation:**
  * Default rest duration: 5 minutes (configurable).
  * Displays distinct, calming visual theme (e.g., cool green/blue palette contrasting with focus orange/red).
* **Rest Affirmations & Suggestions (Anti-Brainrot):**
  * Displays rotating suggestions to replace digital dopamine loops:
    * *"Step away from the screen."*
    * *"Drink a glass of water."*
    * *"Do 10 deep breaths or quick stretches."*
    * *"Walk around the room."*
    * *"Read a page of a physical book."*
  * Explicit warnings against passive video scrolling (Instagram Reels, TikTok, YouTube Shorts).
* **Rest Completion Alert:**
  * Prominent, urgent audio alert / beep prompting the user to transition back to focus.
  * Persistent high-priority reminder until acknowledged.
* **Rest Quality Rating:**
  * Scale: **1 to 5 Stars / Rating** evaluating break restorative quality:
    * `1` - Brainrot / Doomscrolling (drained mental energy)
    * `2` - Screen-based distractions (reading news, checking social)
    * `3` - Passive rest (sitting idly, snacking)
    * `4` - Restorative physical rest (stretching, walking, tidying)
    * `5` - Deep rest & recharge (breathwork, hydration, disconnected from technology)

### 3.4 Notifications, Audio & Alerts
* **Sound Alerts:**
  * Crisp, noticeable audio beeps/chimes for:
    * Focus session end (rewarding, distinct chime).
    * Rest period end (urgent, clear "back-to-work" chime).
  * Custom volume override and silence toggle.
* **Haptics:**
  * Tactile haptic feedback on start, pause, completion, and rating taps.
* **System Notifications:**
  * Foreground service / background notification with live remaining time.
  * Actionable notifications on lockscreen: `[Pause]`, `[Start Rest]`, `[Start Next Pomodoro]`.
  * High-priority alarms ensuring alerts fire reliably even when the device is locked or in Doze mode (Android exact alarm permissions).

### 3.5 Preferences & Configuration
* **Durations:**
  * Focus duration: Adjustable (e.g., 10m, 15m, 25m, 45m, 50m, 60m; custom stepper).
  * Short break duration: Adjustable (e.g., 3m, 5m, 10m).
  * Long break duration: Adjustable (e.g., 15m, 20m, 30m).
  * Long break frequency: Trigger after $N$ completed focus sessions (default: 4).
* **Automation Options:**
  * Auto-start breaks after rating (Toggle: Default ON).
  * Auto-start next focus session after rest rating (Toggle: Default OFF, requiring deliberate user commitment).
* **Sound & Alerts Settings:**
  * Audio alert type selection (Beep, Digital chime, Bell, Gong, Zen bowl).
  * Vibration toggle.
* **Optional Streaks Setting:**
  * **Streak Feature Toggle (ON/OFF):** Can be completely disabled in settings.
  * When enabled: Tracks daily consecutive focus goal achievements.
  * When disabled: Streak badges, fire counters, and daily warnings are hidden from the UI to avoid shame-based burnout.

### 3.6 Metrics, Analytics & Data Storage
* **Local Data Persistence (Offline-First):**
  * Stored on-device (e.g., Isar, Drift, or Hive SQLite).
* **Captured Data Points per Session:**
  * `sessionId`: UUID
  * `sessionType`: Focus vs. Short Break vs. Long Break
  * `targetDurationSeconds`: Int
  * `actualDurationSeconds`: Int
  * `startedAt`: Timestamp
  * `completedAt`: Timestamp
  * `isCompleted`: Boolean (completed vs. aborted early)
  * `pauseCount`: Int
  * `totalPauseDurationSeconds`: Int
  * `productivityRating`: Int? (1–5, for focus sessions)
  * `restQualityRating`: Int? (1–5, for break sessions)
* **User Insights & Dashboard:**
  * Daily / Weekly / Monthly summary:
    * Total deep work focus hours.
    * Average focus productivity rating (1–5 trendline).
    * Average break quality rating (Anti-Brainrot score).
    * Total sessions completed vs. aborted.
    * Correlation insight (e.g., *"Sessions followed by 4+ star breaks showed 25% higher productivity"*).

---

## 4. Non-Functional Requirements

| Metric | Target Requirement | Rationale |
|---|---|---|
| **Cold Startup Time** | $< 1.2\text{ seconds}$ | Immediate access is vital for users with short attention spans or impulse blocks. |
| **Input Responsiveness** | $< 16\text{ ms}$ (60 FPS minimum) | UI must feel tactile, snappy, and lightweight. |
| **Battery Consumption** | $< 1.5\%$ battery drain per 2h session | Timers must rely on system alarm schedulers, not active waking CPU loops. |
| **Reliability** | Exact alarm delivery even under Android Doze mode and iOS background state. | A missed break or focus alarm breaks the user's trust in the timer system. |
| **Data Privacy** | 100% offline-first local storage by default. | User productivity metrics should remain private; no forced account creation. |

---

## 5. Monetization Strategy (Freemium Model)

To build a viable, scalable commercial product, Focusmaxxing will employ a freemium model with clear tier boundaries.

### 5.1 Free Tier (Core Experience)
* Full Pomodoro focus & rest timers with default sound options.
* 1-Tap quick start.
* Post-focus and post-rest 1–5 ratings.
* Break hygiene suggestions.
* Streak counter (toggleable).
* 7-day rolling historical metrics and basic session totals.

### 5.2 Focusmaxxing Pro / Subscription (Premium Tier)
* **Pricing Model:** Monthly subscription ($3.99/mo), Annual subscription with discount ($29.99/yr), or Lifetime Access ($59.99).
* **Premium Features:**
  1. **Advanced Analytics & Insights Engine:**
     - Unlimited historical data and trend exports (CSV/JSON).
     - Peak productivity hours heatmap.
     - Correlation analysis: Impact of break quality on subsequent focus scores.
  2. **Anti-Brainrot App Shield (Android Accessibility / UsageStats API):**
     - Automatically blocks or creates high-friction interlocks for blacklisted apps (Instagram, TikTok, Twitter/X, Reddit) during both Focus *and* Rest periods.
  3. **Custom Soundscapes & Binaural Beats:**
     - Built-in ambient audio: Brown noise, white noise, rain, lofi beats, 40Hz gamma binaural tones for focus.
  4. **Home Screen & Lock Screen Widgets:**
     - Quick start 1-tap widgets, live countdown widget, today's focus score dial.
  5. **Cloud Sync & Cross-Device Backup:**
     - Secure, encrypted cloud backup across Android and iOS devices.
  6. **Custom Themes & App Icons:**
     - AMOLED True Black, Synthwave, Cyberpunk, Forest, and custom minimalist styling.

---

## 6. Technical Architecture & Technology Stack

* **Framework:** Flutter (Dart 3+) for cross-platform Android and iOS compilation.
* **Architecture Pattern:** Clean Architecture with Feature-First structure (Presentation, Domain, Data layers).
* **State Management:** Riverpod (or BLoC) for predictable, testable reactive state.
* **Local Database:** Isar Database or Drift (SQLite) for ultra-fast, structured querying of session metrics.
* **Background Processing & Alarms:**
  * `flutter_local_notifications` + `android_alarm_manager_plus` / system alarm APIs for exact timing.
  * Audio playback via `audioplayers` or `just_audio`.
* **Platform Channels:**
  * Android Foreground Service for persistent notification and timer countdown.
  * Android UsageStats / Accessibility services (for future Pro app-blocking feature).

---

## 7. Delivery Roadmap

```
+-------------------------------------------------------------------------+
| Phase 1: MVP Core (Frictionless Timer & Break System)                   |
| - 1-Tap Focus Start UI                                                  |
| - Audio chime alerts (end of focus, end of rest)                        |
| - 1-5 Productivity & Rest Quality rating dialogs                        |
| - Basic timer duration & sound configuration                            |
| - Optional streak tracker (with disable toggle)                         |
| - Local storage for session metrics & basic history                     |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
| Phase 2: Analytics & Enhancements                                       |
| - Dashboard charts (focus time, break quality score, daily trends)      |
| - Background service & actionable lockscreen notifications               |
| - Expanded anti-brainrot guided exercises & break suggestions           |
| - Custom alarm tones and sound library                                  |
+-------------------------------------------------------------------------+
                                    |
                                    v
+-------------------------------------------------------------------------+
| Phase 3: Monetization & Pro Feature Suite                               |
| - Paywall & In-App Purchase integration (RevenueCat)                    |
| - Ambient soundscapes (Binaural beats, brown noise)                     |
| - Android app blocker / distraction shield integration                  |
| - Lockscreen / homescreen interactive widgets                           |
+-------------------------------------------------------------------------+
```
