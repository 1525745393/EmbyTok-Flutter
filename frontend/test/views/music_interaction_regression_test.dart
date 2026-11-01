/// 音乐库 UI 交互回归测试
///
/// 背景（本分片 UI 审查发现）：
/// 1. 首页下拉刷新/错误重试/空态「刷新音乐库」都调用 `loadTab(home)`，
///    而 provider 中 `loadTab(home)` 为空操作（仅复位 isLoading），导致首页
///    下拉刷新无效果、初始加载失败后「重试」按钮无效。修复为统一走
///    `_refreshCurrentTab()`：首页路由到 `loadHomeData(force:true)` + 清精选缓存；
///    同时移除 home_tab.dart 内层冗余 RefreshIndicator（它会拦截外层手势）。
/// 2. `_playRecentPlayback` 对未在分页已加载页（默认前 200 首）内的歌曲直接
///    弹「该歌曲已不在当前列表中」，无法播放；与 `_playPin` 同改为按 id 构造
///    最小 AudioSong 入队。
///
/// 本文件用例固定上述两条行为，防止回退。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/audio_models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/providers/recent_playbacks_provider.dart';
import 'package:embytok_flutter/views/synology_music_view.dart';

class _FakeAuthNotifier extends SynologyAuthNotifier {
  _FakeAuthNotifier(super.ref) : super() {
    state = const SynologyAuthState(
      isLoggedIn: true,
      serverUrl: 'http://192.168.1.6:5000',
      account: 'tester',
      sid: 'mock-sid',
    );
  }
}

/// 假音乐库：不发网络请求；预置一首与最近播放记录 id 不同的歌曲，
/// 使 `_isEmptyForTab(home)` 为 false（首页 Tab 正常渲染 body，不走错误屏），
/// 同时让最近播放记录匹配不到已加载歌曲、走回退构造分支。
class _FakeMusicNotifier extends SynologyMusicNotifier {
  _FakeMusicNotifier(super.ref) : super() {
    state = const SynologyMusicState(
      songs: [
        AudioSong(
          id: 'music_loaded_1',
          title: '已加载歌曲',
          tag: AudioSongTag(artist: '已加载歌手'),
        ),
      ],
    );
  }

  @override
  Future<void> loadTab(SynologyMusicTab tab, {bool force = false}) async {}

  @override
  Future<void> loadHomeData({bool force = false}) async {}
}

/// 假播放 Notifier：记录 playQueue 入队内容，不触发真实播放器。
class _RecordingPlaybackNotifier extends SynologyPlaybackNotifier {
  _RecordingPlaybackNotifier(super.ref) : super();

  final List<List<AudioSong>> playedQueues = [];

  @override
  Future<void> playQueue(List<AudioSong> queue, int index) async {
    playedQueues.add(List.of(queue));
  }
}

/// 假最近播放：固定一条歌曲记录（id 不在已加载列表内）。
class _FakeRecentNotifier extends RecentPlaybacksNotifier {
  _FakeRecentNotifier() : super() {
    state = const [
      RecentPlayback(
        mediaId: 'music_offline_999',
        mediaType: RecentPlaybackType.song,
        title: '离线收藏歌曲',
        subtitle: '某歌手 - 某专辑',
        lastPlayTime: 1,
      ),
    ];
  }
}

/// 在 override 工厂里用 ref 构造 recording notifier，同时持有引用用于断言。
class _Harness {
  _RecordingPlaybackNotifier? playback;

  Widget build() {
    return ProviderScope(
      overrides: [
        synologyAuthProvider.overrideWith((ref) => _FakeAuthNotifier(ref)),
        synologyMusicProvider.overrideWith((ref) => _FakeMusicNotifier(ref)),
        synologyPlaybackProvider
            .overrideWith((ref) => playback = _RecordingPlaybackNotifier(ref)),
        recentPlaybacksProvider
            .overrideWith((ref) => _FakeRecentNotifier()),
      ],
      child: const MaterialApp(home: SynologyMusicView()),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('首页只挂一个 RefreshIndicator（内层冗余已移除）', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 修复前：外层 + home_tab 内层两个 RefreshIndicator，内层拦截手势导致
    // 首页下拉刷新退化为 loadTab(home) 空操作。修复后只剩外层一个。
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('最近播放点击：未加载分页内歌曲按 id 构造入队，不误报不在列表',
      (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 最近播放卡片标题可见
    expect(find.text('离线收藏歌曲'), findsOneWidget);

    await tester.tap(find.text('离线收藏歌曲'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 应触发一次 playQueue，且入队歌曲即该记录（按 id 回退构造）
    expect(harness.playback!.playedQueues.length, 1);
    final queued = harness.playback!.playedQueues.single;
    expect(queued, hasLength(1));
    expect(queued.single.id, 'music_offline_999');
    expect(queued.single.title, '离线收藏歌曲');

    // 不应出现「该歌曲已不在当前列表中」的错误提示
    expect(find.text('该歌曲已不在当前列表中'), findsNothing);
  });
}
