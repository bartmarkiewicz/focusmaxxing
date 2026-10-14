# Focusmaxxing - Product Requirements Document (PRD)

**Document Version:** 2.1.0  
**Status:** Approved Specification  
**Target Platforms:** Android (Primary), iOS (Cross-platform)  

---

## 1. Executive Summary & Vision

**Focusmaxxing** is a fast, minimal, distraction-free productivity app designed to help users—particularly those managing ADHD, executive dysfunction, or heavy digital distractions—get straight into deep work without friction and protect them from falling into "brainrot" traps during rest periods.

### Core Philosophy
1. **Zero Cognitive Friction:** Instant app launch directly into the timer. Minimum clicks to start a session (launch -> tap Start).
2. **Anti-Brainrot Break Hygiene:** Rest periods actively encourage restorative breaks (reading, walking, breathing, hydrating) over high-stimulus digital dopamine loops (Instagram Reels, TikTok, YouTube Shorts).
3. **Compassionate Productivity (ADHD-Friendly):** The app stays simple and low-pressure. Streaks are strictly optional and can be toggled off completely to prevent guilt spirals.
4. **Actionable Reflection:** Quick 1-tap ratings (1–5) after focus sessions and rest periods to help users observe patterns in their focus and downtime.
5. **Session Intelligence:** Captures session metrics, pause habits, and ratings locally for personal insight.
6. **100% Account-Free & Private:** Zero logins, zero email requests, and zero telemetry. All session data resides strictly on the user's device with offline data export.
7. **Fair, User-First Commercial Model:** Freemium app with a single **One-Time Lifetime Pro Unlock** via native platform billing (no recurring subscriptions, no third-party revenue middlemen).

---

## 2. Navigation & User Experience (UX) Architecture

### 2.1 Screen Hierarchy: 3-Tab Bottom Navigation Bar
* **Tab 1: Timer (Default Landing Screen):**
  * Opens immediately upon app launch.
  * Displays single configured focus duration, prominent Start button, and optional ambient sound toggle.
  * Strictly single duration shown on screen to eliminate decision fatigue; duration adjustments are made in Settings.
