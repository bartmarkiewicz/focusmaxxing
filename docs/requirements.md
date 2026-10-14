# Focusmaxxing - Product Requirements Document (PRD)

**Document Version:** 3.1.0  
**Status:** Approved Specification (Post-Grilling Finalization)  
**Target Platforms:** Android (Primary, Phase 1), iOS (Phase 2 via Screen Time API)  
**Architecture:** Flutter with `provider` + `ChangeNotifier` & SQLite (`sqflite`)  
**Positioning:** The Anti-Brainrot App Blocker & ADHD "Lock-In" Engine.

---

## 1. Executive Summary & Vision

**Focusmaxxing** is a fast, high-conviction productivity app that fuses **ADHD task initiation (micro-commitments)** with **hard OS-level distraction blocking (The Brainrot Shield)**.

Instead of relying on fragile willpower against algorithmically optimized social media feeds, Focusmaxxing physically intercepts distracting apps during focus blocks and rest periods, replacing compulsive doomscrolling with strict focus enforcement, gentle cognitive anchoring, and zero-friction break protection.

### 1.1 Core Principles
1. **Active Shielding Over Passive Nagging:** Real distraction defense requires OS-level app interception. When locked in, blocked apps are physically unusable.
2. **Zero Survey Slop (Anti-Fatigue):** No 1–5 bureaucratic ratings. Only a 1-sentence task initiation before starting, and a 1-tap celebratory binary check-in when done (`[ Locked In 🚀 ]` vs `[ Derailed 💀 ]`).
3. **Restorative Break Guard:** Prevents the "5-minute break turning into a 45-minute TikTok vortex" by keeping blocked apps locked through rest periods until the user explicitly locks in on the next focus session.
4. **Uncluttered 3-Tab Hierarchy:** Instant launch directly into the Timer. Secondary tools (like the task backlog) stay tucked away so they never distract from the immediate focus task.
5. **Fair, One-Time Commercial Model:** Free forever tier (up to 2 blocked apps) + single **One-Time Lifetime Pro Unlock** ($9.99 flat, one-and-done). Zero subscriptions, zero microtransactions, and 100% offline privacy.

---

## 2. Screen Hierarchy & Navigation Architecture

### 2.1 3-Tab Bottom Navigation
* **Tab 1: Timer (Default Landing Screen):**
  * Opens immediately upon app launch.
  * Prominent countdown dial and active 1-sentence task anchor.
  * Start button / Pause button / **Hold-to-Cancel (5-second hold)** button.
  * Ambient soundscape toggle icon (Brown noise, 40Hz, Rain).
  * **Header Quick-Action:** Subtle icon opening the **Backlog Sheet** (keeps task planning completely out of the way until requested).
* **Tab 2: Shield (Brainrot App Blocker):**
  * Permission status banner (Contextual prompt for Usage Access & Draw-Over-Apps).
  * **Curated Quick-Shield Presets:** 1-tap toggle cards for detected social feeds (Instagram, TikTok, Twitter/X, Reddit, YouTube Shorts, Mobile Games).
  * Searchable list of all installed user applications (system apps excluded by default).
  * Free tier limit indicator (2 apps selected) with Lifetime Pro upgrade prompt for unlimited shielding.
* **Tab 3: Insights & Settings:**
  * Daily Summary (total locked-in focus minutes today, sessions completed).
  * Current Streak Counter (toggleable on/off for ADHD guilt prevention).
  * Chronological session history log (Timestamp, 1-sentence goal, duration, `[ Locked In 🚀 ]` vs `[ Derailed 💀 ]`).
  * Settings section: Custom timer intervals (Focus, Short Break, Long Break), alert sounds/vibrations, and Lifetime Pro restore/purchase.

### 2.2 Unobtrusive Task Backlog (Swipe-Up Sheet / Header Modal)
* Accessible on-demand from the Timer screen header icon.
* A clean, distraction-free scratchpad for queuing upcoming tasks.
* Tapping any task instantly populates the 1-Sentence Goal field on the Timer screen and dismisses the sheet.
* Completed tasks are checked off automatically when sessions finish.

