package com.meditatorapp.meditator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    val streak = (call.argument<Any>("streak_count") as? Number)?.toInt() ?: 0
                    val quote = call.argument<String>("daily_quote") ?: ""
                    val totalMinutes =
                        (call.argument<Any>("total_minutes") as? Number)?.toInt() ?: 0

                    getSharedPreferences(MeditatorWidget.PREFS_NAME, MODE_PRIVATE)
                        .edit()
                        .putInt(MeditatorWidget.KEY_STREAK, streak)
                        .putString(MeditatorWidget.KEY_QUOTE, quote)
                        .putInt(MeditatorWidget.KEY_TOTAL_MINUTES, totalMinutes)
                        .apply()

                    MeditatorWidget.requestUpdateAll(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val WIDGET_CHANNEL = "com.meditatorapp.meditator/widget"
    }
}
