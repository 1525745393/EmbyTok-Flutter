// 桌面音乐 Widget 更新（PRD #11）
//
// 播放状态变化时调 updateMusicWidget，Android 桌面小组件同步曲名。
// 非 Android 平台（iOS/无 home_widget）静默跳过。

import 'package:home_widget/home_widget.dart';

/// 把当前播放曲名推到桌面 Widget
Future<void> updateMusicWidget(String title) async {
  try {
    await HomeWidget.saveWidgetData<String>('title', title.isEmpty ? '未在播放' : title);
    await HomeWidget.updateWidget(
      name: 'MusicWidgetProvider',
      androidName: 'MusicWidgetProvider',
    );
  } catch (_) {
    // 不支持的平台静默
  }
}
