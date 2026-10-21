package com.bmrkiewicz.focusmaxxing.focusmaxxing.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
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

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_glanceable_dial).apply {
                setTextViewText(R.id.widget_today_minutes, "${todayMinutes}m")
                setTextViewText(R.id.widget_active_streak, "🔥 ${activeStreak}d")

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
