package com.meditatorapp.meditator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MeditatorWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "meditator_widget_prefs"
        const val KEY_STREAK = "streak_count"
        const val KEY_QUOTE = "daily_quote"
        const val KEY_TOTAL_MINUTES = "total_minutes"

        private const val DEFAULT_QUOTE = "Момент тишины — лучший подарок себе."

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val streak = prefs.getInt(KEY_STREAK, 0)
            val quote = prefs.getString(KEY_QUOTE, null)?.trim().orEmpty()

            val views = RemoteViews(context.packageName, R.layout.meditator_widget)

            views.setTextViewText(R.id.widget_streak, "🔥 Серия: $streak дней")
            views.setTextViewText(
                R.id.widget_quote,
                if (quote.isNotEmpty()) quote else DEFAULT_QUOTE,
            )

            val startIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val startPendingIntent = PendingIntent.getActivity(
                context,
                REQUEST_CODE_START,
                startIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_start_button, startPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun requestUpdateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, MeditatorWidget::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            val intent = Intent(context, MeditatorWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }

        private const val REQUEST_CODE_START = 1001
    }
}
