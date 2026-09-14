package com.embytok.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 桌面音乐 Widget Provider。
 *
 * 由 Dart 端 HomeWidget.updateWidget 触发 onUpdate；
 * 点击 Widget 打开 App。
 */
class MusicWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.music_widget)
            val title = widgetData.getString("title", "未在播放") ?: "未在播放"
            views.setTextViewText(R.id.widget_title, title)

            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, null
            )
            views.setOnClickPendingIntent(R.id.widget_title, launchIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
