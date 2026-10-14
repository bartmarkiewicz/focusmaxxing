# Focusmaxxing - UI/UX Design System & Screen Blueprint

**Document Version:** 1.1.0  
**Status:** Approved Design Specification (Post-Grilling Finalization)  
**Design Philosophy:** Artisanal Digital Instrument (Tactile, Focused, Human-Centric)  
**Target Standard:** Android Material 3 with Dynamic Material You + OLED Midnight Fallback  
**Accessibility Target:** WCAG 2.1 AA/AAA Compliance & Neurodivergent-First Usability  
**Parent PRD:** [docs/requirements.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/requirements.md)  
**Technical Companion:** [docs/technical_scoping.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/technical_scoping.md)  
**Milestone Scope:** [docs/milestone_1_scope.md](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/milestone_1_scope.md)

---

## 1. Design Vision & Aesthetic Direction

### 1.1 The "Artisanal Digital Instrument" Philosophy
Most modern productivity apps fall into one of two traps: sterile corporate Jira-like dashboards or flashy gamified toys with cartoon confetti that overwhelm people with ADHD.

**Focusmaxxing** is designed as a **precision instrument**—reminiscent of high-end mechanical stopwatches, Dieter Rams' audio hardware, and modern craft tools like *Things 3* and *Linear*:
* **Sacred Minimalist Timer:** The main focus screen contains zero ambient music widgets or settings clutter. It is a quiet, sacred space dedicated solely to the active countdown and task anchor.
* **Tactile & Visceral Friction:** Canceling an active session requires deliberate physical effort (tapping Pause first, then holding down Cancel for 5 continuous seconds with progressive haptic resistance).
* **Respectful of Executive Function:** No decision fatigue. Only one prominent action on screen at any time.

---

## 2. Design Tokens & Visual Standard

### 2.1 Color Architecture (Dynamic Material You + OLED Fallback)

