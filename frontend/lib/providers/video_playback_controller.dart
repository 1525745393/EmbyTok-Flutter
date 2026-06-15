// 视频播放控制器：当前播放条目、播放位置、倍速、字幕等

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

// 当前正在播放的媒体条目
final currentPlayingItemProvider = StateProvider<MediaItem?>((ref) => null);

// 当前播放位置（秒）
final currentPositionProvider = StateProvider<Duration>((ref) => Duration.zero);

// 是否正在播放
final isPlayingProvider = StateProvider<bool>((ref) => false);

// 播放倍速：1.0 / 1.25 / 1.5 / 2.0
final playbackRateProvider = StateProvider<double>((ref) => 1.0);

// 当前选中的字幕（字幕语言或轨道 ID，null 表示关闭）
final selectedSubtitleProvider = StateProvider<String?>((ref) => null);
