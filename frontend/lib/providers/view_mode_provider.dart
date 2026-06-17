import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 视图模式：feed（视频流）或 poster（海报墙）
enum ViewMode { feed, poster }

/// 播放模式：sequential（顺序）或 random（随机）
enum PlaybackMode { sequential, random }

final viewModeProvider = StateNotifierProvider<ViewModeNotifier, ViewMode>(
  (ref) => ViewModeNotifier(),
);

final playbackModeProvider = StateNotifierProvider<PlaybackModeNotifier, PlaybackMode>(
  (ref) => PlaybackModeNotifier(),
);

class ViewModeNotifier extends StateNotifier<ViewMode> {
  ViewModeNotifier() : super(ViewMode.feed);
  void toggle() => state = state == ViewMode.feed ? ViewMode.poster : ViewMode.feed;
  void set(ViewMode mode) => state = mode;
}

class PlaybackModeNotifier extends StateNotifier<PlaybackMode> {
  PlaybackModeNotifier() : super(PlaybackMode.sequential);
  void toggle() => state = state == PlaybackMode.sequential ? PlaybackMode.random : PlaybackMode.sequential;
}