Focusmaxxing organically inherits Android 12+ wallpaper palettes via `DynamicColorBuilder`, but strictly maps semantic contrast tokens so focus states are immediately distinguishable from rest states.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Semantic Token Palette                          │
├───────────────────────┬───────────────────────┬────────────────────────┤
│ Token Name            │ Hex / System Token    │ Functional Purpose     │
├───────────────────────┼───────────────────────┼────────────────────────┤
│ `surface_midnight`    │ #090A0D               │ OLED primary background│
│ `surface_raised`      │ #13151B               │ Cards & dialog surfaces│
│ `surface_hairline`    │ #222631               │ 1dp crisp dividers     │
│ `text_high_contrast`  │ #F4F6FB (96% white)   │ Primary typography     │
│ `text_muted`          │ #8B92A4 (60% white)   │ Labels, timestamps     │
│ `accent_lock_in`      │ #00E676 (Emerald)     │ Active focus & flow    │
│ `accent_rest_mode`    │ #38B6FF (Glacier Blue)│ Restorative break mode │
│ `accent_hard_lock`    │ #FF3B30 (Crimson)     │ Shield overlay/danger  │
│ `accent_streak_gold`  │ #FFB800 (Warm Amber)  │ Active streak counter  │
└───────────────────────┴───────────────────────┴────────────────────────┘
```

### 2.2 Typography Hierarchy
To prevent cognitive jitter, all numeric countdowns strictly utilize **Monospace / Tabular Figures** (`FontFeature.tabularFigures()`). Digits never shift horizontally as seconds tick down.

* **Display Countdown:** 64pt, Bold, Tabular Numbers, -1.5px letter spacing.
* **Goal Anchor Headline:** 20pt, Semi-Bold, Humanist Sans, 1.3 line height.
* **Action Button Labels:** 16pt, Medium, 0.5px letter spacing, All-Caps or Title Case.
* **Micro-Copy & Chips:** 13pt, Regular, Secondary Muted.

### 2.3 Motion & Physics Philosophy
* **Continuous Sweeping Dial:** The circular gauge renders as a smooth, continuous sweep arc with a soft glowing indicator dot at the leading tip and a subtle hairline background track.
* **Spring Dynamics:** Bottom sheets use damped springs (`dampingRatio: 0.85`, `stiffness: 300`) to feel like physical drawers.
* **Accessibility Motion Guard:** Checks `MediaQuery.disableAnimationsOf(context)` to automatically flatten animations for users with vestibular or motion sensitivities.

---

## 3. Screen-by-Screen Detailed Blueprints & Wireframes

---

### 3.1 Screen 1: The Timer Screen (Tab 1 - Core Focus Engine)

The Timer screen is the root landing screen. It has four distinct visual states.

#### A. State 1: Idle (Ready to Lock In)
```
+-------------------------------------------------------------+
|  [Focusmaxxing]                              [Backlog Icon] |
|                                                             |
|                                                             |
|                     ┌─────────────────┐                     |
|                  . '=====\             ' .                  |
|                /          ●                \                |
|               |            25:00            |               |
|               |                             |               |
|                \                           /                |
|                  . '                   ' .                  |
|                     └─────────────────┘                     |
|                                                             |
|           [ 15m ]   [ 25m ]   [ 45m ]   [ 60m ]   [Custom]  |
|                                                             |
|                                                             |
|              +-------------------------------+              |
|              |         🚀 LOCK IN            |              |
|              +-------------------------------+              |
|                                                             |
|    [⏱ Timer]              [🛡 Shield]          [📊 Insights] |
+-------------------------------------------------------------+
```
* **Top Header:** Clean wordmark on the left; subtle, low-contrast Backlog list icon on the top right.
* **Dial Widget:** Continuous sweeping arc with an illuminated leading tip dot (`●`).
* **Duration Pills:** Fast 1-tap preset pills (`15m`, `25m`, `45m`, `60m`, `Custom`) directly under the dial. Zero modal friction to pick common focus blocks.
* **Primary CTA:** Large 56dp pill button labeled **"🚀 LOCK IN"** with a gentle breathing pulse.
* **Sacred Main Screen:** Zero ambient sound controls or cluttered settings on this screen.

---

#### B. State 2: 1-Sentence Goal Modal (Task Initiation)
When the user taps **"LOCK IN"**, the dial blurs softly and this low-friction bottom sheet springs up:
```
+-------------------------------------------------------------+
|                      ─── Handle ───                         |
|                                                             |
|   What ONE thing are you locking in on?                     |
|   ┌─────────────────────────────────────────────────────┐   |
|   | Finish slides 3 and 4                               |   |
|   └─────────────────────────────────────────────────────┘   |
|   42/60 chars                                               |
|                                                             |
|   Quick Anchors:                                            |
|   [ ⚡ Deep Work ]  [ Write spec ]  [ Fix auth bug ]         |
|                                                             |
|   +-----------------------------------------------------+   |
|   |                   START FOCUS (25m)                 |   |
|   +-----------------------------------------------------+   |
+-------------------------------------------------------------+
```
* **Auto-Focus:** Keyboard pops up immediately upon presentation.
* **Quick-Flow Fallback Chip:** Tapping `[ ⚡ Deep Work ]` fills the field with one tap for users who want to bypass typing and get straight into flow.
* **Direct Submit:** Tapping the keyboard "Done" action starts the timer immediately with zero intermediate prompts.

---

#### C. State 3: Running (Active Flow State)
```
+-------------------------------------------------------------+
|  [Focusmaxxing]                              [Backlog Icon] |
|                                                             |
|                                                             |
|                     ┌─────────────────┐                     |
|                  . '===============\   ' .                  |
|                /                    ●       \               |
|               |            21:44            |               |
|               |                             |               |
|                \   "Finish slides 3 and 4" /                |
|                  . '                   ' .                  |
|                     └─────────────────┘                     |
|                                                             |
|                                                             |
|              +-------------------------------+              |
|              |         ⏸ PAUSE FOCUS        |              |
|              +-------------------------------+              |
|                                                             |
|    [⏱ Timer]              [🛡 Shield]          [📊 Insights] |
+-------------------------------------------------------------+
```
* **Distraction-Free:** While the timer is running, **only the Pause button is visible**. The screen is completely clean.
* **The Goal Anchor:** The 1-sentence goal is prominently pinned inside the ring beneath the countdown.

---

#### D. State 4: Paused (Reveals Hold-to-Cancel Safety Valve)
```
+-------------------------------------------------------------+
|  [Focusmaxxing]                              [Backlog Icon] |
|                                                             |
|                     ┌─────────────────┐                     |
|                  . '===============\   ' .                  |
|                /                    ●       \               |
|               |       PAUSED (21:44)        |               |
|                \   "Finish slides 3 and 4" /                |
|                  . '                   ' .                  |
|                     └─────────────────┘                     |
|                                                             |
|              +-------------------------------+              |
|              |        ▶ RESUME FOCUS         |              |
|              +-------------------------------+              |
|                                                             |
|              +-------------------------------+              |
|              |      Hold to Cancel (5s)      |              |
|              +-------------------------------+              |
|                                                             |
|    [⏱ Timer]              [🛡 Shield]          [📊 Insights] |
+-------------------------------------------------------------+
```
* **Two-Step Cognitive Barrier:** To prevent impulse quits, the user must explicitly pause first. Only in the paused state is the **Hold to Cancel (5s)** button revealed.
* **Cancellation Interaction:** Continuous 5-second press-and-hold with progressive haptic feedback. Releasing before 5.0s springs back to 0.0s immediately.

---

#### E. State 5: Rest Mode (Restorative Break Guard)
```
+-------------------------------------------------------------+
|  [REST MODE]                                                |
|                                                             |
|                     ┌─────────────────┐                     |
|                  . '                   ' .                  |
|                /                           \                |
|               |            04:12            |               |
|               |                             |               |
|                \     RECHARGE YOUR BRAIN   /                |
|                  . '                   ' .                  |
|                     └─────────────────┘                     |
|                                                             |
|          ┌─────────────────────────────────────────┐        |
|          | 💡 Step away from your desk.            |        |
|          |    Drink a glass of water or stretch.   |        |
|          |    Social feeds remain locked. 🛡️      |        |
|          └─────────────────────────────────────────┘        |
|                                                             |
|              +-------------------------------+              |
|              |      I'M READY TO FOCUS       |              |
|              +-------------------------------+              |
+-------------------------------------------------------------+
```
* **Atmosphere Shift:** Turns to Glacier Blue / Slate.
* **Strict Fixed Rest:** Fixed 5-minute duration (no extension buttons to prevent break drift). Single action: `[ I'M READY TO FOCUS ]` to resume early if recharged.
* **Anti-Doomscroll Lockdown:** When break timer hits `00:00`, blocked apps remain locked until the user returns to Focusmaxxing and taps `[ Lock In ]`.

---

### 3.2 Screen 2: Binary Check-In Dialog

Appears immediately upon timer completion (clock pauses on this screen so break time is not wasted):

```
+-------------------------------------------------------------+
|                                                             |
|                        🎉 25:00 Complete                    |
|                 "Finish slides 3 and 4"                     |
|                                                             |
|                       Did you lock in?                      |
|                                                             |
|      +-----------------------+   +-----------------------+  |
|      |      LOCKED IN 🚀     |   |      DERAILED 💀      |  |
|      |     (Flow State)      |   |   (Got Distracted)    |  |
|      +-----------------------+   +-----------------------+  |
|                                                             |
+-------------------------------------------------------------+
```
* **Clock Paused:** The 5-minute break countdown begins only **after** the user taps either button, ensuring they receive their full rest period.
* **Zero Surveys:** 1-tap instant check-in.

---

### 3.3 Screen 3: Unobtrusive Backlog Sheet

Accessible by tapping the subtle list icon in the top header of the Timer:

```
+-------------------------------------------------------------+
|  ─── Backlog (Focus Scratchpad) ───             [✕ Close]   |
|                                                             |
|  ┌───────────────────────────────────────────────┬──────┐   |
|  | Add next task...                              |  ＋  |   |
|  └───────────────────────────────────────────────┴──────┘   |
|                                                             |
|  TAP TO LOCK IN · SWIPE TO REMOVE                           |
|                                                             |
|  ┌──────────────────────────────────────────────────────┐   |
|  | 🚀 Draft system architecture document                |   |
|  └──────────────────────────────────────────────────────┘   |
|  ┌──────────────────────────────────────────────────────┐   |
|  | 🚀 Review PR #104 on Github                          |   |
|  └──────────────────────────────────────────────────────┘   |
|                                                             |
+-------------------------------------------------------------+
```
* **Instant Activation:** Tapping any task tile sets it as the active goal, dismisses the sheet, and opens the Timer ready to go.
* **Swipe-to-Dismiss:** Swiping left deletes the task with a gentle undo snackbar.

---

### 3.4 Screen 4: The Brainrot Shield (Tab 2 - App Blocker)

```
+-------------------------------------------------------------+
|  Brainrot Shield                                            |
|  Physically locks addictive feeds during focus blocks.      |
|                                                             |
|  ┌──────────────────────────────────────────────────────┐   |
|  | 🛡️ Shield Status: ACTIVE (2/2 Apps Selected)         |   |
|  └──────────────────────────────────────────────────────┘   |
|                                                             |
|  QUICK PRESETS                                              |
|  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            |
|  | [x] Instagram| | [x] TikTok  | | [ ] Twitter |            |
|  └─────────────┘ └─────────────┘ └─────────────┘            |
|  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            |
|  | [ ] Reddit  | | [ ] YouTube | | [ ] Games   |            |
|  └─────────────┘ └─────────────┘ └─────────────┘            |
|                                                             |
|  ALL INSTALLED APPS                   [ 🔍 Search apps... ] |
|  ┌──────────────────────────────────────────────────────┐   |
|  | (Icon) Discord                                  [ ]  |   |
|  | (Icon) Chrome                                   [ ]  |   |
|  └──────────────────────────────────────────────────────┘   |
|                                                             |
|    [⏱ Timer]              [🛡 Shield]          [📊 Insights] |
+-------------------------------------------------------------+
```
* **2-App Limit Upgrade Modal:** When attempting to select a 3rd app, an upgrade sheet appears:
  * Explains the 2-app free cap.
  * Shows Lifetime Pro ($9.99 flat).
  * Direct action: `[ Swap Free App ]` allowing the user to uncheck an existing app without paying.

---

### 3.5 Screen 5: Hard Lock Overlay (`SYSTEM_ALERT_WINDOW`)

```
+-------------------------------------------------------------+
|                                                             |
|                           🔒 LOCKED IN                      |
|                                                             |
|                      "Finish slides 3 and 4"                |
|                                                             |
|                             18:22                           |
|                           REMAINING                         |
|                                                             |
|                Bro, your goal isn't on Instagram.           |
|                Get back to work.                            |
|                                                             |
|                                                             |
|              +-------------------------------+              |
|              |    RETURN TO FOCUSMAXXING     |              |
|              +-------------------------------+              |
|                                                             |
|                       Zero Bypass Enabled                   |
+-------------------------------------------------------------+
```

---

### 3.6 Screen 6: Insights & Settings (Tab 3)

```
+-------------------------------------------------------------+
|  Insights & Settings                                        |
|                                                             |
|  TODAY'S MOMENTUM                                           |
|  ┌───────────────────────────┬───────────────────────────┐  |
|  |        125 MINS           |          5 / 5            |  |
|  |      Locked In Today      |     Sessions Finished     |  |
|  └───────────────────────────┴───────────────────────────┘  |
|                                                             |
|  CURRENT STREAK: 🔥 6 DAYS                                   |
|  • Streak Tracking: [ On / Off ]                             |
|  • Include Weekends in Streak: [ Off ] (Weekends Exempt)     |
|                                                             |
|  RECENT SESSIONS                                            |
|  ┌──────────────────────────────────────────────────────┐   |
|  | 🚀 25m · "Finish slides 3 and 4"            14:15 PM |   |
|  | 🚀 25m · "Fix auth interceptor bug"         13:30 PM |   |
|  └──────────────────────────────────────────────────────┘   |
|                                                             |
|  CONFIG & PREFERENCES                                       |
|  • Daily Focus Reminders: [ Off ] (Configurable 09:00 AM)   |
|  • Ambient Audio: [ Off ▾ ] (Brown Noise, 40Hz, Rain)       |
|  • Focus Duration: 25 mins                                  |
|  • Rest Duration: 5 mins                                    |
|                                                             |
|  +-------------------------------------------------------+  |
|  | ⭐ LIFETIME PRO: UNLOCKED ($9.99 One-Time)             |  |
|  +-------------------------------------------------------+  |
|                                                             |
|    [⏱ Timer]              [🛡 Shield]          [📊 Insights] |
+-------------------------------------------------------------+
```
* **Compassionate Streak:** Zero guilt design. Master toggle to completely hide streaks, optional "Include Weekends" toggle (OFF by default so weekends are exempt), and silent reset on missed days.
* **Daily Reminders:** Optional daily push notification to prompt focus (OFF by default to prevent notification spam). Configurable time picker when enabled.
* **Ambient Audio Config:** Audio soundscapes are cleanly configured here (with preview play button and volume slider), keeping the Timer screen clean.

---

## 4. Accessibility (a11y) & Ergonomics Framework

* **Thumb Zone Optimization:** All primary actions (Start, Pause, Hold-to-Cancel, Check-In) are anchored in the lower 35% of the screen.
* **48dp Rule:** Every interactive tap target strictly complies with `kMinInteractiveDimension` (48x48dp minimum).
* **Screen Reader Semantics:** Custom countdown dials and hold buttons are wrapped in explicit `Semantics` widgets announcing live time remaining and gesture instructions to TalkBack users.
* **Motion Guard:** Automatically flattens animations when `MediaQuery.disableAnimationsOf(context)` is detected.
