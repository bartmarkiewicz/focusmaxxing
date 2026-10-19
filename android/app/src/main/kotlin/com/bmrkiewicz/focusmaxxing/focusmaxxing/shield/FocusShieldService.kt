package com.bmrkiewicz.focusmaxxing.focusmaxxing.shield

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
import android.os.IBinder
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import androidx.core.app.NotificationCompat
import com.bmrkiewicz.focusmaxxing.focusmaxxing.MainActivity
import flutter.overlay.window.flutter_overlay_window.OverlayService
import flutter.overlay.window.flutter_overlay_window.WindowSetup
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

        @Volatile
        var isRunning: Boolean = false
            private set
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
            "Focus session in progress"
        }

        if (!isRunning) {
            isRunning = true
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

                    if (!hasUsageStatsPermission()) {
                        if (!isDegraded) {
                            isDegraded = true
                            updateNotification("Shield Paused: Permission revoked. Tap to restore.")
                        }
                        delay(1000)
                        continue
                    }

                    if (usageStatsManager != null && blockedPackages.isNotEmpty()) {
                        val now = System.currentTimeMillis()
                        val events = usageStatsManager.queryEvents(now - 2000, now)
                        if (events != null) {
                            val event = UsageEvents.Event()
                            var resumedPackage: String? = null

                            while (events.hasNextEvent()) {
                                events.getNextEvent(event)
                                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                                    resumedPackage = event.packageName
                                }
                            }

                            if (resumedPackage != null &&
                                resumedPackage != packageName &&
                                blockedPackages.contains(resumedPackage)
                            ) {
                                triggerOverlay()
                            }
                        }
                    }

                    if (isDegraded) {
                        isDegraded = false
                        val currentText = if (isScheduled && !scheduleTimeRange.isNullOrEmpty()) {
                            "Scheduled Auto-Shield Active ($scheduleTimeRange)"
                        } else {
                            "Focus session in progress"
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
            val windowSetup = WindowSetup.getInstance()
            windowSetup.width = -1
            windowSetup.height = -1
            windowSetup.isEnableDrag = false
            windowSetup.setGravityFromAlignment("center")
            windowSetup.setFlag("defaultFlag")
            windowSetup.overlayTitle = "Brainrot Shield Active"
            windowSetup.overlayContent = "Social feeds locked"

            val overlayIntent = Intent(this@FocusShieldService, OverlayService::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("startX", -6)
                putExtra("startY", -6)
            }
            startService(overlayIntent)
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
        scope.cancel()

        if (OverlayService.isRunning) {
            stopService(Intent(this, OverlayService::class.java))
        }

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
