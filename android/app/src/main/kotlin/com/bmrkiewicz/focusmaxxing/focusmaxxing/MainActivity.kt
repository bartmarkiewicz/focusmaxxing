package com.bmrkiewicz.focusmaxxing.focusmaxxing

import android.annotation.SuppressLint
import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.bmrkiewicz.focusmaxxing.focusmaxxing.shield.AutoShieldAlarmReceiver
import com.bmrkiewicz.focusmaxxing.focusmaxxing.shield.FocusShieldService
import flutter.overlay.window.flutter_overlay_window.OverlayService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    companion object {
        private const val SHIELD_CHANNEL = "com.focusmaxxing/shield"
        private var shieldMethodChannel: MethodChannel? = null

        fun notifyOverlayAction(action: String) {
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                try {
                    shieldMethodChannel?.invokeMethod(
                        "onOverlayAction",
                        mapOf("action" to action)
                    )
                } catch (_: Exception) {}
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FocusShieldService.ensureOverlayBridgeRegistered(applicationContext)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHIELD_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        shieldMethodChannel = channel
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        shieldMethodChannel?.setMethodCallHandler(null)
        shieldMethodChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startShield" -> {
                FocusShieldService.ensureOverlayBridgeRegistered(applicationContext)
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                val isScheduled = call.argument<Boolean>("isScheduled") ?: false
                val timeRange = call.argument<String>("timeRange")
                val intent = Intent(this, FocusShieldService::class.java).apply {
                    putStringArrayListExtra(FocusShieldService.EXTRA_BLOCKED_PACKAGES, ArrayList(packages))
                    putExtra(FocusShieldService.EXTRA_IS_SCHEDULED, isScheduled)
                    if (timeRange != null) {
                        putExtra(FocusShieldService.EXTRA_TIME_RANGE, timeRange)
                    }
                }
                ContextCompat.startForegroundService(this, intent)
                result.success(true)
            }

            "stopShield" -> {
                val force = call.argument<Boolean>("force") ?: false
                val active = FocusShieldService.instance
                val isManualSessionActive = active != null &&
                    !active.isScheduled &&
                    (FocusShieldService.targetEndTimeEpochMs > System.currentTimeMillis() || FocusShieldService.currentRemainingSeconds > 0)

                if (force) {
                    if (isManualSessionActive) {
                        // Schedule alarm callback fired (e.g. 06:00), but a manual session is currently running:
                        // Do not stop service. Invalidate schedule baseline only so the manual session finishes uninterrupted.
                        FocusShieldService.isScheduledBaseline = false
                        FocusShieldService.scheduledBaselineRange = null
                    } else {
                        // Schedule ended (or forced stop) with no manual session running: shut down service.
                        FocusShieldService.isScheduledBaseline = false
                        FocusShieldService.scheduledBaselineRange = null
                        FocusShieldService.currentIsMaximumFocus = false
                        FocusShieldService.currentIsPaused = false
                        FocusShieldService.targetEndTimeEpochMs = 0L
                        if (FocusShieldService.isRunning) {
                            stopService(Intent(this, FocusShieldService::class.java))
                        }
                        FocusShieldService.dismissOverlayOnly(applicationContext)
                    }
                } else {
                    // Manual session ended / cancelled in app (force: false)
                    if (active != null && FocusShieldService.isScheduledBaseline) {
                        // Scheduled baseline is active: cleanly restore it!
                        active.restoreScheduledBaseline()
                    } else {
                        // No scheduled baseline: shut down service.
                        FocusShieldService.currentIsMaximumFocus = false
                        FocusShieldService.currentIsPaused = false
                        FocusShieldService.targetEndTimeEpochMs = 0L
                        if (FocusShieldService.isRunning) {
                            stopService(Intent(this, FocusShieldService::class.java))
                        }
                        FocusShieldService.dismissOverlayOnly(applicationContext)
                    }
                }
                result.success(true)
            }

            "syncOverlayData" -> {
                val goal = call.argument<String>("goal") ?: call.argument<String>("taskGoal") ?: "Deep Work"
                val remaining = call.argument<Int>("remainingSeconds") ?: call.argument<Int>("remaining") ?: 1500
                val isBreak = call.argument<Boolean>("isBreak") ?: call.argument<Boolean>("isBreakMode") ?: false
                val isMaximumFocus = call.argument<Boolean>("isMaximumFocus") ?: false
                val isPaused = call.argument<Boolean>("isPaused") ?: false
                val targetEndTime = (call.argument<Number>("targetEndTimeEpochMs"))?.toLong() ?: 0L
                FocusShieldService.updateOverlaySessionState(
                    applicationContext,
                    goal,
                    remaining,
                    isBreak,
                    isMaximumFocus,
                    targetEndTime,
                    isPaused
                )
                result.success(true)
            }

            "isShieldRunning" -> {
                result.success(FocusShieldService.isRunning)
            }

            "checkPermissions" -> {
                result.success(
                    mapOf(
                        "usageStats" to hasUsageStatsPermission(),
                        "overlay" to hasOverlayPermission(),
                        "batteryOptimization" to isIgnoringBatteryOptimizations()
                    )
                )
            }

            "requestUsageStatsPermission" -> {
                try {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                } catch (_: ActivityNotFoundException) {
                    startActivity(Intent(Settings.ACTION_SETTINGS).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
                }
                result.success(true)
            }

            "requestOverlayPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    } catch (_: ActivityNotFoundException) {
                        startActivity(Intent(Settings.ACTION_SETTINGS).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
                    }
                }
                result.success(true)
            }

            "requestIgnoreBatteryOptimizations" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        @SuppressLint("BatteryLife")
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                    } catch (_: ActivityNotFoundException) {
                        try {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                        } catch (_: ActivityNotFoundException) {
                            startActivity(Intent(Settings.ACTION_SETTINGS).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) })
                        }
                    }
                }
                result.success(true)
            }

            "bringToForeground" -> {
                FocusShieldService.dismissOverlayAndReturnToApp(applicationContext)
                result.success(true)
            }

            "scheduleAlarms" -> {
                val startHour = call.argument<Int>("startHour") ?: 9
                val startMinute = call.argument<Int>("startMinute") ?: 0
                val endHour = call.argument<Int>("endHour") ?: 17
                val endMinute = call.argument<Int>("endMinute") ?: 0
                AutoShieldAlarmReceiver.scheduleAlarm(applicationContext, true, startHour, startMinute)
                AutoShieldAlarmReceiver.scheduleAlarm(applicationContext, false, endHour, endMinute)
                result.success(true)
            }

            "cancelAlarms" -> {
                AutoShieldAlarmReceiver.cancelAlarms(applicationContext)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        @Suppress("DEPRECATION")
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
        } else {
            true
        }
    }
}
