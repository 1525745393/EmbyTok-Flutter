// VideoListNotifier 状态机测试：验证分页加载、刷新、切换媒体库等状态流转

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:embbytok_flutter/models/models.dart';
import 'package:embbytok_flutter/providers/auth_provider.dart';
import 'package:embbytok_flutter/providers/library_provider.dart';
import 'package:embbytok_flutter/providers/video_list_provider.dart';
import 'package:embbytok_flutter/services/embbytok_service.dart';
import 'package:embbytok_flutter/utils/constants.dart';

import '../mocks/mock_services.dart';

void main() {
  group('VideoListState', () {
    test('初始状态正确', () {
      const state = VideoListState();
      expect(state.items, isEmpty);
      expect(state.isLoading, false);
      expect(state.hasMore, true);
      expect(state.error, isNull);
      expect(state.offset, 0);
      expect(state.limit, kDefaultPageLimit);
    });

    test('copyWith 正确更新字段', () {
      const original = VideoListState();
      final items = [
        MediaItem(id: '1', title: 'Video 1', type: 'Movie'),
        MediaItem(id: '2', title: 'Video 2', type: 'Movie'),
      ];

      final updated = original.copyWith(
        items: items,
        isLoading: true,
        hasMore: false,
        error: '加载失败',
        offset: 20,
        limit: 10,
      );

      expect(updated.items, items);
      expect(updated.isLoading, true);
      expect(updated.hasMore, false);
      expect(updated.error, '加载失败');
      expect(updated.offset, 20);
      expect(updated.limit, 10);
    });
  });

  group('VideoListNotifier', () {
    late MockEmbytokService mockService;
    late ProviderContainer container;
    late AuthState testAuthState;

    setUp(() {
      mockService = MockEmbytokService();
      testAuthState = AuthState(
        isAuthenticated: true,
        user: User(id: 'user-1', name: 'test', accessToken: 'test-token'),
        embyServerUrl: 'http://emby.example.com',
        token: 'test-token',
      );
    });

    tearDown(() {
      container.dispose();
    });

    // 创建带认证状态的容器（支持传入选中的媒体库 ID 列表）
    ProviderContainer createContainerWithAuth({
      List<String> selectedLibraryIds = const <String>['lib-1'],
    }) {
      return ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testAuthState)),
          videoListProvider.overrideWith(
            (ref) => VideoListNotifier(ref, service: mockService),
          ),
          selectedLibraryIdsProvider.overrideWith(
            (ref) => _TestSelectedLibraryNotifier(selectedLibraryIds),
          ),
        ],
      );
    }

    test('初始状态', () {
      container = createContainerWithAuth();

      final state = container.read(videoListProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, false);
      expect(state.hasMore, true);
      expect(state.error, isNull);
    });

    test('refresh() 成功加载第一页（单库）', () async {
      final items = List.generate(
        20,
        (i) => MediaItem(id: 'item-$i', title: 'Video $i', type: 'Movie'),
      );

      final response = PaginatedResponse<MediaItem>(
        items: items,
        total: 50,
        offset: 0,
        limit: 20,
      );

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => response);

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.items.length, 20);
      expect(state.isLoading, false);
      expect(state.hasMore, true);
      expect(state.offset, 20);
      expect(state.error, isNull);

      verify(mockService.getLibraryItems(
        'lib-1',
        limit: 20,
        offset: 0,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('refresh() 成功加载第一页（多库混合）', () async {
      final items1 = List.generate(
        10,
        (i) => MediaItem(id: 'lib1-item-$i', title: 'Lib1 Video $i', type: 'Movie'),
      );
      final items2 = List.generate(
        10,
        (i) => MediaItem(id: 'lib2-item-$i', title: 'Lib2 Video $i', type: 'Movie'),
      );

      final response1 = PaginatedResponse<MediaItem>(
        items: items1,
        total: 50,
        offset: 0,
        limit: 20,
      );
      final response2 = PaginatedResponse<MediaItem>(
        items: items2,
        total: 30,
        offset: 0,
        limit: 20,
      );

      when(mockService.getLibraryItems(
        'lib-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => response1);

      when(mockService.getLibraryItems(
        'lib-2',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => response2);

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1', 'lib-2']);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.items.length, 20); // 10 + 10
      expect(state.items.first.id, 'lib1-item-0');
      expect(state.items.last.id, 'lib2-item-9');
      expect(state.hasMore, true);

      verify(mockService.getLibraryItems(
        'lib-1',
        limit: 20,
        offset: 0,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);

      verify(mockService.getLibraryItems(
        'lib-2',
        limit: 20,
        offset: 0,
        serverUrl: 'http://emby.example.com',
        token: 'test-token',
      )).called(1);
    });

    test('refresh() 加载所有数据时 hasMore = false', () async {
      final items = List.generate(
        5,
        (i) => MediaItem(id: 'item-$i', title: 'Video $i', type: 'Movie'),
      );

      final response = PaginatedResponse<MediaItem>(
        items: items,
        total: 5,
        offset: 0,
        limit: 20,
      );

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => response);

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.items.length, 5);
      // hasMore 基于 merged.length >= perLibLimit * selectedIds.length
      // 5 < 20, 所以 hasMore = false
      expect(state.hasMore, false);
    });

    test('loadMore() 多库模式下重新请求', () async {
      final items = List.generate(
        20,
        (i) => MediaItem(id: 'item-$i', title: 'Video $i', type: 'Movie'),
      );

      final response = PaginatedResponse<MediaItem>(
        items: items,
        total: 50,
        offset: 0,
        limit: 20,
      );

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => response);

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);

      // 先加载第一页
      await notifier.refresh();
      expect(container.read(videoListProvider).items.length, 20);

      // 加载更多
      await notifier.loadMore();

      final state = container.read(videoListProvider);
      expect(state.items.length, 20); // 多库模式下重新拉取
      expect(state.hasMore, true);
    });

    test('loadMore() 在无更多数据时不请求', () async {
      final items = List.generate(
        5,
        (i) => MediaItem(id: 'item-$i', title: 'Video $i', type: 'Movie'),
      );

      final response = PaginatedResponse<MediaItem>(
        items: items,
        total: 5,
        offset: 0,
        limit: 20,
      );

      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => response);

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      // 重置 mock 调用计数
      clearInteractions(mockService);

      // 尝试加载更多（hasMore = false）
      await notifier.loadMore();

      // 不应该有新的服务调用
      verifyNever(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('loadMore() 在加载中时跳过', () async {
      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);

      // 手动设置 loading 状态
      notifier.state = notifier.state.copyWith(isLoading: true);

      await notifier.loadMore();

      // 不应该有服务调用
      verifyNever(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('加载失败：error 包含错误信息', () async {
      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow(Exception('网络错误'));

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('加载视频失败'));
    });

    test('加载失败：字符串错误信息', () async {
      when(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenThrow('服务器维护中');

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.error, '服务器维护中');
    });

    test('未登录时 refresh() 返回错误', () async {
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => _TestAuthNotifier(const AuthState()),
          ),
          videoListProvider.overrideWith(
            (ref) => VideoListNotifier(ref, service: mockService),
          ),
          selectedLibraryIdsProvider.overrideWith(
            (ref) => _TestSelectedLibraryNotifier(const <String>['lib-1']),
          ),
        ],
      );

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.error, '尚未登录');
      expect(state.isLoading, false);

      // 不应该调用服务
      verifyNever(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('未选择媒体库时 refresh() 不加载', () async {
      container = createContainerWithAuth(selectedLibraryIds: const <String>[]);

      final notifier = container.read(videoListProvider.notifier);
      await notifier.refresh();

      final state = container.read(videoListProvider);
      expect(state.isLoading, false);
      expect(state.items, isEmpty);

      verifyNever(mockService.getLibraryItems(
        any,
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      ));
    });

    test('切换媒体库：refresh() 重置列表', () async {
      // 媒体库 1 的数据
      final lib1Items = List.generate(
        10,
        (i) => MediaItem(id: 'lib1-item-$i', title: 'Lib1 Video $i', type: 'Movie'),
      );

      final lib1Response = PaginatedResponse<MediaItem>(
        items: lib1Items,
        total: 10,
        offset: 0,
        limit: 20,
      );

      // 媒体库 2 的数据
      final lib2Items = List.generate(
        5,
        (i) => MediaItem(id: 'lib2-item-$i', title: 'Lib2 Video $i', type: 'Movie'),
      );

      final lib2Response = PaginatedResponse<MediaItem>(
        items: lib2Items,
        total: 5,
        offset: 0,
        limit: 20,
      );

      when(mockService.getLibraryItems(
        'lib-1',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => lib1Response);

      when(mockService.getLibraryItems(
        'lib-2',
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
        serverUrl: anyNamed('serverUrl'),
        token: anyNamed('token'),
      )).thenAnswer((_) async => lib2Response);

      container = createContainerWithAuth(selectedLibraryIds: <String>['lib-1']);

      final notifier = container.read(videoListProvider.notifier);

      // 加载媒体库 1
      await notifier.refresh();
      expect(container.read(videoListProvider).items.first.id, 'lib1-item-0');

      // 切换到媒体库 2：需要通过 override 更新，这里直接创建新的 container 验证
      final container2 = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier(testAuthState)),
          videoListProvider.overrideWith(
            (ref) => VideoListNotifier(ref, service: mockService),
          ),
          selectedLibraryIdsProvider.overrideWith(
            (ref) => _TestSelectedLibraryNotifier(const <String>['lib-2']),
          ),
        ],
      );

      final notifier2 = container2.read(videoListProvider.notifier);
      await notifier2.refresh();
      final state2 = container2.read(videoListProvider);
      expect(state2.items.length, 5);
      expect(state2.items.first.id, 'lib2-item-0');
      expect(state2.offset, 5);

      container2.dispose();
    });
  });
}

// 测试用 AuthNotifier：直接返回预设状态
class _TestAuthNotifier extends StateNotifier<AuthState> {
  _TestAuthNotifier(AuthState initialState) : super(initialState);
}

// 测试用 SelectedLibraryNotifier：返回预设的选中媒体库 ID 列表
class _TestSelectedLibraryNotifier extends StateNotifier<List<String>> {
  _TestSelectedLibraryNotifier(List<String> initialState) : super(initialState);
}
