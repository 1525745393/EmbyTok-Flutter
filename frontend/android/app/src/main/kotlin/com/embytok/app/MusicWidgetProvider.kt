package com.embytok.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 桌面音乐 Widget Provider。
 *
 * 由 Dart 端 HomeWidget.updateWidget 触发 onUpdate；
 * 点击 Widget 主体打开 App，按钮走 home_widget 的交互（播放状态由 Dart 渲染）。
 */
class MusicWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.os.Bundle
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.music_widget)
            val title = widgetData.getString("title", "未在播放")
            views.setTextViewText(R.id.widget_title, title)

            // 点击 Widget 打开 App
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, null
            )
            views.setOnClickPendingIntent(R.id.widget_title, launchIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
