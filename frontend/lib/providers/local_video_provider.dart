// 本地视频 Provider：列表状态、权限状态、筛选排序、加载状态
// 对应 PRD《本地模式》§5.3
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_video_item.dart';
import '../models/file_source.dart';
import '../services/local_video_service.dart';
import '../services/scrape_service.dart';
import '../services/scrape_media_store.dart';
import 'file_sources_provider.dart';

/// 服务单例
final localVideoServiceProvider = Provider<LocalVideoService>(
  (_) => LocalVideoService(),
);

/// 排序方式
enum LocalVideoSort {
  modifiedDesc,  // 修改时间倒序（默认）
  nameAsc,       // 名称 A→Z
  durationDesc,  // 时长倒序
  sizeDesc,      // 文件大小倒序
  ratingDesc,    // 评分高到低（需刮削）
}

/// 视图模式
enum LocalVideoViewMode { grid, list }

/// 本地视频列表状态
class LocalVideoState {
  final List<LocalVideoItem> items;
  final bool loading;
  final PermissionState permission;
  final LocalVideoSort sort;
  final LocalVideoViewMode viewMode;
  final String keyword;
  final bool selecting;        // 多选模式
  final Set<String> selected;   // 已选 id
  final String? error;
  final List<String> recentHashes; // 最近播放 pathHash（按时间倒序）
  final bool groupByFolder;        // 是否按文件夹分组
  final Set<String> favoriteHashes; // 已收藏 pathHash（P3）
  final Set<String> favoriteActorIds; // 已收藏演员 TMDB id
  final Map<String, ScrapedMedia> scrapedMap; // 刮削结果 pathHash→media（刮削 P0）
  final bool scraping; // 是否正在批量刮削
  final int scrapeDone; // 刮削进度（P1 #4）
  final int scrapeTotal;
  final int scrapeOk; // P2 #11：成功数
  final int scrapeFail; // P2 #11：失败数
  final Map<String, String> failedMap; // P2 #6：pathHash→失败原因
  final String? typeFilter; // 类型筛选（P1 #6）：null=全部/movie/tv/none

  const LocalVideoState({
    this.items = const [],
    this.loading = false,
    this.permission = PermissionState.notDetermined,
    this.sort = LocalVideoSort.modifiedDesc,
    this.viewMode = LocalVideoViewMode.grid,
    this.keyword = '',
    this.selecting = false,
    this.selected = const {},
    this.error,
    this.recentHashes = const [],
    this.groupByFolder = false,
    this.favoriteHashes = const {},
    this.favoriteActorIds = const {},
    this.scrapedMap = const {},
    this.scraping = false,
    this.scrapeDone = 0,
    this.scrapeTotal = 0,
    this.scrapeOk = 0,
    this.scrapeFail = 0,
    this.failedMap = const {},
    this.typeFilter,
  });

