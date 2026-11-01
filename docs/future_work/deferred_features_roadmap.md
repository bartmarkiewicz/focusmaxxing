# Focusmaxxing: Deferred Features Roadmap (MVP 2.1+)

**Status:** Backlog / Ready for Implementation  
**Target Milestone:** MVP 2.1 / Feature Hardening Sprint  
**Parent Document:** [MVP 2.0 PRD](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/archive/mvp_2.0_product_requirements_document.md)  
**Architecture Context:** [System Overview](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/docs/architecture/system_overview.md)

---

## 1. Feature Backlog & Priority Matrix

| Feature ID | Feature Name | Core Area / Layer | Architectural Touchpoints | Complexity | Priority |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **E4** | **Streak Shield 24h Recovery Grace Window** | Domain / Data (`insights`) | [`InsightsRepositoryImpl`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/data/repositories/insights_repository_impl.dart), [`StreakCard`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/presentation/widgets/streak_card.dart) | Medium | P1 |
| **E5** | **1-Tap Widget Deep Link Auto-Start** | Native Kotlin / Presentation (`widget`, `timer`) | [`GlanceableDialWidgetProvider.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/widget/GlanceableDialWidgetProvider.kt), [`TimerNotifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart) | Low | P1 |
| **E8** | **15-Second Audio Teaser Previews** | Domain / Presentation (`audio`, `billing`) | [`AudioNotifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/presentation/notifiers/audio_notifier.dart), [`SoundscapeConfigTile`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/presentation/widgets/soundscape_config_tile.dart) | Medium | P2 |
| **E13** | **Daily Momentum Target Ring & 7D Sparkline** | Presentation (`insights`) | [`InsightsPage`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/presentation/pages/insights_page.dart), `CustomPainter` | Medium | P2 |
| **E14** | **Clockface Radial Detents & Extended Presets** | Presentation (`timer`) | [`TimerDialWidget`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/timer_dial_widget.dart), [`DurationPresetsWidget`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/duration_presets_widget.dart) | Low | P2 |
| **E15** | **App Category Filter Chips with Haptic Toggles** | Presentation / Data (`shield`) | [`ShieldNotifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart), [`ShieldPage`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/pages/shield_page.dart) | Medium | P3 |

---

## 2. Technical Feature Specifications

### 2.1 E4: Streak Shield 24-Hour Recovery Grace Window

