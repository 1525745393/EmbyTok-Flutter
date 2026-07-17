// 全局播放列表 Provider
//
// 独立拆分原因：
// - 全局播放列表与视频列表加载逻辑完全无关
// - 是一个独立的跨页面数据传递机制
// - 可以在任何页面设置/读取，不依赖 VideoListNotifier

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// 全局播放列表状态：用于支持从任意页面跳转到播放页时传递视频列表
///
/// 在跳转到播放页之前，各页面应设置此 Provider 的值
class PlaybackListState {
  final List<MediaItem> items;
  final String? currentItemId;

  const PlaybackListState({
    this.items = const [],
    this.currentItemId,
  });

  PlaybackListState copyWith({
    List<MediaItem>? items,
    String? currentItemId,
  }) {
    return PlaybackListState(
      items: items ?? this.items,
      currentItemId: currentItemId ?? this.currentItemId,
    );
  }
}

/// 全局播放列表 Notifier：用于设置当前页面的视频列表
final playbackListProvider =
    StateNotifierProvider<PlaybackListNotifier, PlaybackListState>((ref) {
  return PlaybackListNotifier();
});

class PlaybackListNotifier extends StateNotifier<PlaybackListState> {
  PlaybackListNotifier() : super(const PlaybackListState());

  /// 设置播放列表
  void setPlaybackList(List<MediaItem> items, String currentItemId) {
    state = PlaybackListState(items: items, currentItemId: currentItemId);
  }

  /// 清空播放列表
  void clear() {
    state = const PlaybackListState();
  }
}
