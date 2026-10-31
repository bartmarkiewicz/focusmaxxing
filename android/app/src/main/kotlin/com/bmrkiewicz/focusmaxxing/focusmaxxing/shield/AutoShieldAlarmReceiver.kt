package com.bmrkiewicz.focusmaxxing.focusmaxxing.shield

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class AutoShieldAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_START_AUTO_SHIELD = "com.bmrkiewicz.focusmaxxing.START_AUTO_SHIELD"
        const val ACTION_STOP_AUTO_SHIELD = "com.bmrkiewicz.focusmaxxing.STOP_AUTO_SHIELD"
        const val START_ALARM_ID = 2001
        const val END_ALARM_ID = 2002

        fun parseFlutterStringList(raw: String?): List<String>? {
            if (raw.isNullOrBlank()) return null
            val bracketIndex = raw.indexOf('[')
            if (bracketIndex < 0) return null
            return try {
                val arr = JSONArray(raw.substring(bracketIndex))
                val items = ArrayList<String>(arr.length())
                for (i in 0 until arr.length()) {
                    items.add(arr.getString(i))
                }
                items
            } catch (_: Exception) {
                null
            }
        }

        fun getFlutterStringList(context: Context, key: String): List<String>? {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            try {
                val set = prefs.getStringSet(key, null)
                if (set != null) return set.toList()
            } catch (_: Exception) {}

            try {
                val raw = prefs.getString(key, null)
                return parseFlutterStringList(raw)
            } catch (_: Exception) {}

            return null
        }

        fun scheduleAlarm(context: Context, isStart: Boolean, hour: Int, minute: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val action = if (isStart) ACTION_START_AUTO_SHIELD else ACTION_STOP_AUTO_SHIELD
            val requestCode = if (isStart) START_ALARM_ID else END_ALARM_ID
            val intent = Intent(context, AutoShieldAlarmReceiver::class.java).apply {
                this.action = action
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val now = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (target.before(now)) {
                target.add(Calendar.DAY_OF_YEAR, 1)
            }

            val triggerTimeMs = target.timeInMillis
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTimeMs,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTimeMs,
                            pendingIntent
                        )
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTimeMs,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerTimeMs,
                        pendingIntent
                    )
                }
            } catch (_: SecurityException) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMs,
                    pendingIntent
                )
            } catch (_: Exception) {}
        }

        fun cancelAlarms(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val startIntent = Intent(context, AutoShieldAlarmReceiver::class.java).apply {
                action = ACTION_START_AUTO_SHIELD
            }
            val startPending = PendingIntent.getBroadcast(
                context,
                START_ALARM_ID,
                startIntent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (startPending != null) {
                alarmManager.cancel(startPending)
                startPending.cancel()
            }

            val endIntent = Intent(context, AutoShieldAlarmReceiver::class.java).apply {
                action = ACTION_STOP_AUTO_SHIELD
            }
            val endPending = PendingIntent.getBroadcast(
                context,
                END_ALARM_ID,
                endIntent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (endPending != null) {
                alarmManager.cancel(endPending)
                endPending.cancel()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        when (action) {
            ACTION_START_AUTO_SHIELD -> {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

                val calendar = Calendar.getInstance()
                val dartWeekday = when (calendar.get(Calendar.DAY_OF_WEEK)) {
                    Calendar.MONDAY -> 1
                    Calendar.TUESDAY -> 2
                    Calendar.WEDNESDAY -> 3
                    Calendar.THURSDAY -> 4
                    Calendar.FRIDAY -> 5
                    Calendar.SATURDAY -> 6
                    Calendar.SUNDAY -> 7
                    else -> 1
                }

                var startHour = 9
                var startMinute = 0
                var endHour = 17
                var endMinute = 0
                var isEnabled = true
                var timeRangeText = "09:00 - 17:00"

                val configRaw = prefs.getString("flutter.scheduled_auto_shield_config", null)
                if (configRaw != null) {
                    try {
                        val obj = JSONObject(configRaw)
                        isEnabled = obj.optBoolean("isEnabled", true)
                        startHour = obj.optInt("startHour", 9)
                        startMinute = obj.optInt("startMinute", 0)
                        endHour = obj.optInt("endHour", 17)
                        endMinute = obj.optInt("endMinute", 0)
                        timeRangeText = String.format("%02d:%02d - %02d:%02d", startHour, startMinute, endHour, endMinute)
                    } catch (_: Exception) {}
                }

                if (!isEnabled) {
                    return
                }

                scheduleAlarm(context, true, startHour, startMinute)

                val activeDays = getFlutterStringList(context, "flutter.scheduled_auto_shield_active_days")
                    ?: listOf("1", "2", "3", "4", "5")
                if (!activeDays.contains(dartWeekday.toString())) {
                    return
                }

                val parsedPackages = getFlutterStringList(context, "flutter.scheduled_auto_shield_packages") ?: emptyList()
                val blockedPackages = ArrayList<String>(parsedPackages)

                val serviceIntent = Intent(context, FocusShieldService::class.java).apply {
                    putStringArrayListExtra(FocusShieldService.EXTRA_BLOCKED_PACKAGES, blockedPackages)
                    putExtra(FocusShieldService.EXTRA_TIME_RANGE, timeRangeText)
                    putExtra(FocusShieldService.EXTRA_IS_SCHEDULED, true)
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            }

            ACTION_STOP_AUTO_SHIELD -> {
                val active = FocusShieldService.instance
                val isManualSessionActive = active != null &&
                    !active.isScheduled &&
                    (FocusShieldService.targetEndTimeEpochMs > System.currentTimeMillis() || FocusShieldService.currentRemainingSeconds > 0)

                if (isManualSessionActive) {
                    FocusShieldService.isScheduledBaseline = false
                    FocusShieldService.scheduledBaselineRange = null
                } else {
                    FocusShieldService.isScheduledBaseline = false
                    FocusShieldService.scheduledBaselineRange = null
                    FocusShieldService.currentIsMaximumFocus = false
                    FocusShieldService.currentIsPaused = false
                    FocusShieldService.targetEndTimeEpochMs = 0L
                    if (FocusShieldService.isRunning) {
                        context.stopService(Intent(context, FocusShieldService::class.java))
                    }
                    FocusShieldService.dismissOverlayOnly(context)
                }

                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val configRaw = prefs.getString("flutter.scheduled_auto_shield_config", null)
                if (configRaw != null) {
                    try {
                        val obj = JSONObject(configRaw)
                        if (obj.optBoolean("isEnabled", true)) {
                            val endHour = obj.optInt("endHour", 17)
                            val endMinute = obj.optInt("endMinute", 0)
                            scheduleAlarm(context, false, endHour, endMinute)
                        }
                    } catch (_: Exception) {}
                }
            }

            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val configRaw = prefs.getString("flutter.scheduled_auto_shield_config", null) ?: return
                try {
                    val obj = JSONObject(configRaw)
                    if (obj.optBoolean("isEnabled", true)) {
                        val sH = obj.optInt("startHour", 9)
                        val sM = obj.optInt("startMinute", 0)
                        val eH = obj.optInt("endHour", 17)
                        val eM = obj.optInt("endMinute", 0)
                        scheduleAlarm(context, true, sH, sM)
                        scheduleAlarm(context, false, eH, eM)
                    }
                } catch (_: Exception) {}
            }
        }
    }
}
