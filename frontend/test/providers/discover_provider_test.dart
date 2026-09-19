// 发现数据源 Provider 集成测试
//
// 覆盖「发现·标签」链路（PRD：发现页对接 Emby 类型/标签/合集，用户可分别设置）：
// 1. saveTags 持久化选择 + 触发标签内容加载（getItemsByTag 合并去重）
// 2. 启动时从 SharedPreferences 恢复已选标签
// 3. hasSelection 包含标签来源

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/models/models.dart';
import 'package:embytok_flutter/providers/auth_provider.dart';
import 'package:embytok_flutter/providers/cache_providers.dart';
import 'package:embytok_flutter/providers/discover_provider.dart';
import 'package:embytok_flutter/providers/embytok_service_provider.dart';
import 'package:embytok_flutter/providers/library_provider.dart';
import 'package:embytok_flutter/providers/syno_accounts_provider.dart';
import 'package:embytok_flutter/repositories/media_repository.dart';
import 'package:embytok_flutter/utils/constants.dart';

import '../mocks/mock_services.dart';

// ============================================================
// 测试辅助类
// ============================================================

/// 固定认证状态的 AuthNotifier（跳过 _loadFromStorage 的异步恢复）
class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, AuthState initialState) {
    state = initialState;
  }
}

const _testAuthState = AuthState(
  isAuthenticated: true,
  user: User(id: 'user-1', name: 'test', accessToken: 'token-1'),
  embyServerUrl: 'http://emby.test',
  token: 'token-1',
);

/// MediaRepository 的 Mock 实现，只覆盖发现链路需要的方法
class _MockMediaRepository extends Mock implements MediaRepository {
  List<Library> tags = [];
  List<Library> genres = [];
  List<Library> collections = [];

  /// tag -> items
  Map<String, List<MediaItem>> tagItems = {};

  @override
  Future<List<Library>> getTags({
    int? limit,
    String? serverUrl,
    String? token,
  }) async {
    return tags;
  }

  @override
  Future<List<Library>> getGenres({
    int? limit,
    String? serverUrl,
    String? token,
  }) async {
    return genres;
  }

  @override
  Future<List<Library>> getCollections({
    int? limit,
    String? serverUrl,
    String? token,
  }) async {
    return collections;
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByTag(
    String? tag, {
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
  }) async {
    return PaginatedResponse<MediaItem>(
      items: tagItems[tag] ?? const [],
      total: (tagItems[tag] ?? const []).length,
      offset: offset ?? 0,
      limit: limit ?? 30,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getItemsByGenre(
    String? genre, {
    int? limit,
    int? offset,
    String? serverUrl,
    String? token,
  }) async {
    return PaginatedResponse<MediaItem>(
      items: const [],
      total: 0,
      offset: offset ?? 0,
      limit: limit ?? 30,
    );
  }

  @override
  Future<PaginatedResponse<MediaItem>> getBoxSetItems(
    String? boxSetId, {
    int? limit,
    int? offset,
    bool? excludePlayed,
    String? serverUrl,
    String? token,
  }) async {
    return PaginatedResponse<MediaItem>(
      items: const [],
      total: 0,
      offset: offset ?? 0,
      limit: limit ?? 50,
    );
  }
}

MediaItem _item(String id, String title, {int year = 2024}) {
  return MediaItem(
    id: id,
    title: title,
    productionYear: year,
    type: 'Movie',
  );
}

/// 等待 DiscoverNotifier 的异步操作完成
/// 轮询 isLoading 且要求连续空闲 60ms（覆盖 _init 中先恢复选择、后拉列表的间隙），
/// 最多等待 3 秒
Future<void> _waitForIdle(ProviderContainer container,
    {Duration timeout = const Duration(seconds: 3)}) async {
  final deadline = DateTime.now().add(timeout);
  DateTime? idleSince;
  while (DateTime.now().isBefore(deadline)) {
    final state = container.read(discoverProvider);
    if (!state.isLoading) {
      final now = DateTime.now();
      if (idleSince == null) {
        idleSince = now;
      } else if (now.difference(idleSince) >
          const Duration(milliseconds: 60)) {
        return;
      }
    } else {
      idleSince = null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('等待 DiscoverNotifier 空闲超时');
}

ProviderContainer _createContainer({
  required _MockMediaRepository repo,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderContainer(
    overrides: [
      embytokServiceProvider.overrideWithValue(MockEmbytokService()),
      authProvider.overrideWith(
        (ref) => _TestAuthNotifier(ref, _testAuthState),
      ),
      libraryListProvider.overrideWith((ref) async {
        return [Library(id: 'lib-1', name: 'Movies', type: 'movies')];
      }),
      mediaRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

// ============================================================
// 测试用例
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveTags 持久化选择并加载标签内容（合并去重）', () async {
    final repo = _MockMediaRepository()
      ..tags = [
        Library(id: '4K', name: '4K', type: 'Tag'),
        Library(id: '国配', name: '国配', type: 'Tag'),
      ]
      ..tagItems = {
        '4K': [_item('m-1', '4K 电影 A', year: 2026)],
        '国配': [_item('m-2', '国配电影 B', year: 2025)],
      };
    final container = _createContainer(repo: repo);
    addTearDown(container.dispose);

    // 等待初始 _init 完成
    await _waitForIdle(container);

    final notifier = container.read(discoverProvider.notifier);
    await notifier.saveTags(const ['4K', '国配']);

    final state = container.read(discoverProvider);
    expect(state.hasSelection, isTrue);
    expect(state.selectedTagIds, containsAll(['4K', '国配']));
    // 标签内容合并进发现列表
    expect(state.items.map((i) => i.id), containsAll(['m-1', 'm-2']));

    // 持久化检查：存储键写入（accountScopedKey 含账号分桶）
    final prefs = await SharedPreferences.getInstance();
    final key = await accountScopedKey(kStorageKeyDiscoverTags);
    expect(prefs.getString(key), isNotNull);
    expect(prefs.getString(key)!.contains('4K'), isTrue);
    expect(prefs.getString(key)!.contains('国配'), isTrue);
  });

  test('启动时从存储恢复已选标签并自动加载内容', () async {
    final repo = _MockMediaRepository()
      ..tags = [Library(id: '4K', name: '4K', type: 'Tag')]
      ..tagItems = {
        '4K': [_item('m-1', '4K 电影 A')],
      };
    // 预置存储：已选标签 4K（按账号分桶 key）
    final key = await accountScopedKey(kStorageKeyDiscoverTags);
    final container = _createContainer(
      repo: repo,
      prefs: {key: '["4K"]'},
    );
    addTearDown(container.dispose);

    await _waitForIdle(container);

    final state = container.read(discoverProvider);
    expect(state.selectedTagIds, ['4K']);
    expect(state.hasSelection, isTrue);
    // 自动加载标签内容
    expect(state.items.map((i) => i.id), contains('m-1'));
  });

  test('未选择任何来源时 hasSelection 为 false 且列表为空', () async {
    final repo = _MockMediaRepository()
      ..tags = [Library(id: '4K', name: '4K', type: 'Tag')]
      ..genres = [Library(id: 'g1', name: '动作', type: 'Genre')]
      ..collections = [
        Library(id: 'c1', name: '系列', type: 'BoxSet')
      ];
    final container = _createContainer(repo: repo);
    addTearDown(container.dispose);

    await _waitForIdle(container);

    final state = container.read(discoverProvider);
    expect(state.hasSelection, isFalse);
    expect(state.items, isEmpty);
  });
}
