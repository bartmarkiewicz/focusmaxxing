/// Centralized copy strings following the "Instrument" voice:
/// Sentence case, no emoji, no exclamation marks, factual and calm.
abstract final class AppStrings {
  // Navigation / Tabs
  static const String tabTimer = 'Timer';
  static const String tabShield = 'Shield';
  static const String tabInsights = 'Insights';

  // Timer Page
  static const String startSession = 'Start session';
  static const String holdToStop = 'Hold to stop';
  static const String sound = 'Sound';
  static const String strict = 'Strict';
  static const String off = 'Off';
  static const String on = 'On';
  static const String breakLabel = 'Break';
  static const String quickCaptureHint = 'Dump a quick thought...';

  static String soundToggle(bool isEnabled) => 'Sound: ${isEnabled ? on : off}';
  static String strictToggle(bool isEnabled) => 'Strict: ${isEnabled ? on : off}';
  static String blockedAppsSummary(int count, {String? firstAppName}) {
    if (count <= 0) return 'No apps blocked';
    if (firstAppName != null && count == 1) return '$firstAppName blocked';
    if (firstAppName != null && count > 1) {
      return '$firstAppName +${count - 1} blocked';
    }
    return '$count apps blocked';
  }

  // Session Receipt / Check-In
  static String sessionComplete(int sessionNumber) =>
      'SESSION ${sessionNumber.toString().padLeft(2, '0')} — COMPLETE';
  static const String didYouLockIn = 'Did you lock in?';
  static const String ratingLockedIn = 'Locked in';
  static const String ratingDerailed = 'Derailed';
  static const String howDidItGo = 'Did you lock in?';
  static const String ratingFocused = 'Locked in';
  static const String ratingMixed = 'Mixed';
  static const String ratingDidntFinish = "Derailed";
  static const String startAnother25 = 'Start another 25 min';
  static const String break5Min = '5 min break';
  static const String done = 'Done';
  static const String save = 'Save';
  static const String started = 'Started';
  static const String blockedAttempts = 'Blocked attempts';
  static const String todayTotal = 'Today total';

  // Goal & Multi-Target
  static const String whatAreYouWorkingOn = 'What are you working on?';
  static const String recent = 'RECENT';
  static const String enterGoalHint = 'e.g. Thesis draft';
  static const String targets = 'TARGETS';

  // Brainrot Shield
  static const String shieldTitle = 'Brainrot Shield';
  static const String presets = 'PRESETS';
  static String appsBlockedHeader(int count) => 'APPS · $count BLOCKED';
  static const String schedule = 'SCHEDULE';
  static const String searchAppsHint = 'Search apps...';
  static const String accessibilityNeeded = 'Accessibility permission needed → Fix';
  static const String usageAccessNeeded = 'Usage access permission needed → Fix';
  static const String overlayPermissionNeeded = 'Overlay permission needed → Fix';

  // Overlay Lock View
  static const String blockedHeadline = 'BLOCKED';
  static String blockedUntilNotice(String appName, String formattedTime) =>
      '$appName is blocked until $formattedTime.';
  static const String youAreWorkingOn = "You're working on";
  static String goalWithRemaining(String goal, int minutesLeft) =>
      '$goal — $minutesLeft min left.';
  static const String backToWork = 'Back to work';
  static const String breatheForAMinute = 'Breathe for a minute';
  static const String holdToEndSession = 'Hold to end session';

  // Breather View
  static const String urgePassesNotice =
      'The urge usually passes in about a minute. Breathe with the square.';
  static const String breathIn = 'In';
  static const String breathHold = 'Hold';
  static const String breathOut = 'Out';

  // Insights
  static const String insightsTitle = 'Insights';
  static const String today = 'Today';
  static const String thisWeek = 'This week';
  static const String streak = 'Streak';
  static const String history = 'HISTORY';
  static const String filter7D = '7D';
  static const String filter30D = '30D';
  static const String filter1Y = '1Y';
  static const String insightsNoSessions = 'Completed focus sessions will appear here.';

  // Settings
  static const String settingsTitle = 'Settings';
  static const String appearanceSection = 'APPEARANCE';
  static const String themeMode = 'Theme';
  static const String themeSystem = 'System';
  static const String themeDark = 'Dark';
  static const String themeLight = 'Light';
  static const String finishSection = 'ACCENT FINISH';
  static const String proSection = 'PRO';
  static const String restorePurchases = 'Restore purchases';

  // Pro Upgrade
  static const String proTitle = 'Focusmaxxing Pro';
  static const String proTag = 'PRO';
  static String buyOnce(String price) => 'Buy once — $price';
  static const String oneTimeNotice = 'One-time purchase. No subscription.';
  static const String proBenefitAccentFinishes = 'Custom physical finishes: Brass, Signal, Ink, Moss';
  static const String proBenefitUnlimitedShield = 'Unlimited apps shielded';
  static const String proBenefitSchedules = 'Automated focus schedules';
  static const String proBenefitSoundscapes = 'Full ambient audio library';
}
