package com.bmrkiewicz.focusmaxxing.focusmaxxing.shield

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationCompat
import com.bmrkiewicz.focusmaxxing.focusmaxxing.MainActivity
import flutter.overlay.window.flutter_overlay_window.OverlayService
import flutter.overlay.window.flutter_overlay_window.WindowSetup
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class FocusShieldService : Service() {

    companion object {
        const val CHANNEL_ID = "focus_shield_channel"
        const val NOTIFICATION_ID = 9001
        const val EXTRA_BLOCKED_PACKAGES = "BLOCKED_PACKAGES"
        const val EXTRA_TIME_RANGE = "SCHEDULE_TIME_RANGE"
        const val EXTRA_IS_SCHEDULED = "IS_SCHEDULED"
        const val ACTION_STOP_SHIELD = "com.bmrkiewicz.focusmaxxing.STOP_SHIELD"
        const val OVERLAY_BRIDGE_CHANNEL = "com.focusmaxxing/overlay_bridge"
        const val OVERLAY_CACHED_ENGINE_ID = "myCachedEngine"
        private const val FULL_COVER_SIZE = -1999

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var currentGoal: String = "Deep Work"

        @Volatile
        var currentRemainingSeconds: Int = 1500

        @Volatile
        var currentIsBreak: Boolean = false

        @Volatile
        var currentIsMaximumFocus: Boolean = false

        @Volatile
        var dismissGraceUntilMs: Long = 0L

        @Volatile
        var lastProcessedEventTime: Long = 0L

        @Volatile
        private var returnDebounceUntilMs: Long = 0L

        private var instance: FocusShieldService? = null
        private var bridgeChannel: MethodChannel? = null

        fun ensureOverlayBridgeRegistered(context: Context) {
            val appContext = context.applicationContext
            var engine = FlutterEngineCache.getInstance().get(OVERLAY_CACHED_ENGINE_ID)
            if (engine == null) {
                try {
                    val engineGroup = FlutterEngineGroup(appContext)
                    val entryPoint = DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        "overlayMain"
                    )
                    engine = engineGroup.createAndRunEngine(appContext, entryPoint)
                    FlutterEngineCache.getInstance().put(OVERLAY_CACHED_ENGINE_ID, engine)
                } catch (_: Exception) {
                    return
                }
            }

            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, OVERLAY_BRIDGE_CHANNEL)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialOverlayState" -> {
                        result.success(
                            mapOf(
                                "goal" to currentGoal,
                                "remainingSeconds" to currentRemainingSeconds,
                                "isBreak" to currentIsBreak,
                                "isMaximumFocus" to currentIsMaximumFocus
                            )
                        )
                    }
                    "returnToFocusmaxxing" -> {
                        dismissOverlayAndReturnToApp(appContext)
                        result.success(true)
                    }
                    "cancelSessionFromOverlay" -> {
                        currentIsMaximumFocus = false
                        MainActivity.notifyOverlayAction("cancelSessionFromOverlay")
                        dismissOverlayAndReturnToApp(appContext)
                        try {
                            appContext.stopService(Intent(appContext, FocusShieldService::class.java))
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
            bridgeChannel = channel
        }

        fun updateOverlaySessionState(
            context: Context,
            goal: String,
            remainingSeconds: Int,
            isBreak: Boolean,
            isMaximumFocus: Boolean = currentIsMaximumFocus
        ) {
            val wasMaximumFocus = currentIsMaximumFocus
            currentGoal = goal.ifBlank { "Deep Work" }
            currentRemainingSeconds = remainingSeconds.coerceAtLeast(0)
            currentIsBreak = isBreak
            currentIsMaximumFocus = isMaximumFocus && !isBreak

            Handler(Looper.getMainLooper()).post {
                try {
                    val engine = FlutterEngineCache.getInstance().get(OVERLAY_CACHED_ENGINE_ID)
                    if (engine != null) {
                        val channel = bridgeChannel ?: MethodChannel(
                            engine.dartExecutor.binaryMessenger,
                            OVERLAY_BRIDGE_CHANNEL
                        ).also { bridgeChannel = it }
                        channel.invokeMethod(
                            "updateOverlayState",
                            mapOf(
                                "goal" to currentGoal,
                                "remainingSeconds" to currentRemainingSeconds,
                                "isBreak" to currentIsBreak,
                                "isMaximumFocus" to currentIsMaximumFocus
                            )
                        )
                    }
                } catch (_: Exception) {}

                val activeService = instance
                if (activeService != null && isRunning) {
                    if (currentIsMaximumFocus && !OverlayService.isRunning) {
                        activeService.scope.launch {
                            activeService.triggerOverlay()
                        }
                    } else if (wasMaximumFocus && !currentIsMaximumFocus && OverlayService.isRunning) {
                        dismissOverlayOnly(context.applicationContext)
                    }

                    if (!activeService.isDegraded && !activeService.isScheduled) {
                        val mins = (currentRemainingSeconds / 60).toString().padStart(2, '0')
                        val secs = (currentRemainingSeconds % 60).toString().padStart(2, '0')
                        val modeLabel = when {
                            currentIsBreak -> "Break Guard"
                            currentIsMaximumFocus -> "Maximum Focus ($currentGoal)"
                            else -> "Lock In ($currentGoal)"
                        }
                        activeService.updateNotification("$modeLabel · $mins:$secs remaining")
                    }
                }
            }
        }

        fun dismissOverlayOnly(context: Context) {
            val appContext = context.applicationContext
            try {
                val closeIntent = Intent(appContext, OverlayService::class.java).apply {
                    putExtra(OverlayService.INTENT_EXTRA_IS_CLOSE_WINDOW, true)
                }
                appContext.startService(closeIntent)
            } catch (_: Exception) {}
            try {
                appContext.stopService(Intent(appContext, OverlayService::class.java))
            } catch (_: Exception) {}
        }

        fun dismissOverlayAndReturnToApp(context: Context) {
            val appContext = context.applicationContext
            val now = System.currentTimeMillis()
            if (now < returnDebounceUntilMs) return
            returnDebounceUntilMs = now + 1000L
            dismissGraceUntilMs = now + 3000L
            lastProcessedEventTime = now

            // 1. Bring MainActivity to foreground while overlay is still alive (preserving Android 10+ BAL exemption)
            try {
                val launchIntent = Intent(appContext, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                appContext.startActivity(launchIntent)
            } catch (_: Exception) {
                try {
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    appContext.startActivity(homeIntent)
                } catch (_: Exception) {}
            }

            // 2. Dismiss the overlay view after initiating activity foregrounding
            dismissOverlayOnly(appContext)
        }
    }

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    @Volatile
    private var blockedPackages: Set<String> = emptySet()

    @Volatile
    private var isScheduled: Boolean = false

    @Volatile
    private var scheduleTimeRange: String? = null

    @Volatile
    private var isDegraded: Boolean = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        instance = this
        if (intent?.action == ACTION_STOP_SHIELD) {
            stopSelf()
            return START_NOT_STICKY
        }

        val packages = intent?.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES)
        if (packages != null) {
            blockedPackages = packages.toSet()
        }

        if (intent?.hasExtra(EXTRA_IS_SCHEDULED) == true) {
            isScheduled = intent.getBooleanExtra(EXTRA_IS_SCHEDULED, false)
            scheduleTimeRange = intent.getStringExtra(EXTRA_TIME_RANGE)
        }

        val notificationText = if (isScheduled && !scheduleTimeRange.isNullOrEmpty()) {
            "Scheduled Auto-Shield Active ($scheduleTimeRange)"
        } else {
            val mins = (currentRemainingSeconds / 60).toString().padStart(2, '0')
            val secs = (currentRemainingSeconds % 60).toString().padStart(2, '0')
            "Lock In ($currentGoal) · $mins:$secs remaining"
        }

        ensureOverlayBridgeRegistered(applicationContext)

        if (!isRunning) {
            isRunning = true
            lastProcessedEventTime = System.currentTimeMillis() - 500L
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildForegroundNotification(notificationText))
            startPollingLoop()
        } else {
            updateNotification(notificationText)
        }

        return START_STICKY
    }

    private fun startPollingLoop() {
        scope.launch {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            while (isRunning) {
                try {
                    val isInteractive = powerManager?.isInteractive ?: true
                    if (!isInteractive) {
                        delay(2000)
                        continue
                    }

                    val now = System.currentTimeMillis()
                    if (now < dismissGraceUntilMs) {
                        delay(400)
                        continue
                    }

                    if (currentIsMaximumFocus) {
                        if (!OverlayService.isRunning) {
                            triggerOverlay()
                        }
                        delay(500)
                        continue
                    }

                    if (!hasUsageStatsPermission()) {
                        if (!isDegraded) {
                            isDegraded = true
                            updateNotification("Shield Paused: Permission revoked. Tap to restore.")
                        }
                        delay(1000)
                        continue
                    }

                    if (usageStatsManager != null && blockedPackages.isNotEmpty()) {
                        val queryStart = maxOf(lastProcessedEventTime - 250L, now - 2500L)
                        val events = usageStatsManager.queryEvents(queryStart, now)
                        if (events != null) {
                            val event = UsageEvents.Event()
                            var resumedPackage: String? = null
                            var latestTimestamp = lastProcessedEventTime

                            while (events.hasNextEvent()) {
                                events.getNextEvent(event)
                                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED &&
                                    event.timeStamp > lastProcessedEventTime
                                ) {
                                    resumedPackage = event.packageName
                                    if (event.timeStamp > latestTimestamp) {
                                        latestTimestamp = event.timeStamp
                                    }
                                }
                            }

                            if (latestTimestamp > lastProcessedEventTime) {
                                lastProcessedEventTime = latestTimestamp
                            }

                            if (resumedPackage != null) {
                                if (resumedPackage != packageName &&
                                    blockedPackages.contains(resumedPackage)
                                ) {
                                    triggerOverlay()
                                } else if (!blockedPackages.contains(resumedPackage) &&
                                    OverlayService.isRunning &&
                                    !currentIsMaximumFocus
                                ) {
                                    withContext(Dispatchers.Main) {
                                        dismissOverlayOnly(applicationContext)
                                    }
                                }
                            }
                        }
                    }

                    if (isDegraded) {
                        isDegraded = false
                        val currentText = if (isScheduled && !scheduleTimeRange.isNullOrEmpty()) {
                            "Scheduled Auto-Shield Active ($scheduleTimeRange)"
                        } else {
                            val mins = (currentRemainingSeconds / 60).toString().padStart(2, '0')
                            val secs = (currentRemainingSeconds % 60).toString().padStart(2, '0')
                            "Lock In ($currentGoal) · $mins:$secs remaining"
                        }
                        updateNotification(currentText)
                    }
                } catch (securityEx: SecurityException) {
                    if (!isDegraded) {
                        isDegraded = true
                        updateNotification("Shield Paused: Permission revoked. Tap to restore.")
                    }
                } catch (_: Exception) {
                    // Suppress transient query errors and continue polling
                }
                delay(500)
            }
        }
    }

    private suspend fun triggerOverlay() {
        if (OverlayService.isRunning) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            if (!isDegraded) {
                isDegraded = true
                updateNotification("Shield Paused: Permission revoked. Tap to restore.")
            }
            return
        }

        withContext(Dispatchers.Main) {
            ensureOverlayBridgeRegistered(applicationContext)

            val windowSetup = WindowSetup.getInstance()
            windowSetup.width = FULL_COVER_SIZE
            windowSetup.height = FULL_COVER_SIZE
            windowSetup.isEnableDrag = false
            windowSetup.setGravityFromAlignment("center")
            windowSetup.setFlag("defaultFlag")
            windowSetup.overlayTitle = "Brainrot Shield Active"
            windowSetup.overlayContent = "Social feeds locked"

            val overlayIntent = Intent(this@FocusShieldService, OverlayService::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("startX", 0)
                putExtra("startY", 0)
            }
            startService(overlayIntent)

            updateOverlaySessionState(
                applicationContext,
                currentGoal,
                currentRemainingSeconds,
                currentIsBreak
            )
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

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Brainrot Shield",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors app usage and enforces focus locks during sessions"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(contentText: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, flags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Brainrot Shield Active")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(NOTIFICATION_ID, buildForegroundNotification(contentText))
    }

    override fun onDestroy() {
        isRunning = false
        if (instance === this) {
            instance = null
        }
        scope.cancel()

        dismissOverlayOnly(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)?.cancel(NOTIFICATION_ID)

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
