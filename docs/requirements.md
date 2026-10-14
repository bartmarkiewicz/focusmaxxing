# Focusmaxxing - Product Requirements Document (PRD)

**Document Version:** 2.0.0  
**Status:** Approved Specification  
**Target Platforms:** Android (Primary), iOS (Cross-platform)  

---

## 1. Executive Summary & Vision

**Focusmaxxing** is a fast, minimal, distraction-free productivity app designed to help users—particularly those managing ADHD, executive dysfunction, or heavy digital distractions—get straight into deep work without friction and protect them from falling into "brainrot" traps during rest periods.

### Core Philosophy
1. **Zero Cognitive Friction:** Instant app startup. Minimum clicks to start a session (launch -> tap Start).
2. **Anti-Brainrot Break Hygiene:** Rest periods actively encourage restorative breaks (reading, walking, breathing, hydrating) over high-stimulus digital dopamine loops (Instagram Reels, TikTok, YouTube Shorts).
3. **Compassionate Productivity (ADHD-Friendly):** The app stays simple and low-pressure. Streaks are strictly optional and can be toggled off to prevent guilt spirals.
4. **Actionable Reflection:** Quick 1-tap ratings (1–5) after focus sessions and rest periods to help users observe patterns in their focus and downtime.
5. **Session Intelligence:** Captures session metrics, pause habits, and ratings locally for personal insight.
6. **Fair, User-First Commercial Model:** Freemium app with a single **One-Time Lifetime Pro Unlock** (no subscriptions, no third-party revenue middlemen).

---

## 2. Core Functional Requirements

### 2.1 Instant-Start Pomodoro Timer
* **Minimum-Click Launch:**
  * Opening the app immediately presents the timer screen.
  * Tapping **Start** begins the focus session with zero intermediate configuration required.
* **Timer Lifecycle & States:**
  * **Idle:** Shows current focus duration (default: 25 minutes) with a prominent Start button and access to settings.
  * **Running (Focus):** Clean, distraction-free countdown with Pause and Reset/Cancel actions.
  * **Paused:** Displays paused state; tracks individual pause events and cumulative pause time.
  * **Completed:** Triggers completion audio chime/beep and immediately reveals the 1-tap rating bar.
* **Keep Awake / Screen Control:**
  * Option to keep screen awake during an active session or allow standard screen sleep while background timers run accurately.

### 2.2 Post-Focus Productivity Reflection
* **1-Tap Quick Rating Bar:**
  * Immediately upon completing a focus block, a 1–5 visual rating bar appears:
    * `1` - Very low focus / heavily distracted
    * `2` - Low focus / struggled to maintain momentum
    * `3` - Moderate focus / acceptable output
    * `4` - High focus / solid deep work
    * `5` - Peak flow state / maximum output
  * **Interaction:** Single tap records the rating and immediately transitions into the rest phase without requiring an extra "Submit" button. Includes a quick skip option.

### 2.3 Rest Period & Anti-Brainrot System
* **Rest Period Initiation:**
  * Default duration: 5 minutes (configurable).
  * Calming visual transition indicating break mode.
* **Anti-Brainrot Restorative Cards & Gentle Nudges:**
  * Displays randomized, actionable, screen-free restorative suggestions:
    * *"Step away from the screen."*
    * *"Take a 5-minute walk or do a quick stretch."*
    * *"Drink a glass of water or tea."*
    * *"Read a few pages of a physical book."*
  * **Background Nudge:** If the app is sent to the background during rest, a gentle reminder notification nudges the user to avoid passive doomscrolling on social media.
* **End-of-Rest Urgency Alert:**
  * High-priority notification with a distinct, urgent chime urging the user that break time is over and it is time to return to work.
  * **Gentle Repeat:** If the alert is not acknowledged or the app is not opened within 60 seconds, plays a gentle follow-up reminder chime to prevent drifting into prolonged distraction.