#### Problem Statement
Current streak logic in [`InsightsRepositoryImpl.calculateStreak`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/data/repositories/insights_repository_impl.dart#L122-L134) allows 1 weekly auto-freeze. If a user misses a second day or has already consumed their weekly freeze, the streak immediately drops to zero. For ADHD users, sudden streak collapse triggers severe demotivation and abandonment ("streak despair").

#### Architectural Specification
1. **Grace Window Calculation**:
   - When evaluating streak status on day $T$, if day $T-1$ has zero completed sessions and no weekly freeze remains, do not immediately reset streak to `0`.
   - Instead, mark streak state as `StreakStatus.atRisk`.
   - Establish a 24-hour grace deadline: `graceDeadline = startOfDay(T) + 24 hours`.
2. **Recovery Criteria**:
   - Completing any single focus session of $\ge 20\text{ minutes}$ (`actual_duration_seconds >= 1200` with `status == 'LOCKED_IN'`) during day $T$ satisfies the recovery criteria.
   - Upon completion, [`InsightsRepositoryImpl`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/data/repositories/insights_repository_impl.dart) increments the streak from the previous unbroken anchor day, logs recovery to `SharedPreferences` key `streak_recovery_used_epoch_ms`, and updates the status to `StreakStatus.recovered`.
3. **Data Model & Persistence**:
   - `SharedPreferences` keys:
     - `streak_shield_grace_active` (bool)
     - `streak_shield_grace_deadline_epoch_ms` (int)
     - `streak_last_recovery_date` (string, ISO-8601 date, capped at 1 recovery per 14 days to prevent abuse).

#### Acceptance Criteria
- [ ] Streak calculation marks consecutive days with missing yesterday as `atRisk` instead of `0`.
- [ ] Completing a 20-minute focus session today retroactively repairs the broken link.
- [ ] [`StreakCard`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/presentation/widgets/streak_card.dart) renders an amber badge: `"STREAK AT RISK: Complete 20m today to protect your 12-day streak"`.
- [ ] Unit tests in `test/features/insights/data/insights_repository_impl_test.dart` verify 24h grace window calculation and recovery session threshold.

---

### 2.2 E5: 1-Tap Widget Deep Link Auto-Start

#### Problem Statement
Tapping the home screen widget [`QuickLockInWidgetProvider.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/widget/QuickLockInWidgetProvider.kt) navigates to `MainActivity` via intent `focusmaxxing://lockin`, but triggers [`GoalInputDialog`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/goal_input_dialog.dart), adding input friction when an ADHD user needs immediate flow capture.

#### Architectural Specification
1. **Deep Link URI Routing**:
   - Update widget pending intent URI: `focusmaxxing://lockin?autoStart=true`.
   - In [`MainActivity.kt`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/android/app/src/main/kotlin/com/bmrkiewicz/focusmaxxing/focusmaxxing/MainActivity.kt), intercept `onNewIntent` and push `autoStart` query flag through the `MethodChannel` or `app_links` stream.
2. **Goal Fallback Resolution**:
   - When `autoStart == true`:
     - Query [`GetBacklogTasksUseCase`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/backlog/domain/usecases/get_backlog_tasks_usecase.dart).
     - If non-empty, use the title of the highest-priority incomplete task (`backlogTasks.firstWhere((t) => !t.isCompleted).title`).
     - If backlog is empty, fall back to default goal `"Deep Work"`.
3. **Execution & UI Confirmation**:
   - Call [`TimerNotifier.startFocusSession(goal: resolvedGoal)`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/notifiers/timer_notifier.dart) directly without displaying dialogs.
   - Display a non-blocking 5-second `SnackBar` at the base of [`TimerPage`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/pages/timer_page.dart):
     - Text: `"Locked in: [Resolved Goal]"`
     - Action: `[ Rename ]` (opens inline edit dialog).

#### Acceptance Criteria
- [ ] Tapping home screen widget when app is in background launches directly into running timer within 300ms.
- [ ] Top backlog task title is populated as goal anchor; defaults to `"Deep Work"` if backlog is empty.
- [ ] Ongoing notification and shield service arm immediately upon launch.

---

### 2.3 E8: 15-Second Audio Teaser Previews

#### Problem Statement
Locked Pro soundscapes (40Hz Binaural, Rain, Chime) in [`SoundscapeConfigTile`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/presentation/widgets/soundscape_config_tile.dart) present a locked lock icon. Users cannot evaluate audio quality before purchasing Lifetime Pro ($9.99), lowering conversion rates.

#### Architectural Specification
1. **State Machine Extension**:
   - In [`AudioNotifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/presentation/notifiers/audio_notifier.dart), introduce preview state:
     ```dart
     bool get isPreviewPlaying;
     String? get previewTrackId;
     int get previewSecondsRemaining;
     ```
2. **Audio Engine Interaction**:
   - Tapping a locked soundscape initiates `playPreview(trackId)`.
   - [`AudioPlayerEngine`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/audio/data/datasources/audio_player_engine.dart) starts playback at full volume and schedules a 15-second `Timer.periodic`.
   - Over seconds 12–15 (last 3 seconds), linearly ramp volume down: `volume = 1.0 - ((15 - remaining) / 3.0)`.
   - At second 15, stop playback and emit `PreviewCompleted` event.
3. **Paywall Presentation**:
   - Upon `PreviewCompleted`, automatically display [`UpgradeModalSheet`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/billing/presentation/widgets/upgrade_modal_sheet.dart) with contextual header: `"Liked 40Hz Binaural Beats? Unlock all master tracks with Lifetime Pro"`.

#### Acceptance Criteria
- [ ] Tapping a Pro soundscape plays high-fidelity audio for exactly 15 seconds.
- [ ] Audio tile displays an animated 15-second circular countdown ring and waveform icon.
- [ ] Soft audio fade-out executes smoothly over the final 3 seconds without clipping.
- [ ] Paywall modal sheet opens immediately upon preview completion.

---

### 2.4 E13: Daily Momentum Target Ring & 7-Day Sparkline Dots

#### Problem Statement
The current [`InsightsPage`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/insights/presentation/pages/insights_page.dart) displays raw completed minutes (e.g., `"45 MINS"`), lacking a concrete daily target benchmark and weekly consistency cues.

#### Architectural Specification
1. **Target Ring Component (`MomentumGoalRing`)**:
   - Configurable daily goal minutes (default: 60 minutes, adjustable in 15-minute increments via settings, stored in `SharedPreferences` key `daily_focus_goal_minutes`).
   - `CustomPainter` rendering an emerald radial arc (`AppColors.accentLockIn`) over a muted background ring (`AppColors.surfaceHairline`).
   - Center readout: Current completed minutes vs target (e.g., `"45 / 60m"`), percentage (`"75%"`).
   - Milestone trigger: When `completedMinutes >= targetMinutes`, animate a pulse effect and display `"TARGET CRUSHED ⚡"`.
2. **7-Day Sparkline Dots Row (`SparklineDotsRow`)**:
   - Horizontal row displaying the last 7 calendar days (`M T W T F S S`).
   - Quad-state dot representation:
     - `TargetMet` (Emerald filled): $\ge \text{Daily Goal}$.
     - `Partial` (Amber filled): $> 0\text{ minutes}$ but $<$ target.
     - `FreezeProtected` (Cyan shield icon): Protected by weekly freeze.
     - `Missed` (Muted dark ring): 0 minutes.

#### Acceptance Criteria
- [ ] Ring arc accurately matches `todayFocusSeconds / (dailyGoalMinutes * 60)`.
- [ ] Ring caps visually at 100% while displaying overflow text (e.g., `"75 / 60m • 125%"`).
- [ ] Sparkline dots reflect historical SQLite query from `sessions` grouped by `date(start_time_epoch_ms / 1000, 'unixepoch', 'localtime')`.

---

### 2.5 E14: Clockface Radial Detents & Extended Presets

#### Problem Statement
[`TimerDialWidget`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/timer_dial_widget.dart) allows continuous angle scrubbing but lacks tactile detents at standard Pomodoro increments. Furthermore, preset buttons are limited to 15m, 25m, 45m, 60m, omitting common 30m intervals and 90m ultradian deep work blocks.

#### Architectural Specification
1. **Radial Detent Snap Engine**:
   - Subdivide 360° dial into 5-minute detents: $360^\circ / 12 = 30^\circ$ per 5-minute increment (for a 60m clockface).
   - In `GestureDetector.onPanUpdate`:
     - Compute raw scrubbed angle $\theta$.
     - When $\theta$ is within $\pm 3^\circ$ of a $30^\circ$ multiple, snap the duration to the nearest 5-minute mark.
     - Trigger `HapticFeedback.selectionClick()` on every detent crossed.
2. **Dial Detents Painter**:
   - Render 12 subtle tick marks along the outer perimeter of the timer track in [`TimerDialWidget`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/timer_dial_widget.dart).
   - Active ticks illuminated with `AppColors.accentLockIn`; inactive ticks rendered with `AppColors.surfaceHairline`.
3. **Extended Presets**:
   - In [`DurationPresetsWidget`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/timer/presentation/widgets/duration_presets_widget.dart), add `30m` and `90m` (Ultradian Flow) chips with horizontal scrolling layout.

#### Acceptance Criteria
- [ ] Dial snaps cleanly to 5-minute boundaries with distinct haptic feedback.
- [ ] 12 radial tick marks render with pixel-perfect alignment.
- [ ] `30m` and `90m` presets correctly set dial duration and update state.

---

### 2.6 E15: App Category Filter Chips in Shield Page

#### Problem Statement
In [`ShieldPage`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/pages/shield_page.dart), installed apps are presented in an unorganized list of 80–150 apps. Finding social media or browsers requires manual search queries.

#### Architectural Specification
1. **Category Resolver Subsystem**:
   - In `InstalledAppsDataSourceImpl`, extract `ApplicationInfo.category` on Android API 26+:
     - `ApplicationInfo.CATEGORY_SOCIAL` $\rightarrow$ `AppCategory.social`
     - `ApplicationInfo.CATEGORY_GAME` $\rightarrow$ `AppCategory.entertainment`
     - `ApplicationInfo.CATEGORY_PRODUCTIVITY` $\rightarrow$ `AppCategory.productivity`
   - Fallback heuristics: Match package names against known social/browser packages (`com.instagram.android`, `com.zhiliaoapp.musically`, `com.android.chrome`, `org.mozilla.firefox`).
2. **Filter Chips UI (`AppCategoryFilterBar`)**:
   - Horizontal chip selector: `[All]`, `[🛡️ Shielded (${activeCount})]`, `[Social]`, `[Entertainment]`, `[Browsers]`.
   - Instant filtering in [`ShieldNotifier`](file:///C:/Users/darkn/IdeaProjects/focusmaxxing/lib/features/shield/presentation/notifiers/shield_notifier.dart) without re-querying package manager.
   - `HapticFeedback.selectionClick()` dispatched on filter chip selection and toggle operations.

#### Acceptance Criteria
- [ ] Selecting `[🛡️ Shielded]` displays only currently shielded apps, allowing instant verification of free-tier slots.
- [ ] Social apps and browsers correctly categorize into respective chip filters.
- [ ] Filter changes execute in $< 16\text{ms}$ on lists with up to 300 installed packages.