  LocalVideoState copyWith({
    List<LocalVideoItem>? items,
    bool? loading,
    PermissionState? permission,
    LocalVideoSort? sort,
    LocalVideoViewMode? viewMode,
    String? keyword,
    bool? selecting,
    Set<String>? selected,
    String? error,
    List<String>? recentHashes,
    bool? groupByFolder,
    Set<String>? favoriteHashes,
    Set<String>? favoriteActorIds,
    Map<String, ScrapedMedia>? scrapedMap,
    bool? scraping,
    int? scrapeDone,
    int? scrapeTotal,
    int? scrapeOk,
    int? scrapeFail,
    Map<String, String>? failedMap,
    String? typeFilter,
  }) =>
      LocalVideoState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        permission: permission ?? this.permission,
        sort: sort ?? this.sort,
        viewMode: viewMode ?? this.viewMode,
        keyword: keyword ?? this.keyword,
        selecting: selecting ?? this.selecting,
        selected: selected ?? this.selected,
        error: error,
        recentHashes: recentHashes ?? this.recentHashes,
        groupByFolder: groupByFolder ?? this.groupByFolder,
        favoriteHashes: favoriteHashes ?? this.favoriteHashes,
        favoriteActorIds: favoriteActorIds ?? this.favoriteActorIds,
        scrapedMap: scrapedMap ?? this.scrapedMap,
        scraping: scraping ?? this.scraping,
        scrapeDone: scrapeDone ?? this.scrapeDone,
        scrapeTotal: scrapeTotal ?? this.scrapeTotal,
        scrapeOk: scrapeOk ?? this.scrapeOk,
        scrapeFail: scrapeFail ?? this.scrapeFail,
        failedMap: failedMap ?? this.failedMap,
        typeFilter: typeFilter ?? this.typeFilter,
      );

  /// 最近播放的视频项（按时间倒序，与 items 求交集）
  List<LocalVideoItem> get recentItems {
    final map = {for (final e in items) e.id: e};
    return recentHashes
        .map((h) => map[h])
        .whereType<LocalVideoItem>()
        .toList();
  }

  /// 最近添加的视频（P1）：按修改时间倒序，取前 10 个，排除已在"继续观看"中的
  List<LocalVideoItem> get recentlyAdded {
    final playing = recentHashes.toSet();
    final list = [...items]..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return list.where((e) => !playing.contains(e.pathHash)).take(10).toList();
  }

  /// 未观看的视频（P1）：从未播放过（不在 recentHashes 中），取前 10
  List<LocalVideoItem> get unwatchedItems {
    final played = recentHashes.toSet();
    return items.where((e) => !played.contains(e.pathHash)).take(10).toList();
  }

  /// 按文件夹分组（P2）：返回 {文件夹名: 视频列表}，按文件夹名排序
  Map<String, List<LocalVideoItem>> get grouped {
    final map = <String, List<LocalVideoItem>>{};
    for (final e in filtered) {
      final folder = e.relativePath?.trim() ?? '未分类';
      map.putIfAbsent(folder, () => []).add(e);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// 筛选 + 排序后的展示列表
  List<LocalVideoItem> get filtered {
    var list = items;
    if (keyword.trim().isNotEmpty) {
      final k = keyword.toLowerCase();
      list = list.where((e) => e.name.toLowerCase().contains(k)).toList();
    }
    // 类型筛选（P1 #6）
    if (typeFilter != null) {
      list = list.where((e) {
        final s = scrapedMap[e.pathHash];
        if (typeFilter == 'none') return s == null;
        return s?.type == typeFilter;
      }).toList();
    }
    switch (sort) {
      case LocalVideoSort.modifiedDesc:
        list = [...list]..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case LocalVideoSort.nameAsc:
        list = [...list]..sort((a, b) => a.name.compareTo(b.name));
        break;
      case LocalVideoSort.durationDesc:
        list = [...list]..sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case LocalVideoSort.sizeDesc:
        list = [...list]..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case LocalVideoSort.ratingDesc:
        // 评分高到低，无评分排最后
        list = [...list]..sort((a, b) {
          final ra = scrapedMap[a.pathHash]?.rating ?? -1;
          final rb = scrapedMap[b.pathHash]?.rating ?? -1;
          return rb.compareTo(ra);
        });
        break;
    }
    return list;
  }
}

class LocalVideoNotifier extends StateNotifier<LocalVideoState> {
  final Ref _ref;
  LocalVideoNotifier(this._ref) : super(const LocalVideoState()) {
    _init();
  }

  Future<void> _init() async {
    final svc = _ref.read(localVideoServiceProvider);
    // 迁移旧 SharedPreferences 缓存到文件（幂等）
    await ScrapeMediaStore.migrateFromPrefs();
    // 先读缓存，再后台刷新
    final cached = await svc.loadCache();
    final ps = await LocalVideoService.currentPermission();
    final sp = await SharedPreferences.getInstance();
    final favActors = sp.getStringList('favorite_actors')?.toSet() ?? {};
    state = state.copyWith(items: cached, permission: ps, favoriteActorIds: favActors);
    if (ps.hasAccess) {
      refresh();
    }
  }

  /// 请求权限并扫描
  Future<void> requestPermissionAndScan() async {
    final svc = _ref.read(localVideoServiceProvider);
    final ps = await LocalVideoService.requestPermission();
    state = state.copyWith(permission: ps);
    if (ps.hasAccess) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final svc = _ref.read(localVideoServiceProvider);
      final items = await svc.scan();
      final recent = await svc.getRecentPlayHashes();
      final favs = await svc.getFavorites();
      final cached = await ScrapeService.loadCache();
      final central = await ScrapeMediaStore.loadCentralAll();
      cached.addAll(central); // 文件存储优先（覆盖 prefs）
      // App 目录视频：读视频旁 .nfo（清除 prefs 缓存后仍可恢复）
      for (final it in items) {
        if (it.isAppDirFile && it.path != null && !cached.containsKey(it.pathHash)) {
          final nfo = await ScrapeMediaStore.loadSibling(it.path!);
          if (nfo != null) cached[it.pathHash] = nfo;
        }
      }
      state = state.copyWith(
          items: items,
          recentHashes: recent,
          favoriteHashes: favs,
          scrapedMap: cached,
          loading: false);
      // 更新每个文件源的视频计数
      final sources = _ref.read(fileSourcesProvider);
      for (final s in sources) {
        final count = items.where((e) => e.sourceId == s.id).length;
        if (count != s.videoCount) {
          _ref.read(fileSourcesProvider.notifier).updateScanStatus(
                s.id,
                FileSourceStatus.connected,
                videoCount: count,
              );
        }
      }
      // 后台异步刮削未缓存文件
      scrapeMissing();
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  /// 后台刮削未缓存的文件（P0）
  Future<void> scrapeMissing() async {
    if (state.scraping) return;
    final todo = state.items
        .where((e) => !state.scrapedMap.containsKey(e.pathHash))
        .toList();
    state = state.copyWith(
      scraping: true,
      scrapeDone: 0,
      scrapeTotal: todo.length,
      failedMap: const {},
    );
    final cached = Map<String, ScrapedMedia>.from(state.scrapedMap);
    final failed = <String, String>{};
    var done = 0, ok = 0, fail = 0;
    // 并发限制：4 并发，对齐 TMDB 免费层 ~40req/10s
    const concurrency = 4;
    var i = 0;
    Future<void> worker() async {
      while (i < todo.length) {
        final idx = i++;
        final item = todo[idx];
        try {
          if (item.mediaType == 'short') {
            done++;
            continue;
          }
          final m = await ScrapeService.scrapeFile(
            item.pathHash,
            item.name,
            parentDir: item.relativePath,
            mediaTypeHint: item.mediaType,
          );
          if (m != null) {
            cached[item.pathHash] = m;
            await ScrapeService.saveCache(item.pathHash, m);
            await ScrapeMediaStore.save(item, m);
            failed.remove(item.pathHash);
            ok++;
          } else {
            failed[item.pathHash] = '未找到匹配';
            fail++;
          }
        } catch (e) {
          failed[item.pathHash] = e.toString();
          fail++;
        }
        done++;
        if (_mounted) {
          state = state.copyWith(scrapedMap: cached, scrapeDone: done, failedMap: Map.unmodifiable(failed));
        }
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));
    if (_mounted) {
      state = state.copyWith(scraping: false, scrapeOk: ok, scrapeFail: fail);
    }
  }

  /// 只重试上次刮削失败的项
  Future<void> retryFailed() async {
    if (state.scraping) return;
    final hashes = state.failedMap.keys.toSet();
    if (hashes.isEmpty) return;
    final todo = state.items.where((e) => hashes.contains(e.pathHash)).toList();
    state = state.copyWith(
      scraping: true,
      scrapeDone: 0,
      scrapeTotal: todo.length,
    );
    final cached = Map<String, ScrapedMedia>.from(state.scrapedMap);
    final failed = <String, String>{};
    var done = 0, ok = 0, fail = 0;
    const concurrency = 4;
    var i = 0;
    Future<void> worker() async {
      while (i < todo.length) {
        final idx = i++;
        final item = todo[idx];
        try {
          final m = await ScrapeService.scrapeFile(
            item.pathHash,
            item.name,
            parentDir: item.relativePath,
            mediaTypeHint: item.mediaType,
          );
          if (m != null) {
            cached[item.pathHash] = m;
            await ScrapeService.saveCache(item.pathHash, m);
            await ScrapeMediaStore.save(item, m);
            ok++;
          } else {
            failed[item.pathHash] = '未找到匹配';
            fail++;
          }
        } catch (e) {
          failed[item.pathHash] = e.toString();
          fail++;
        }
        done++;
        if (_mounted) {
          state = state.copyWith(scrapedMap: cached, scrapeDone: done, failedMap: Map.unmodifiable(failed));
        }
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));
    if (_mounted) {
      state = state.copyWith(scraping: false, scrapeOk: ok, scrapeFail: fail);
    }
  }

  bool get _mounted => true;

  /// 切换本地收藏（P3）
  Future<void> toggleFavorite(String pathHash) async {
    final svc = _ref.read(localVideoServiceProvider);
    final nowFav = !state.favoriteHashes.contains(pathHash);
    final favs = Set<String>.from(state.favoriteHashes);
    if (nowFav) {
      favs.add(pathHash);
    } else {
      favs.remove(pathHash);
    }
    state = state.copyWith(favoriteHashes: favs);
    try {
      await svc.setFavorite(pathHash, nowFav);
    } catch (_) {}
  }

  /// 切换本地收藏演员（TMDB id）
  Future<void> toggleFavoriteActor(String personId) async {
    final sp = await SharedPreferences.getInstance();
    final nowFav = !state.favoriteActorIds.contains(personId);
    final ids = Set<String>.from(state.favoriteActorIds);
    if (nowFav) {
      ids.add(personId);
    } else {
      ids.remove(personId);
    }
    state = state.copyWith(favoriteActorIds: ids);
    await sp.setStringList('favorite_actors', ids.toList());
  }

  void setKeyword(String k) => state = state.copyWith(keyword: k);

  /// 从本地列表移除指定 pathHash 的视频（不删文件，仅清缓存记录）
  Future<void> removeByPathHash(String pathHash) async {
    final items = List.of(state.items)
      ..removeWhere((it) => it.pathHash == pathHash);
    state = state.copyWith(items: items);
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      'local_video_cache_v1',
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
  void setSort(LocalVideoSort s) => state = state.copyWith(sort: s);
  void setTypeFilter(String? t) => state = state.copyWith(typeFilter: t);
  void toggleGroupByFolder() =>
      state = state.copyWith(groupByFolder: !state.groupByFolder);
  void toggleViewMode() => state = state.copyWith(
        viewMode: state.viewMode == LocalVideoViewMode.grid
            ? LocalVideoViewMode.list
            : LocalVideoViewMode.grid,
      );
  void setViewMode(LocalVideoViewMode m) =>
      state = state.copyWith(viewMode: m);

  /// 全选当前 filtered（P2 #12）
  void selectAll() {
    final ids = state.filtered.map((e) => e.id).toSet();
    state = state.copyWith(selected: ids);
  }

  void enterSelecting() => state = state.copyWith(selecting: true, selected: {});
  void exitSelecting() => state = state.copyWith(selecting: false, selected: {});
  void toggleSelected(String id) {
    final s = {...state.selected};
    if (s.contains(id)) {
      s.remove(id);
      if (s.isEmpty) {
        state = state.copyWith(selected: s, selecting: false);
        return;
      }
    } else {
      s.add(id);
    }
    state = state.copyWith(selected: s);
  }

  /// 删除指定 id 的视频
  Future<int> deleteByIds(Set<String> ids) async {
    final svc = _ref.read(localVideoServiceProvider);
    var ok = 0;
    for (final id in ids) {
      final item = state.items.where((e) => e.id == id).firstOrNull;
      if (item == null) continue;
      if (await svc.delete(item)) {
        ok++;
        await ScrapeMediaStore.delete(item);
        // 同时清理 prefs 旧缓存
        final sp = await SharedPreferences.getInstance();
        await sp.remove('scrape_${item.pathHash}');
      }
    }
    if (ok > 0) {
      state = state.copyWith(
        items: state.items.where((e) => !ids.contains(e.id)).toList(),
        selected: {},
        selecting: false,
      );
    }
    return ok;
  }
}

final localVideoProvider =
    StateNotifierProvider<LocalVideoNotifier, LocalVideoState>(
  (ref) => LocalVideoNotifier(ref),
);

/// 本地视频流中当前可见页索引（用于滑动时暂停其他页）
/// -1 表示独立使用 LocalPlayerPage，始终播放
final localFeedPlayingIndexProvider = StateProvider<int>((_) => -1);

/// 用户在"视频流使用"选择器中选中的本地文件源 ID
/// - null：未选本地源（走 Emby 推荐流）
/// - 空字符串 ''：全部本地视频
/// - 非空：只播该文件源
/// 持久化到 SharedPreferences，重启 App 后恢复
class LocalFeedSourceIdNotifier extends StateNotifier<String?> {
  static const _key = 'local_feed_source_id';
  LocalFeedSourceIdNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    // 区分 null（未设置/走 Emby）与 ''（全部本地）
    state = v;
  }

  Future<void> set(String? value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, value);
    }
  }
}

final localFeedSourceIdProvider =
    StateNotifierProvider<LocalFeedSourceIdNotifier, String?>(
        (_) => LocalFeedSourceIdNotifier());
