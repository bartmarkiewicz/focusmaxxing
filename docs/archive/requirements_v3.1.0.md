# Focusmaxxing - Product Requirements Document (PRD)

> [!WARNING]
> **DEPRECATED & ARCHIVED DOCUMENTATION (v3.1.0)**  
> This specification represents the historical MVP 1.0 product baseline and is **superseded** by the canonical, modular product specifications located in [`docs/product/`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/product).  
> For current production specifications, see [`docs/product/overview.md`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/product/overview.md).

**Document Version:** 3.1.0 (Archived)  
**Status:** Superseded by [`docs/product/`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/product)  
**Target Platforms:** Android (Primary, Phase 1), iOS (Phase 2 via Screen Time API)  
**Positioning:** The Anti-Brainrot App Blocker & ADHD "Lock-In" Engine  
**Technical Companion:** See [`docs/archive/technical_scoping_v1.1.0.md`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/archive/technical_scoping_v1.1.0.md) for historical engineering architecture.

---

## 1. Executive Summary & Vision

**Focusmaxxing** is a fast, high-conviction productivity app that fuses **ADHD task initiation (micro-commitments)** with **hard OS-level distraction blocking (The Brainrot Shield)**.

Instead of relying on fragile willpower against algorithmically optimized social media feeds, Focusmaxxing physically intercepts distracting apps during focus blocks and rest periods, replacing compulsive doomscrolling with strict focus enforcement, cognitive anchoring, and zero-friction break protection.

### 1.1 Core Product Principles
1. **Active Shielding Over Passive Nagging:** Real distraction defense requires active OS-level intervention. When locked in, blocked apps are physically unusable.
2. **Zero Survey Slop (Anti-Fatigue):** No 1–5 bureaucratic ratings. Only a 1-sentence task initiation before starting, and a 1-tap celebratory binary check-in when done (`[ Locked In 🚀 ]` vs `[ Derailed 💀 ]`).
3. **Restorative Break Guard:** Prevents 5-minute Pomodoro breaks from turning into 45-minute doomscroll sessions by keeping blocked apps locked through rest periods until the user explicitly locks in on the next focus session.
4. **Uncluttered 3-Tab Hierarchy:** Instant launch directly into the Timer. Secondary tools (like the task backlog) stay tucked away so they never distract from the immediate focus task.
5. **Fair, One-Time Commercial Model:** Free forever tier (up to 2 blocked apps) + single **One-Time Lifetime Pro Unlock** ($9.99 flat, one-and-done). Zero subscriptions, zero microtransactions, and 100% offline privacy.

---

## 2. Screen Hierarchy & Navigation Architecture

### 2.1 3-Tab Bottom Navigation
* **Tab 1: Timer (Default Landing Screen):**
  * Opens immediately upon app launch.
  * Prominent countdown dial and active 1-sentence task anchor.
  * Fast 1-tap duration preset pills (`15m`, `25m`, `45m`, `60m`, `Custom`).
  * Sacred minimalist UI: Zero ambient audio controls or settings clutter on the main screen (audio is managed in Settings).
  * State transitions: Start button (Idle) -> Pause button only (Running) -> Resume and **Hold-to-Cancel (5-second hold)** button (Paused, two-step barrier).
  * **Header Quick-Action:** Subtle icon opening the **Backlog Sheet** (keeps task planning completely out of the way until requested).
* **Tab 2: Shield (Brainrot App Blocker):**
  * Permission status banner (Contextual prompt for Usage Access & Draw-Over-Apps).
  * **Curated Quick-Shield Presets:** 1-tap toggle cards for detected social feeds (Instagram, TikTok, Twitter/X, Reddit, YouTube Shorts, Mobile Games).
  * Searchable list of all installed user applications (system apps excluded by default).
  * Free tier limit indicator (2 apps selected) with Lifetime Pro upgrade prompt for unlimited shielding.
* **Tab 3: Insights & Settings:**
  * Daily Summary (total locked-in focus minutes today, sessions completed).
  * Current Streak Counter (master toggle on/off for guilt prevention; optional "Include Weekends" toggle—OFF by default so weekends are exempt).
  * Chronological session history log (Timestamp, 1-sentence goal, duration, `[ Locked In 🚀 ]`, `[ Derailed 💀 ]`, or `[ Cancelled ]`).
  * Settings section: Custom timer intervals, ambient audio soundscape selection, daily focus reminder notifications (OFF by default, configurable time), alert sounds/vibrations, and Lifetime Pro restore/purchase.

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
  2. Input field (max 60 characters) with a 1-tap `[ ⚡ Deep Work ]` quick-flow chip for immediate flow, plus recent-goal chips and Backlog task pickers.
  3. Tapping **"Lock In"** begins the timer immediately.
* **Persistent Anchor:**
  * The goal is displayed prominently beneath the countdown clock.
  * The goal is pinned in the persistent Android notification drawer.
* **Session Completion:**
  * On timer completion, audio chime sounds and a 1-tap dialog appears (clock paused until acknowledged):
    * `[ Locked In 🚀 ]` (Counts toward streak & completed focus total)
    * `[ Derailed 💀 ]` (Logs full session as distracted/derailed)

