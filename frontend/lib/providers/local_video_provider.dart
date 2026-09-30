// 本地视频 Provider：列表状态、权限状态、筛选排序、加载状态
// 对应 PRD《本地模式》§5.3
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/local_video_item.dart';
import '../services/local_video_service.dart';
import '../services/scrape_service.dart';

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
  final Map<String, ScrapedMedia> scrapedMap; // 刮削结果 pathHash→media（刮削 P0）
  final bool scraping; // 是否正在批量刮削

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
    this.scrapedMap = const {},
    this.scraping = false,
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
    Map<String, ScrapedMedia>? scrapedMap,
    bool? scraping,
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
        scrapedMap: scrapedMap ?? this.scrapedMap,
        scraping: scraping ?? this.scraping,
      );

  /// 最近播放的视频项（按时间倒序，与 items 求交集）
  List<LocalVideoItem> get recentItems {
    final map = {for (final e in items) e.id: e};
    return recentHashes
        .map((h) => map[h])
        .whereType<LocalVideoItem>()
        .toList();
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
    // 先读缓存，再后台刷新
    final cached = await svc.loadCache();
    final ps = await LocalVideoService.currentPermission();
    state = state.copyWith(items: cached, permission: ps);
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
      state = state.copyWith(
          items: items,
          recentHashes: recent,
          favoriteHashes: favs,
          scrapedMap: cached,
          loading: false);
      // 后台异步刮削未缓存文件
      scrapeMissing();
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }

  /// 后台刮削未缓存的文件（P0）
  Future<void> scrapeMissing() async {
    if (state.scraping) return;
    state = state.copyWith(scraping: true);
    final cached = Map<String, ScrapedMedia>.from(state.scrapedMap);
    for (final item in state.items) {
      if (cached.containsKey(item.pathHash)) continue;
      try {
        final m = await ScrapeService.scrapeFile(item.pathHash, item.name);
        if (m != null) {
          cached[item.pathHash] = m;
          await ScrapeService.saveCache(item.pathHash, m);
          if (state.scraping && _mounted) {
            state = state.copyWith(scrapedMap: cached);
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (_mounted) state = state.copyWith(scraping: false);
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

  void setKeyword(String k) => state = state.copyWith(keyword: k);
  void setSort(LocalVideoSort s) => state = state.copyWith(sort: s);
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
      if (await svc.delete(item)) ok++;
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
