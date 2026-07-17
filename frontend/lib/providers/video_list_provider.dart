// 视频列表 Provider 统一入口
//
// 拆分说明（原 962 行按职责拆分）：
// - [video_list_state.dart]         VideoListState 状态模型
// - [video_list_notifier.dart]      VideoListNotifier 核心业务逻辑 + 主 Provider
// - [playback_list_provider.dart]   全局播放列表（完全独立）
// - 本文件：派生 Provider + 统一导出
//
// 导入方式不变：import 'package:embbytok/providers/video_list_provider.dart'
// 所有原有符号（VideoListState、videoListProvider、filteredVideoListProvider 等）
// 均通过本文件重新导出，保持向后兼容。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../utils/app_preferences.dart' show OrientationMode;
import 'app_preferences_providers.dart';
import 'playback_list_provider.dart';
import 'video_list_notifier.dart';
import 'video_list_state.dart';

// ==================== 状态与 Notifier 重新导出 ====================

export 'video_list_state.dart';
export 'video_list_notifier.dart';
export 'playback_list_provider.dart';

// ==================== 方向过滤的派生 Provider ====================

/// 根据屏幕方向模式过滤后的视频列表
///
/// - [OrientationMode.vertical] 仅保留竖屏视频
/// - [OrientationMode.horizontal] 仅保留横屏视频
/// - [OrientationMode.both] 返回全部视频
final filteredVideoListProvider = Provider<List<MediaItem>>((ref) {
  final videoState = ref.watch(videoListProvider);
  final orientationMode = ref.watch(orientationModeProvider);

  // 如果是加载中或错误状态，直接返回原列表
  if (videoState.isLoading || videoState.error != null) {
    return videoState.items;
  }

  // 根据方向模式过滤
  return videoState.items.where((item) {
    return switch (orientationMode) {
      OrientationMode.vertical => item.isPortrait,
      OrientationMode.horizontal => item.isLandscape,
      OrientationMode.both => true, // 显示全部
    };
  }).toList();
});

// ==================== 网格模式过滤与排序后的派生 Provider ====================

/// 网格模式下的视频列表
///
/// 说明：排序和搜索已通过 Emby 服务端 API 实现，
/// 这里直接返回 videoListProvider 的数据。
/// 保留此 provider 是为了保持 API 一致性，
/// 未来如果需要客户端额外过滤可以在这里添加。
final gridFilteredVideoListProvider = Provider<List<MediaItem>>((ref) {
  final videoState = ref.watch(videoListProvider);
  return videoState.items;
});

/// 网格模式下点击选中的视频 ID
///
/// 已废弃：网格 → 视频流的跳转现在通过 GoRouter `?initialId=<itemId>` 透传。
/// 保留此 provider 是为了与历史代码兼容（部分测试仍可能引用）。
/// 后续 PR 将彻底删除。
@Deprecated('使用 GoRouter ?initialId= 透传，不再需要此 provider')
final gridSelectedItemIdProvider = StateProvider<String?>((ref) => null);

/// 从 feed 切回网格时需要定位到的视频 ID
///
/// 已废弃：feed → grid 的回显定位现在由 currentPlayingIdProvider 驱动。
/// PosterGridView 监听 currentPlayingIdProvider 后自行滚动。
@Deprecated('使用 currentPlayingIdProvider，不再需要此 provider')
final feedToGridJumpItemIdProvider = StateProvider<String?>((ref) => null);