---

## 3. Core Functional Requirements

### 3.1 ADHD Task Initiation: "The One-Sentence Lock-In"
* **Initiation Flow:**
  1. Tapping **Start** opens a focused micro-prompt: *"What ONE thing are you locking in on?"*
  2. Input field (max 60 characters) with 1-tap chips to reuse the last 3 recent goals or pull from the Backlog.
  3. Tapping **"Lock In"** begins the timer immediately.
* **Persistent Anchor:**
  * The goal is displayed prominently beneath the countdown clock.
  * The goal is pinned in the persistent Android notification drawer.
* **Session Completion:**
  * No complex surveys. On timer completion, audio chime sounds and a 1-tap dialog appears:
    * `[ Locked In 🚀 ]` (Counts toward streak & completed focus total)
    * `[ Derailed 💀 ]` (Logs session as incomplete/derailed)

### 3.2 The Brainrot Shield & Hard Lock Interception
* **Detection Engine:**
  * Android `UsageStatsManager` polling foreground package events via a lightweight background service (~500ms response time).
  * 100% compliant with Google Play Store policies (no prohibited Accessibility Service abuse or invasive Device Admin requirements).
* **Hard Lock Overlay (`SYSTEM_ALERT_WINDOW`):**
  * When a blocked app moves to the foreground during a session:
    * Focusmaxxing immediately displays a full-screen, high-contrast overlay.
    * Shows the user's active goal: *"You are locked in on: [Goal]"*.
    * Displays the remaining focus time countdown.
    * **Zero Emergency Bypass:** No "snooze" or "emergency pass" button. The overlay provides only one action: `[ Return to Focusmaxxing ]`, which immediately minimizes the blocked app and returns the user to the active timer.
* **In-App Cancellation Strictness:**
  * To prevent impulsive dopamine quits, the Cancel button inside Focusmaxxing requires a **5-Second Continuous Press-and-Hold** to terminate an active session early.
  * Terminating early releases the app block but marks the session as `Derailed 💀` in local logs.

### 3.3 The Restorative Break Guard
* When a focus session completes, the app transitions into the configured rest period (default: 5 minutes).
* **Break Shielding:** The Brainrot Shield **remains actively enforced** during the break period. Social media and doomscroll feeds stay blocked to ensure rest is genuinely restorative (stretching, water, screen break).
* **The Anti-Doomscroll Transition:**
  * When the 5-minute break timer reaches `00:00`, **blocked apps remain locked**.
  * The app plays a completion alert chime.
  * Feeds remain blocked until the user returns to Focusmaxxing and taps `[ Lock In ]` for the next focus session, closing the "wait out the clock to scroll" loophole.

### 3.4 Ambient Audio Soundscapes
* Built-in, high-efficiency, offline audio loops:
  * High-density Brown Noise (muffles background household noise).
  * 40Hz Gamma Isochronic / Binaural Tones (cognitive focus stimulation).
  * Rain on Canvas.
