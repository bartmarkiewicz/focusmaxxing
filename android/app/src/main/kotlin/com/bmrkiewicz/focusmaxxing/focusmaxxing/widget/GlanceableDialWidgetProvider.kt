package com.bmrkiewicz.focusmaxxing.focusmaxxing.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.bmrkiewicz.focusmaxxing.focusmaxxing.MainActivity
import com.bmrkiewicz.focusmaxxing.focusmaxxing.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class GlanceableDialWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val allPrefs = widgetData.all
        val todayMinutes = (allPrefs["today_minutes"] as? Number)?.toInt() ?: 0
        val activeStreak = (allPrefs["active_streak"] as? Number)?.toInt() ?: 0
        val isRunning = (allPrefs["is_running"] as? Boolean) ?: false
        val targetEndTimeEpochMs = (allPrefs["target_end_epoch_ms"] as? Number)?.toLong() ?: 0L
        val taskGoal = (allPrefs["task_goal"] as? String)?.trim().orEmpty()

        val remainingMs = targetEndTimeEpochMs - System.currentTimeMillis()
        val isCurrentlyActive = isRunning && remainingMs > 0L

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_glanceable_dial).apply {
                setTextViewText(R.id.widget_active_streak, "🔥 ${activeStreak}d")

                if (isCurrentlyActive) {
                    setViewVisibility(R.id.widget_idle_container, View.GONE)
                    setViewVisibility(R.id.widget_active_container, View.VISIBLE)

                    val baseRealtime = SystemClock.elapsedRealtime() + remainingMs
                    setChronometer(R.id.widget_chronometer, baseRealtime, null, true)
                    setChronometerCountDown(R.id.widget_chronometer, true)

                    val displayGoal = if (taskGoal.isNotEmpty()) taskGoal else context.getString(R.string.widget_focusing_now)
                    setTextViewText(R.id.widget_task_goal, displayGoal)
                    setTextViewText(R.id.widget_button_lockin, context.getString(R.string.widget_btn_focusing))
                } else {
                    setViewVisibility(R.id.widget_idle_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_active_container, View.GONE)

                    setChronometer(R.id.widget_chronometer, 0L, null, false)
                    setTextViewText(R.id.widget_today_minutes, "${todayMinutes}m")
                    setTextViewText(R.id.widget_button_lockin, context.getString(R.string.widget_btn_lockin))
                }

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("focusmaxxing://lockin")
                )
                setOnClickPendingIntent(R.id.widget_glanceable_dial_root, pendingIntent)
                setOnClickPendingIntent(R.id.widget_button_lockin, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
