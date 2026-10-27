// 本地视频 Provider：列表状态、权限状态、筛选排序、加载状态
// 对应 PRD《本地模式》§5.3
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_video_item.dart';
import '../models/file_source.dart';
import '../services/local_video_service.dart';
import '../services/scrape_service.dart';
import '../services/scrape_media_store.dart';
import '../utils/logger.dart';
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
class LocalVideoState { // 类型筛选（P1 #6）：null=全部/movie/tv/none

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
  final String? typeFilter;

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
  LocalVideoNotifier(this._ref) : super(const LocalVideoState()) {
    _init();
  }
  final Ref _ref;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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

  Future<void>? _inflightRefresh;
  bool _refreshQueued = false;

  /// 全量刷新（合并去重）：已有刷新进行中时标记"尾刷"，完成后若期间又有新请求
  /// 立即再刷一次——连续操作（如快速切换开关）不会产生重叠全量扫描，
  /// 且总能拿到最新源配置，不丢最后一次变更。
  Future<void> refresh() {
    final inflight = _inflightRefresh;
    if (inflight != null) {
      _refreshQueued = true;
      return inflight;
    }
    final f = _doRefresh().whenComplete(() {
      _inflightRefresh = null;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    });
    _inflightRefresh = f;
    return f;
  }

  Future<void> _doRefresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final svc = _ref.read(localVideoServiceProvider);
      final items = await svc.scan();
      final recent = await svc.getRecentPlayHashes();
      final favs = await svc.getFavorites();
      final cached = await ScrapeService.loadCache();
      final central = await ScrapeMediaStore.loadCentralAll();
      cached.addAll(central); // 文件存储优先（覆盖 prefs）
      // 视频旁 .nfo 是权威源：覆盖文本元数据；
      // 但 embytok_* 标签是新加的，旧 .nfo 没有，此时保留中央缓存的 poster/backdrop/still path，
      // 否则会把中央缓存里已有 path 覆盖成 null，导致详情页无图。
      // 所有可空字段都在 .nfo 缺失时回退中央缓存：
      // 旧 .nfo 可能没有 embytok_* 标签、<season>/<episode>、单集简介等，
      // 直接覆盖会让电视剧单集详情页退化成整剧详情页。
      // 逐项读取 .nfo 并合并元数据：分批并发（每批 16），避免大媒体库全量刷新
      // 串行读盘阻塞主路径；每项内部的后台回填仍为 unawaited，不阻塞批次。
      final pathItems = items.where((it) => it.path.isNotEmpty).toList();
      Future<void> mergeNfo(LocalVideoItem it) async {
        final nfo = await ScrapeMediaStore.loadSibling(it.path);
        if (nfo == null) {
          // 没有 .nfo 但中央缓存有数据：用中央数据创建 .nfo 并补下载图片
          final central = cached[it.pathHash];
          if (central != null) {
            unawaited(ScrapeMediaStore.backfillSibling(it.path, central));
            unawaited(ScrapeMediaStore.backfillImages(it.path, it.pathHash, central));
            if (central.cast.isNotEmpty) {
              unawaited(ScrapeMediaStore.backfillCastAvatars(it.path, central.cast));
            }
          }
          return;
        }
        final prev = cached[it.pathHash];
        // 演员合并：.nfo 有演员名但可能缺 id/profilePath（旧格式），
        // 按名字匹配中央缓存补充 id 和头像路径。
        final mergedCast = <Map<String, String>>[];
        final prevCastByName = <String, Map<String, String>>{};
        if (prev?.cast != null) {
          for (final c in prev!.cast) {
            final name = c['name'] ?? '';
            if (name.isNotEmpty) prevCastByName[name] = c;
          }
        }
        for (final nc in nfo.cast) {
          final name = nc['name'] ?? '';
          final match = prevCastByName[name];
          mergedCast.add({
            'name': name,
            'role': nc['role'] ?? match?['role'] ?? '',
            if (nc['id'] != null && nc['id']!.isNotEmpty)
              'id': nc['id']!
            else if (match?['id'] != null && match!['id']!.isNotEmpty)
              'id': match['id']!,
            if (nc['profilePath'] != null && nc['profilePath']!.isNotEmpty)
              'profilePath': nc['profilePath']!
            else if (match?['profilePath'] != null && match!['profilePath']!.isNotEmpty)
              'profilePath': match['profilePath']!,
          });
        }
        // .nfo 没有演员但中央有，用中央的
        if (mergedCast.isEmpty && prev?.cast != null) {
          mergedCast.addAll(prev!.cast);
        }
        final merged = ScrapedMedia(
          tmdbId: nfo.tmdbId,
          type: nfo.type,
          title: nfo.title,
          year: nfo.year ?? prev?.year,
          posterPath: nfo.posterPath ?? prev?.posterPath,
          backdropPath: nfo.backdropPath ?? prev?.backdropPath,
          overview: nfo.overview ?? prev?.overview,
          rating: nfo.rating ?? prev?.rating,
          genres: nfo.genres.isNotEmpty ? nfo.genres : (prev?.genres ?? const []),
          cast: mergedCast,
          directors: nfo.directors.isNotEmpty ? nfo.directors : (prev?.directors ?? const []),
          studios: nfo.studios.isNotEmpty ? nfo.studios : (prev?.studios ?? const []),
          imdbId: nfo.imdbId ?? prev?.imdbId,
          stillPath: nfo.stillPath ?? prev?.stillPath,
          episodeTitle: nfo.episodeTitle ?? prev?.episodeTitle,
          season: nfo.season ?? prev?.season,
          episode: nfo.episode ?? prev?.episode,
          tvId: nfo.tvId ?? prev?.tvId,
          certification: nfo.certification ?? prev?.certification,
          // .nfo 不写 lowConfidence 标签，解析恒为 false；
          // 回退中央缓存，避免低置信匹配标记在每次 refresh 后被覆盖丢失
          lowConfidence: nfo.lowConfidence || (prev?.lowConfidence ?? false),
          // .nfo 无时间字段（_parseXmlNfo 恒为解析时刻），优先中央缓存真实刮削时间，
          // 避免详情页"加入时间"每次刷新漂移成"刚刚"
          scrapedAt: prev?.scrapedAt ?? nfo.scrapedAt,
        );
        cached[it.pathHash] = merged;
        // 旧 .nfo 补全：把合并后的数据写回 .nfo（一次性迁移）
        unawaited(ScrapeMediaStore.backfillSibling(it.path, merged));
        // 补下载海报/背景/剧照到视频旁（旧视频清了 App 数据后沙箱图丢失）
        unawaited(ScrapeMediaStore.backfillImages(it.path, it.pathHash, merged));
        // 补下载演员头像到本地（旧视频刮削时没下载，合并后有了 id/profilePath）
        if (merged.cast.isNotEmpty) {
          unawaited(ScrapeMediaStore.backfillCastAvatars(it.path, merged.cast));
        } else if (merged.tvId != null) {
          // 单集无演员数据：从 TMDB 拉整剧演员
          unawaited(() async {
            final showCast = await ScrapeService.fetchShowCast(merged.tvId!);
            if (showCast.isNotEmpty) {
              cached[it.pathHash] = ScrapedMedia(
                tmdbId: merged.tmdbId,
                type: merged.type,
                title: merged.title,
                year: merged.year,
                posterPath: merged.posterPath,
                backdropPath: merged.backdropPath,
                overview: merged.overview,
                rating: merged.rating,
                genres: merged.genres,
                cast: showCast,
                directors: merged.directors,
                studios: merged.studios,
                imdbId: merged.imdbId,
                stillPath: merged.stillPath,
                episodeTitle: merged.episodeTitle,
                season: merged.season,
                episode: merged.episode,
                tvId: merged.tvId,
                certification: merged.certification,
                lowConfidence: merged.lowConfidence,
                scrapedAt: merged.scrapedAt,
              );
              state = state.copyWith(scrapedMap: Map.unmodifiable(cached));
              unawaited(ScrapeMediaStore.backfillCastAvatars(it.path, showCast));
            }
          }());
        }
        // 检测到 genre 全英文：后台重新拉取中文元数据
        if (ScrapeService.needsChineseRefetch(merged)) {
          unawaited(() async {
            final updated = await ScrapeService.refetchChinese(merged);
            if (updated != null) {
              cached[it.pathHash] = updated;
              state = state.copyWith(scrapedMap: Map.unmodifiable(cached));
              unawaited(ScrapeMediaStore.backfillSibling(it.path, updated));
            }
          }());
        }
      }
      for (var start = 0; start < pathItems.length; start += 16) {
        final end =
            start + 16 > pathItems.length ? pathItems.length : start + 16;
        await Future.wait(pathItems.sublist(start, end).map(mergeNfo));
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
    if (todo.isEmpty) return;
    // 检查共享存储权限：未授权时元数据只存 App 沙箱，不尝试写视频旁
    final hasPerm = await LocalVideoService.hasManageExternalStorage();
    if (!hasPerm) {
      AppLogger.warn('后台刮削：未授予"所有文件访问"权限，元数据仅存 App 内部，不写视频旁 .nfo');
    }
    state = state.copyWith(
      scraping: true,
      scrapeDone: 0,
      scrapeTotal: todo.length,
      scrapeOk: 0,
      scrapeFail: 0,
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
            await ScrapeMediaStore.save(item, m, sessionId: 'auto');
            failed.remove(item.pathHash);
            ok++;
          } else {
            failed[item.pathHash] = '未找到匹配';
            await ScrapeMediaStore.recordHistory(
              videoPath: item.path, status: 'failed',
              error: '未找到匹配', sessionId: 'auto');
            fail++;
          }
        } catch (e) {
          failed[item.pathHash] = e.toString();
          await ScrapeMediaStore.recordHistory(
            videoPath: item.path, status: 'failed',
            error: e.toString(), sessionId: 'auto');
          fail++;
        }
        done++;
        if (_mounted) {
          // batch57-F1：以 state.scrapedMap 为基合并本次结果——若直接整体覆盖 cached 副本，
          // 会把 _doRefresh 后台 fetchShowCast 补拉的演员结果覆盖回旧值（无 cast）
          final merged = Map<String, ScrapedMedia>.from(state.scrapedMap)
            ..addAll(cached);
          state = state.copyWith(scrapedMap: merged, scrapeDone: done, failedMap: Map.unmodifiable(failed));
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
      scrapeOk: 0,
      scrapeFail: 0,
    );
    final cached = Map<String, ScrapedMedia>.from(state.scrapedMap);
    final failed = <String, String>{};
    final sessionId = 'retry_${DateTime.now().millisecondsSinceEpoch}';
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
            await ScrapeMediaStore.save(item, m, sessionId: sessionId);
            ok++;
          } else {
            failed[item.pathHash] = '未找到匹配';
            await ScrapeMediaStore.recordHistory(
              videoPath: item.path, status: 'failed',
              error: '未找到匹配', sessionId: sessionId);
            fail++;
          }
        } catch (e) {
          failed[item.pathHash] = e.toString();
          await ScrapeMediaStore.recordHistory(
            videoPath: item.path, status: 'failed',
            error: e.toString(), sessionId: sessionId);
          fail++;
        }
        done++;
        if (_mounted) {
          // batch57-F1：同 scrapeMissing——合并更新而非整体覆盖，保留后台补拉的演员结果
          final merged = Map<String, ScrapedMedia>.from(state.scrapedMap)
            ..addAll(cached);
          state = state.copyWith(scrapedMap: merged, scrapeDone: done, failedMap: Map.unmodifiable(failed));
        }
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));
    if (_mounted) {
      state = state.copyWith(scraping: false, scrapeOk: ok, scrapeFail: fail);
    }
  }

  bool get _mounted => !_disposed;

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
    final removed =
        state.items.where((it) => it.pathHash == pathHash).firstOrNull;
    final items = List.of(state.items)
      ..removeWhere((it) => it.pathHash == pathHash);
    state = state.copyWith(items: items);
    final sp = await SharedPreferences.getInstance();
    // 必须与 LocalVideoService 缓存格式一致（String JSON 数组）：
    // setStringList 会改变键类型，loadCache 的 getString 将返回 null 导致列表读空
    await sp.setString(
      'local_video_cache_v1',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    // 同步清理刮削旁置文件与缓存（与 deleteByIds 三步一致），
    // 否则下次 refresh 扫描重扫磁盘时文件带旧刮削数据回归、旁置 .nfo 成孤儿
    if (removed != null) {
      try {
        await ScrapeMediaStore.delete(removed);
        await sp.remove('scrape_${removed.pathHash}');
      } catch (_) {}
    }
  }

  /// 播放后回填真实时长/分辨率（localDir/App 目录扫描时未取元数据），
  /// 更新内存状态并持久化到缓存；值未变化时直接返回避免无谓写盘。
  Future<void> updateItemMeta(
    String pathHash, {
    Duration? duration,
    int? width,
    int? height,
  }) async {
    final items = state.items;
    final idx = items.indexWhere((e) => e.pathHash == pathHash);
    if (idx < 0) return;
    final cur = items[idx];
    final nd = duration ?? cur.duration;
    final nw = width ?? cur.width;
    final nh = height ?? cur.height;
    if (nd == cur.duration && nw == cur.width && nh == cur.height) return;
    final updated = [...items];
    updated[idx] = cur.copyWith(duration: nd, width: nw, height: nh);
    state = state.copyWith(items: updated);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      'local_video_cache_v1',
      jsonEncode(updated.map((e) => e.toJson()).toList()),
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

  /// 外部刮削完成后更新 scrapedMap（替代直接 .state = 赋值）
  void updateScrapedMap(Map<String, ScrapedMedia> map) {
    state = state.copyWith(scrapedMap: map);
  }

  /// 增量添加单条刮削结果（批量刮削时每完成一个就调一次，实时刷新主页）
  void addScrapedEntry(String pathHash, ScrapedMedia media) {
    final updated = Map<String, ScrapedMedia>.from(state.scrapedMap);
    updated[pathHash] = media;
    state = state.copyWith(scrapedMap: updated);
  }
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

  /// 删除指定 id 的视频（分批并发删除，避免批量多选删除逐项串行卡顿）
  Future<int> deleteByIds(Set<String> ids) async {
    final svc = _ref.read(localVideoServiceProvider);
    final targets = <LocalVideoItem>[];
    for (final id in ids) {
      final item = state.items.where((e) => e.id == id).firstOrNull;
      if (item != null) targets.add(item);
    }
    var ok = 0;
    // 仅移除真正删除成功的项（用户取消系统确认弹窗的不应从列表消失）
    final deletedIds = <String>{};
    const batchSize = 8;
    for (var start = 0; start < targets.length; start += batchSize) {
      final end = start + batchSize > targets.length ? targets.length : start + batchSize;
      await Future.wait(targets.sublist(start, end).map((item) async {
        try {
          if (await svc.delete(item)) {
            ok++;
            deletedIds.add(item.id);
            await ScrapeMediaStore.delete(item);
            // 同时清理 prefs 旧缓存
            final sp = await SharedPreferences.getInstance();
            await sp.remove('scrape_${item.pathHash}');
          }
        } catch (_) {
          // 单项失败不阻塞同批其他项
        }
      }));
    }
    if (ok > 0) {
      state = state.copyWith(
        items: state.items.where((e) => !deletedIds.contains(e.id)).toList(),
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
  LocalFeedSourceIdNotifier() : super(null) {
    _load();
  }
  static const _key = 'local_feed_source_id';

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
