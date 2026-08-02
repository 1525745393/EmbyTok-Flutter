// VideoGridView 空状态引导测试
//
// 覆盖 spec "视频网格空状态主动引导" 的两个场景：
// 1. 未配置媒体库（videoState.items 为空）→ 显示"选择媒体库" OutlinedButton
// 2. 筛选无结果（items 非空但 displayItems 为空）→ 仅文字提示，不显示按钮
//
// 测试策略：
// - override videoListProvider：用 _FakeVideoListNotifier 注入预设 VideoListState
// - override filteredVideoListProvider：直接注入 displayItems，隔离过滤逻辑
// - override cachedMediaRepositoryProvider：VideoListNotifier 构造函数会
//   ref.read(cachedMediaRepositoryProvider)，需提供 Mock 避免构建真实仓库链
// - 不 override authProvider：默认未认证，libraryListProvider 返回空列表，
//   selectedLibraryIdsProvider 保持空，_loadVideos 不会触发 refresh

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/providers/providers.dart';
import 'package:embytok_flutter/repositories/cached_media_repository.dart';
import 'package:embytok_flutter/views/video_grid_view.dart';

/// CachedMediaRepository 的 Mock 实现
///
/// VideoListNotifier 构造函数通过 ref.read(cachedMediaRepositoryProvider)
/// 获取仓库实例，测试中用 Mock 避免构建真实的 EmbyRepository 网络链。
class _MockCachedMediaRepository extends Mock implements CachedMediaRepository {}

/// 测试用 VideoListNotifier：继承真实 Notifier，构造后直接注入预设状态
///
/// 注意：super(ref) 会执行父类构造函数的 ref.listen 注册（监听
/// selectedLibraryIdsProvider 等），但这些监听器只在对应 provider 状态
/// 变化时触发回调，测试中这些 provider 保持默认值不变，不会触发 refresh。
class _FakeVideoListNotifier extends VideoListNotifier {
  _FakeVideoListNotifier(Ref ref, VideoListState initialState) : super(ref) {
    state = initialState;
  }
}

void main() {
  late _MockCachedMediaRepository mockCachedRepo;

  setUp(() {
    mockCachedRepo = _MockCachedMediaRepository();
  });

  // 构建带 overrides 的测试 Widget
  Widget buildApp({
    required VideoListState videoState,
    required List<MediaItem> displayItems,
  }) {
    return ProviderScope(
      overrides: [
        cachedMediaRepositoryProvider.overrideWithValue(mockCachedRepo),
        videoListProvider.overrideWith(
          (ref) => _FakeVideoListNotifier(ref, videoState),
        ),
        filteredVideoListProvider.overrideWith((ref) => displayItems),
      ],
      child: const MaterialApp(home: VideoGridView()),
    );
  }

  group('VideoGridView 空状态引导', () {
    testWidgets('未配置媒体库时显示"选择媒体库"按钮', (tester) async {
      // videoState.items 为空（未配置媒体库或媒体库为空）
      await tester.pumpWidget(buildApp(
        videoState: const VideoListState(),
        displayItems: const <MediaItem>[],
      ));
      await tester.pumpAndSettle();

      // 应显示引导文字 + OutlinedButton
      expect(find.text('暂无视频，请选择媒体库'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('选择媒体库'), findsOneWidget);
      // 不应显示筛选无结果的提示
      expect(find.text('没有符合筛选条件的视频'), findsNothing);
    });

    testWidgets('有数据但筛选无结果时仅文字提示不显示按钮', (tester) async {
      // videoState.items 非空，但 displayItems 为空（筛选无结果）
      final item = MediaItem(id: 'v1', title: '测试视频', type: 'Movie');
      await tester.pumpWidget(buildApp(
        videoState: VideoListState(items: [item]),
        displayItems: const <MediaItem>[],
      ));
      await tester.pumpAndSettle();

      // 应仅显示筛选无结果文字，不显示按钮
      expect(find.text('没有符合筛选条件的视频'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('选择媒体库'), findsNothing);
      // 不应显示未配置媒体库的引导文字
      expect(find.text('暂无视频，请选择媒体库'), findsNothing);
    });
  });
}
