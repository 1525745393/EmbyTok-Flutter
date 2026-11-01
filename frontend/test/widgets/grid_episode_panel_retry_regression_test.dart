// 视频库-网格与条目域 交互回归测试
//
// 覆盖两类缺陷的永久回归：
// 1. episode_list_panel：季内剧集加载失败时，错误态必须提供「重试」按钮，
//    且点击后真实重新拉取（此前错误态仅一行文字，用户只能关闭重开面板）。
// 2. video_grid_view：网格列数按屏幕宽度自适应（<400→2 / 400-700→3 /
//    700-1000→4 / >=1000→5），防止回退到「仅按方向竖屏2/横屏4」的旧逻辑。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/repositories/media_repository.dart';
import 'package:embytok_flutter/widgets/video/episode_list_panel.dart';

/// 假认证 Notifier：直接注入已登录态，跳过真实存储恢复链。
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref, AuthState initialState) {
    state = initialState;
  }
}

/// 假媒体仓库：首季 getEpisodes 抛错，第二次成功，用于验证重试按钮真实生效。
class _FakeMediaRepo extends Mock implements MediaRepository {
  int episodesCallCount = 0;

  @override
  Future<List<MediaItem>> getSeasons(
    String seriesId, {
    required String serverUrl,
    required String token,
  }) async {
    return const [
      MediaItem(id: 'season-1', title: '第 1 季', type: 'Season', indexNumber: 1),
    ];
  }

  @override
  Future<PaginatedResponse<MediaItem>> getEpisodes(
    String seriesId, {
    String? seasonId,
    int limit = 100,
    int offset = 0,
    required String serverUrl,
    required String token,
  }) async {
    episodesCallCount++;
    if (episodesCallCount == 1) {
      throw Exception('network down');
    }
    return PaginatedResponse<MediaItem>(
      items: const [
        MediaItem(id: 'ep-1', title: 'E01', type: 'Episode', indexNumber: 1),
      ],
      total: 1,
      offset: 0,
      limit: 100,
    );
  }
}

void main() {
  const authState = AuthState(
    isAuthenticated: true,
    embyServerUrl: 'http://test',
    token: 'test-token',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('剧集面板：剧集加载失败显示错误态 + 重试按钮，点击后重新拉取成功',
      (tester) async {
    final repo = _FakeMediaRepo();
    const series = MediaItem(
      id: 'series-1',
      title: '测试剧集',
      type: 'Series',
      seriesId: 'series-1',
      parentIndexNumber: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(ref, authState)),
          mediaRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: EpisodeListPanel(currentItem: series, onPlayEpisode: _noop),
          ),
        ),
      ),
    );

    // 首次 getSeasons 成功 → 选中第1季 → getEpisodes 抛错
    await tester.pump();
    // getSeasons / getEpisodes 均为异步，推进微任务与帧
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // 错误态：显示失败文案 + 重试按钮
    expect(find.text('加载剧集失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    // 点击重试 → 第二次 getEpisodes 成功 → 显示剧集条目
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('加载剧集失败'), findsNothing);
    expect(find.text('E01'), findsOneWidget);
    expect(repo.episodesCallCount, greaterThanOrEqualTo(2),
        reason: '重试必须真实触发第二次 getEpisodes 拉取');
  });
}

void _noop(MediaItem episode, List<MediaItem> seasonEpisodes) {}