* **Tab 2: Insights:**
  * Daily Summary Card (today's total focus hours/minutes).
  * Average Productivity Score (1–5 focus rating average).
  * Anti-Brainrot Score (average rest quality rating showing restorative vs. brainrot breaks).
  * Chronological session history log for the rolling 7-day period.
* **Tab 3: Settings:**
  * Durations configuration (Focus, Short Break, Long Break, Long Break Interval).
  * Auto-advance toggles (`Auto-start Breaks`, `Auto-start Work`).
  * Streaks configuration (Master ON/OFF toggle, daily target, weekend/rest-day exemptions).
  * Sound and alert preferences (alert tones, vibration, volume).
  * Data management (Export to CSV/JSON, clear history).
  * One-Time Lifetime Pro Unlock status and purchase action.

### 2.2 First-Time User Experience (Zero Onboarding)
* **Zero Onboarding Screens:** No tutorial carousels or setup wizards. The user lands directly on the Timer on their first launch.
* **Contextual Permissions:** Notification and exact alarm permissions are requested contextually only when the user taps "Start" for the first time, explaining clearly why alarms are required.

---

## 3. Core Functional Requirements

### 3.1 Instant-Start Pomodoro Timer
* **Minimum-Click Launch:**
  * Opening the app immediately presents the Timer screen.
  * Tapping **Start** begins the focus session with zero intermediate steps.
* **Timer States:**
  * **Idle:** Clean countdown display showing configured focus duration (default: 25:00), primary Start button, and ambient audio toggle icon.
  * **Running (Focus):** Distraction-free countdown, Pause button, and Reset/Cancel button.
  * **Paused:** Displays paused state, tracks individual pause events and cumulative paused time.
  * **Completed:** Triggers completion chime/beep and immediately reveals the 1-Tap Quick Rating Bar.
* **Lifecycle & Crash Recovery (Wall-Clock Target Sync):**
  * The timer calculates progress against an absolute completion timestamp (`targetEndTime = now + duration`).
  * If the app is minimized, closed, killed by the operating system, or if the device restarts, reopening the app seamlessly calculates and displays the exact remaining time or the completion state.
* **In-Session Audio & Soundscapes:**
  * Silent by default during active focus.
  * Optional ambient soundscape toggle directly on the timer screen (e.g., calming brown noise, rain, or lofi audio).

### 3.2 Post-Focus Productivity Reflection
* **1-Tap Quick Rating Bar:**
  * Appears immediately upon timer completion (scale 1 to 5):
    * `1` - Very low focus / heavily distracted
    * `2` - Low focus / struggled to maintain momentum
    * `3` - Moderate focus / acceptable output
    * `4` - High focus / solid deep work
    * `5` - Peak flow state / maximum output
  * **Interaction:** A single tap on any number instantly logs the rating and advances to the rest period (zero extra "Submit" button required). Includes an optional skip button.

### 3.3 Rest Period & Anti-Brainrot System
* **Rest Period Initiation:**
  * Default duration: 5 minutes (configurable).
  * Calming visual transition indicating break mode.
* **Anti-Brainrot Restorative Action Cards:**
  * Displays randomized, actionable, screen-free restorative suggestions:
    * *"Step away from the screen."*
    * *"Take a 5-minute walk or do a quick stretch."*
    * *"Drink a glass of water or tea."*
    * *"Read a few pages of a physical book."*
* **Gentle Background Nudge:**
  * If the user sends the app to the background during a rest period, sends a gentle reminder notification nudging them to avoid passive doomscrolling on social media feeds.
* **Early Break Completion ("I'm Ready to Focus"):**
  * Users can tap a prominent button to end their rest period early if they feel recharged.
  * Logs the actual break duration taken, prompts for the 1–5 rest quality rating, and readies the next focus session.
* **End-of-Rest Urgency Alert:**
  * High-priority notification with a distinct, urgent chime urging the user that break time is over and it is time to return to work.
  * **60-Second Gentle Repeat:** If the alert is not acknowledged or the app is not opened within 60 seconds, plays a gentle follow-up reminder chime to prevent drifting into prolonged distraction.
* **Rest Quality Reflection:**
  * 1-tap rating evaluating break restorative value (1 to 5):
    * `1` - Brainrot doomscrolling (left feeling more depleted)
    * `2` - High-stimulus digital distraction (news, messaging, socials)
    * `3` - Passive rest (sitting idly, snacking)
    * `4` - Restorative physical break (walked, stretched, hydrated)
    * `5` - Deep restorative reset (fully unplugged, relaxed, refreshed)

### 3.4 Notifications, Audio & Alerts
* **Audio Alerts:**
  * Focus Completed: Distinct, rewarding completion chime/beep.
  * Rest Ended: Crisp, urgent chime urging the user to resume focus (with 60-second gentle repeat if unacknowledged).
  * Configurable volume and silent/vibrate toggles.
* **System Notifications:**
  * Exact alarm scheduling ensuring alerts fire reliably even when device is locked or in battery-saver/Doze mode.
  * Ongoing persistent notification with live remaining countdown during active sessions.

### 3.5 Configuration & Settings
* **Durations (Fully Customizable):**
  * Focus block length (default: 25m; adjustable).
  * Short rest duration (default: 5m; adjustable).
  * Long rest duration & frequency (e.g., 15–30m after every 4 focus blocks).
* **Transition Automation (User-Configurable):**
  * Toggle: `Auto-start Breaks` (ON/OFF).
  * Toggle: `Auto-start Work` (ON/OFF).
* **Optional Streaks Feature:**
  * **Master Toggle (ON/OFF):** Can be completely disabled. When disabled, all streak counters, fire icons, and daily reminders are hidden from the UI to avoid shame-based demotivation.
  * **Flexible Criteria:** When enabled, users configure their daily target (e.g., 1, 2, or 4 completed Pomodoros), with built-in optional weekend/rest-day exemptions so scheduled off-days never break the streak.
* **Pauses & Early Cancellations:**
  * If a session is canceled early: actual elapsed focus minutes are credited toward daily totals, pause counts and cumulative pause duration are logged, and the session is marked with an `Aborted` flag (no productivity rating requested).

### 3.6 Metrics & Usage Insights
* **Session Records (Stored Locally):**
  * Timestamp (start time, completion time).
  * Session type (Focus, Short Break, Long Break).
  * Target duration vs. actual elapsed duration.
  * Completion status (`Completed` vs. `Aborted`).
  * Number of pauses and cumulative pause duration.
  * Productivity rating (1–5) for focus sessions.
  * Rest quality rating (1–5) for break sessions.
* **Phase 1 Insights Dashboard:**
  * **Daily Summary Card:** Total focus hours/minutes completed today.
  * **Productivity Average:** Average focus rating (1–5) for the current day.
  * **Anti-Brainrot Score:** Average rest quality rating (1–5) highlighting restorative breaks vs. brainrot.
  * **Chronological Session Log:** Clean list of sessions for the rolling 7-day period.

---

## 4. Visual Aesthetic & Design System

* **Design Standard:** **Material 3 / Dynamic Theming**.
  * Adapts organically to the user's Android system colors and wallpaper palette.
  * Clean, minimal layout with generous whitespace to prevent cognitive overload.
  * Distinct semantic accenting to clearly delineate Focus Mode from Rest Mode.

---

## 5. Monetization Strategy: One-Time Lifetime Pro Unlock

Focusmaxxing implements a clean, transparent **One-Time Lifetime Pro Unlock** directly via native platform billing (Google Play Billing on Android in Phase 1).

### 5.1 Free Tier (Generous & Fully Functional)
* Unlimited Pomodoro focus and rest sessions.
* 1-Tap quick start and full timer controls.
* Complete 1–5 productivity and break quality ratings.
* Anti-brainrot restorative break cards and gentle background nudges.
* Optional streak tracker with rest-day exemptions.
* Rolling 7-day metrics, daily summary card, and Anti-Brainrot correlation score.
* Default audio alerts and system theme matching.

### 5.2 Lifetime Pro Unlock (One-Time Purchase)
* **Purchase Type:** Single non-consumable in-app purchase (e.g., $9.99 or equivalent local pricing).
* **Pro Features:**
  1. **Unlimited Historical Analytics & Deep Trends:** Lifetime history, weekly/monthly trendlines, correlation insights between rest habits and focus scores, and CSV data export.
  2. **Custom Audio & Ambient Soundscapes:** Built-in ambient background noise (brown noise, white noise, rain, lofi focus beats) and custom alarm chime sets.
  3. **Home Screen & Lock Screen Widgets:** 1-tap quick start widgets and live glanceable progress dials.
  4. **Pro Supporter Badge & Themes:** Custom aesthetic variants and exclusive app icons.

### 5.3 Billing Infrastructure
* **Direct Native Billing:** Google Play Billing integration on Android in Phase 1 (and StoreKit for iOS later).
* **Zero Third-Party Dependency:** No RevenueCat, no external auth servers, no subscription tracking overhead.

---

## 6. Implementation Phases

```
+-----------------------------------------------------------------------------------+
| Phase 1: MVP Core + Native Billing Integration                                    |
| - 3-Tab navigation (Timer, Insights, Settings) with Material 3 dynamic theming    |
| - Wall-clock synced timer with instant 1-tap start                                |
| - Audio alerts with 60-second gentle repeat for break completion                  |
| - 1-Tap Quick Rating Bar (1-5 for focus, 1-5 for rest)                            |
| - Anti-brainrot restorative cards & background nudges                             |
| - Early rest completion ('I'm Ready to Focus')                                    |
| - Configurable durations, pause/aborted session logging, and auto-advance toggles |
| - Optional streak system with rest-day exemptions and master toggle               |
| - Daily Summary + 7-day session log & Anti-Brainrot score                         |
| - Local offline storage with manual CSV/JSON export                               |
| - Native Google Play Billing integration for One-Time Lifetime Pro unlock         |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| Phase 2: Pro Features & Polish                                                    |
| - Unlimited analytics dashboard & trend visualizations                            |
| - Ambient audio soundscapes (brown noise, lofi, rain) during focus                |
| - Home screen / lock screen widgets                                               |
| - iOS StoreKit integration & polish                                               |
+-----------------------------------------------------------------------------------+
```