* **Audio Mixing:** Soundscapes mix seamlessly with other active audio streams (e.g. allows brown noise to play simultaneously over a user's Spotify playlist without interrupting playback). Continues playing when the screen is locked.

---

## 4. Monetization & Commercial Architecture

Focusmaxxing eliminates recurring subscriptions and microtransactions in favor of an ethical, high-conversion commercial model:

### 4.1 Tier Breakdown

| Tier | Price | Features Included |
| :--- | :--- | :--- |
| **Free Tier** | **$0** (Free Forever) | • Unlimited Pomodoro & custom focus timers<br>• 1-Sentence Task Initiation & persistent notification anchor<br>• **Brainrot Shield for up to 2 apps** (e.g., Instagram & TikTok)<br>• Zero-Override Hard Lock overlay<br>• Restorative Break Guard (blocks apps during rest periods)<br>• 5-Second Hold-to-Cancel safety valve<br>• Local 7-Day Session History & Streaks<br>• Unobtrusive Backlog scratchpad<br>• Zero ads, zero telemetry, 100% offline |
| **Lifetime Pro Unlock** | **$9.99 flat** (One-Time Purchase) | • **Unlimited Blocked Apps** (all social feeds, games, and custom apps)<br>• **All Neurodivergent Ambient Audio Loops** (Brown noise, 40Hz, Rain)<br>• **Scheduled Auto-Shield** (auto-lock designated apps during set work hours)<br>• Home Screen & Lock Screen quick-launch widgets<br>• Family Library support & permanent ownership |

### 4.2 Billing Implementation
* Native platform billing via `in_app_purchase` for a single non-consumable product ID: `focusmaxxing_lifetime_pro`.
* Offline receipt verification and standard 1-tap "Restore Purchase" support.
* Zero third-party revenue tracking dependencies (no RevenueCat, no external auth servers).

---

## 5. Technical Architecture & Permissions (Android)

### 5.1 Tech Stack
* **Framework:** Flutter (Targeting Android SDK 34+ / Dart 3.x).
* **State Management:** `provider` with `ChangeNotifier` service controllers (`TimerController`, `ShieldController`, `TaskController`).
* **Database:** SQLite via `sqflite` for relational session logs, backlog items, and shield configurations.
* **Audio Engine:** `just_audio` / `audio_session` configured for background audio mixing.

### 5.2 Android Native Permissions & Services
1. **`PACKAGE_USAGE_STATS` (Usage Access):**
   * Contextual permission prompt leading directly to `Settings.ACTION_USAGE_ACCESS_SETTINGS`.
   * Checks foreground app events during active sessions.
2. **`SYSTEM_ALERT_WINDOW` (Draw Over Other Apps):**
   * Contextual prompt leading to `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`.
   * Launches the Hard Lock full-screen overlay instantly when a blocked package is detected.
3. **`FOREGROUND_SERVICE` & `POST_NOTIFICATIONS`:**
   * Keeps timer precision intact and displays persistent live countdown with the 1-sentence goal.
4. **Contextual Onboarding Flow:**
   * Zero upfront permission walls. Users land immediately on the Timer on first launch.
   * Permissions are contextually requested only when the user adds apps to the Shield tab or starts their first shielded focus block, accompanied by clear visual instructions.

---

## 6. Implementation Roadmap

```
+-----------------------------------------------------------------------------------+
| Milestone 1: Core Loop & ADHD Task Anchor (MVP)                                   |
| - Setup Flutter architecture with `provider` and SQLite (`sqflite`)               |
| - 3-Tab navigation skeleton + Header Backlog bottom sheet                         |
| - 1-Sentence Task Initiation dialog with recent goal chips                        |
| - Wall-clock accurate Pomodoro timer with persistent Android notification         |
| - 5-Second Hold-to-Cancel logic + Binary check-in [Locked In 🚀 / Derailed 💀]     |
| - Local session history database and daily streak tracking                        |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| Milestone 2: The Brainrot Shield Engine                                           |
| - Native Android Kotlin service: UsageStats listener + System Alert Window overlay|
| - Shield Tab: Curated presets (Instagram, TikTok, X, Reddit) + installed app picker|
| - Hard Lock Overlay with 0-override policy and 'Return to Focus' action           |
| - Restorative Break Guard: persistent app blocking through 5m rest periods        |
| - Lock enforcement until next session starts (anti-doomscroll transition)         |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| Milestone 3: Audio, Lifetime Pro Billing & Launch Polish                          |
| - Bundled offline audio loops (Brown noise, 40Hz) with audio mixing               |
| - Single One-Time Lifetime Pro Unlock ($9.99 non-consumable via `in_app_purchase`)|
| - Free tier 2-app cap vs. Pro unlimited app shielding                             |
| - High-contrast "Lock In" dark mode visual polish and release build verification  |
+-----------------------------------------------------------------------------------+
```