### 3.2 The Brainrot Shield & Hard Lock Interception
* **Hard Lock Overlay:**
  * When a blocked app moves to the foreground during a session:
    * Focusmaxxing immediately displays a full-screen, high-contrast overlay.
    * Shows the user's active goal: *"You are locked in on: [Goal]"*.
    * Displays the remaining focus time countdown.
    * **Zero Emergency Bypass:** No "snooze" or "emergency pass" button. The overlay provides only one action: `[ Return to Focusmaxxing ]`, which immediately minimizes the blocked app and returns the user to the active timer.
* **In-App Cancellation Strictness:**
  * Two-step friction barrier: While running, only Pause is visible. Tapping Pause reveals Resume and the Cancel button.
  * The Cancel button requires a **5-Second Continuous Press-and-Hold** to terminate an active session early.
  * Terminating early releases the app block and logs the session as `CANCELLED` in local metrics (differentiated from full sessions marked `DERAILED 💀`).

### 3.3 The Restorative Break Guard
* When a focus session completes, the app transitions into the configured rest period (default: 5 minutes).
* **Break Shielding:** The Brainrot Shield **remains actively enforced** during the break period. Social media and doomscroll feeds stay blocked to ensure rest is genuinely restorative (stretching, water, screen break).
* **The Anti-Doomscroll Transition:**
  * When the 5-minute break timer reaches `00:00`, **blocked apps remain locked**.
  * The app plays a completion alert chime.
  * Feeds remain blocked until the user returns to Focusmaxxing and taps `[ Lock In ]` for the next focus session, closing the "wait out the clock to scroll" loophole.

### 3.4 Ambient Audio Soundscapes (Configured in Settings)
* Managed exclusively within Tab 3 Settings to preserve the Timer screen as a sacred, distraction-free space:
  * High-density Brown Noise (muffles background household noise).
  * 40Hz Gamma Isochronic / Binaural Tones (cognitive focus stimulation).
  * Rain on Canvas.
* **Audio Mixing:** Soundscapes mix seamlessly with other active audio streams (e.g., allows brown noise to play simultaneously over a user's Spotify playlist without interrupting playback). Continues playing when the screen is locked.

---

## 4. Monetization Strategy: Free Tier + Single One-Time Purchase

Focusmaxxing eliminates recurring subscriptions and predatory microtransactions in favor of an ethical, high-conversion commercial model:

### 4.1 Tier Breakdown

| Tier | Price | Features Included |
| :--- | :--- | :--- |
| **Free Tier** | **$0** (Free Forever) | • Unlimited Pomodoro & custom focus timers<br>• 1-Sentence Task Initiation & persistent notification anchor<br>• **Brainrot Shield for up to 2 apps** (e.g., Instagram & TikTok)<br>• Zero-Override Hard Lock overlay<br>• Restorative Break Guard (blocks apps during rest periods)<br>• 5-Second Hold-to-Cancel safety valve<br>• Local 7-Day Session History & Streaks<br>• Unobtrusive Backlog scratchpad<br>• Zero ads, zero telemetry, 100% offline |
| **Lifetime Pro Unlock** | **$9.99 flat** (One-Time Purchase) | • **Unlimited Blocked Apps** (all social feeds, games, and custom apps)<br>• **All Neurodivergent Ambient Audio Loops** (Brown noise, 40Hz, Rain)<br>• **Scheduled Auto-Shield** (auto-lock designated apps during set work hours)<br>• Home Screen & Lock Screen quick-launch widgets<br>• Family Library support & permanent ownership |

---

## 5. User Stories & Acceptance Criteria

### US-1: Instant Start with Goal Anchor
* *As a user with executive dysfunction,* I want to start a session with a single sentence commitment so that I avoid task initiation paralysis.
* **Acceptance Criteria:**
  * Tapping Start prompts for a goal (defaulting to previous or empty).
  * Starting begins the timer immediately with goal pinned under the timer and in notifications.

### US-2: Hard App Interception
* *As an easily distracted user,* I want my social apps to be blocked when I'm working so that I cannot unconsciously doomscroll.
* **Acceptance Criteria:**
  * Launching a blocked package displays the full-screen overlay within 500ms.
  * Tapping `[ Return to Focusmaxxing ]` navigates back to Focusmaxxing.
  * No bypass or snooze option is visible on the overlay.

### US-3: Protected Rest Break
* *As a user who falls into break traps,* I want social media to stay blocked during my breaks so that I actually rest.
* **Acceptance Criteria:**
  * Break mode keeps shielded apps blocked.
  * Expired break keeps shielded apps blocked until the user starts the next focus block.

### US-4: Anti-Impulse Cancellation
* *As an impulsive user,* I do not want to be able to accidentally or impulsively cancel a session to access social media.
* **Acceptance Criteria:**
  * A tap on Cancel does not stop the session; it shows a prompt to hold for 5 seconds.
  * Holding for 5 full seconds cancels the session and marks it as `Derailed 💀`.