* **Rest Quality Reflection:**
  * 1-tap rating evaluating break restorative value (1 to 5):
    * `1` - Brainrot doomscrolling (left feeling more depleted)
    * `2` - High-stimulus digital distraction (news, messaging, socials)
    * `3` - Passive rest (sitting idly, snacking)
    * `4` - Restorative physical break (walked, stretched, hydrated)
    * `5` - Deep restorative reset (fully unplugged, relaxed, refreshed)

### 2.4 Notifications, Audio & Alerts
* **Audio Alerts:**
  * Focus Completed: Distinct, rewarding chime/beep.
  * Rest Ended: Crisp, urgent sound urging the user to resume focus (with 60-second gentle repeat if unacknowledged).
  * Configurable volume and silent/vibrate toggles.
* **System Notifications:**
  * Exact alarm scheduling ensuring alerts fire reliably even when device is locked or in battery-saver/Doze mode.
  * Ongoing persistent notification with live remaining countdown during active sessions.

### 2.5 Configuration & Settings
* **Durations (Fully Customizable):**
  * Focus block length (default: 25m; adjustable).
  * Short rest duration (default: 5m; adjustable).
  * Long rest duration & frequency (e.g., 15–30m after every 4 focus blocks).
* **Transition Automation (User-Configurable):**
  * Toggle: `Auto-start Breaks` (ON/OFF).
  * Toggle: `Auto-start Work` (ON/OFF).
* **Optional Streaks Feature:**
  * **Master Toggle (ON/OFF):** Can be completely disabled. When disabled, all streak counters, fire icons, and daily reminders are hidden from the UI.
  * **Flexible Criteria:** When enabled, users configure their daily target (e.g., 1, 2, or 4 completed Pomodoros), with built-in optional weekend/rest-day exemptions so scheduled off-days never break the streak.
* **Pauses & Early Cancellations:**
  * If a session is canceled early: actual elapsed focus minutes are credited toward daily totals, pause counts and cumulative pause duration are logged, and the session is marked with an `Aborted` flag (no productivity rating requested).

### 2.6 Metrics & Usage Insights
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

## 3. Visual Aesthetic & Design System

* **Design Standard:** **Material 3 / Dynamic Theming**.
  * Adapts organically to the user's Android system colors and wallpaper palette.
  * Clean, minimal layout with generous whitespace to prevent cognitive overload.
  * Distinct semantic accenting to clearly delineate Focus Mode from Rest Mode.

---

## 4. Platform Capabilities Needed (Technical Requirements)

*(Specific packages to be evaluated during technical design)*

* **Exact Background Scheduling & Alarms:** Android Exact Alarms (`SCHEDULE_EXACT_ALARM`) and iOS local notification delivery to ensure zero dropped completion chimes.
* **Local Data Persistence:** Snappy on-device database for storing preferences, streaks, and session metrics offline.
* **Audio & Haptic Feedback:** High-priority sound playback (both foreground and background) and tactile haptic response.
* **Native In-App Billing:** Direct integration with Google Play Billing (and Apple StoreKit) for one-time purchases with zero third-party subscription backend.

---

## 5. Monetization Strategy: One-Time Lifetime Pro Unlock

Focusmaxxing rejects predatory subscriptions and third-party SaaS middle layers. It implements a clean, transparent **One-Time Lifetime Pro Unlock** directly via native platform billing.

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
| - Material 3 dynamic themed UI with instant 1-tap start                           |
| - Audio alerts with 60-second gentle repeat for break completion                  |
| - 1-Tap Quick Rating Bar (1-5 for focus, 1-5 for rest)                            |
| - Anti-brainrot restorative cards & background nudges                             |
| - Configurable durations, pause/aborted session logging, and auto-advance toggles |
| - Optional streak system with rest-day exemptions                                 |
| - Daily Summary + 7-day session log & Anti-Brainrot score                         |
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
