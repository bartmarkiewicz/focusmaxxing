package com.bmrkiewicz.focusmaxxing.focusmaxxing.shield

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import flutter.overlay.window.flutter_overlay_window.OverlayService
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class AutoShieldAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_START_AUTO_SHIELD = "com.bmrkiewicz.focusmaxxing.START_AUTO_SHIELD"
        const val ACTION_STOP_AUTO_SHIELD = "com.bmrkiewicz.focusmaxxing.STOP_AUTO_SHIELD"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        when (action) {
            ACTION_START_AUTO_SHIELD -> {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

                // Check active weekdays (Dart DateTime: Mon=1 ... Sun=7)
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

                // In Flutter SharedPreferences, StringList is stored as a JSON array string prefixed with "flutter."
                val activeDaysRaw = prefs.getString("flutter.scheduled_auto_shield_active_days", null)
                if (activeDaysRaw != null) {
                    try {
                        val arr = JSONArray(activeDaysRaw)
                        val days = mutableListOf<String>()
                        for (i in 0 until arr.length()) {
                            days.add(arr.getString(i))
                        }
                        if (!days.contains(dartWeekday.toString())) {
                            return
                        }
                    } catch (_: Exception) {}
                }

                val packagesRaw = prefs.getString("flutter.scheduled_auto_shield_packages", null)
                val blockedPackages = ArrayList<String>()
                if (packagesRaw != null) {
                    try {
                        val arr = JSONArray(packagesRaw)
                        for (i in 0 until arr.length()) {
                            blockedPackages.add(arr.getString(i))
                        }
                    } catch (_: Exception) {}
                }

                var timeRangeText = "09:00 - 17:00"
                val configRaw = prefs.getString("flutter.scheduled_auto_shield_config", null)
                if (configRaw != null) {
                    try {
                        val obj = JSONObject(configRaw)
                        val sH = obj.optInt("startHour", 9)
                        val sM = obj.optInt("startMinute", 0)
                        val eH = obj.optInt("endHour", 17)
                        val eM = obj.optInt("endMinute", 0)
                        timeRangeText = String.format("%02d:%02d - %02d:%02d", sH, sM, eH, eM)
                    } catch (_: Exception) {}
                }

                val serviceIntent = Intent(context, FocusShieldService::class.java).apply {
                    putStringArrayListExtra(FocusShieldService.EXTRA_BLOCKED_PACKAGES, blockedPackages)
                    putExtra(FocusShieldService.EXTRA_TIME_RANGE, timeRangeText)
                    putExtra(FocusShieldService.EXTRA_IS_SCHEDULED, true)
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            }

            ACTION_STOP_AUTO_SHIELD -> {
                context.stopService(Intent(context, FocusShieldService::class.java))
                if (OverlayService.isRunning) {
                    context.stopService(Intent(context, OverlayService::class.java))
                }
            }
        }
    }
}
