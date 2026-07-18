// 详情、继续观看、Next Up、季/集、演员、类型等 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import 'auth_provider.dart';
import 'cache_providers.dart';

// 公共辅助：初始化带认证信息的 service
// 使用 Ref 而非 WidgetRef，因为 FutureProvider 中使用的是 FutureProviderRef
EmbytokService _authService(Ref ref, AuthState auth) {
  final service = EmbytokService();
  final embyServerUrl = auth.embyServerUrl;
  final userId = auth.user?.id;
  final token = auth.token;
  if (embyServerUrl != null && userId != null && token != null) {
    service.setupAuth(
      embyServerUrl: embyServerUrl,
      userId: userId,
      apiKey: token,
    );
  }
  return service;
}

// ============================
// 项详情 Provider（按 itemId 获取）
// ============================

final itemDetailProvider =
    FutureProvider.family<MediaItem, String>((ref, itemId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) throw '尚未登录';
  // 通过缓存仓库获取详情，减少重复 API 请求
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  return cachedRepo.getItemDetail(
    itemId,
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
    userId: auth.user?.id,
  );
});

// ============================
// 相似影片 Provider（按 itemId）
// ============================

final similarItemsProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, itemId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  return cachedRepo.getSimilarItems(
    itemId,
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
});

// ============================
// 继续观看列表
// ============================

final resumeItemsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  final result = await cachedRepo.getResumeItems(
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
  return result.items;
});

// ============================
// Next Up（下一步看什么）
// ============================

final nextUpProvider = FutureProvider<List<MediaItem>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  final result = await cachedRepo.getNextUp(
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
  return result.items;
});

// ============================
// 类型（Genres）列表
// ============================

final genresListProvider = FutureProvider<List<Library>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <Library>[];
  // 通过缓存仓库获取，减少重复 API 请求（长 TTL 30min）
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  return cachedRepo.getGenres(
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
});

// ============================
// 某类型下的影片
// ============================

final genreItemsProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, genre) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求（中 TTL 5min）
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  final result = await cachedRepo.getItemsByGenre(
    genre,
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
  return result.items;
});

// ============================
// 工作室（Studios）列表
// ============================

final studiosListProvider = FutureProvider<List<Library>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <Library>[];
  // 通过缓存仓库获取，减少重复 API 请求（长 TTL 30min）
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  return cachedRepo.getStudios(
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
});

// ============================
// 某工作室下的影片
// ============================

final studioItemsProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, studio) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求（中 TTL 5min）
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  final result = await cachedRepo.getItemsByStudio(
    studio,
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
  return result.items;
});

// ============================
// 剧集季列表（按 seriesId）
// ============================

final seasonsProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, seriesId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  return cachedRepo.getSeasons(
    seriesId,
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
});

// ============================
// 剧集集列表（按 seriesId + seasonId）
// ============================

class EpisodesQuery {
  final String seriesId;
  final String? seasonId;
  const EpisodesQuery({required this.seriesId, this.seasonId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodesQuery &&
          runtimeType == other.runtimeType &&
          seriesId == other.seriesId &&
          seasonId == other.seasonId;

  @override
  int get hashCode => seriesId.hashCode ^ (seasonId?.hashCode ?? 0);
}

final episodesProvider =
    FutureProvider.family<List<MediaItem>, EpisodesQuery>((ref, query) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <MediaItem>[];
  // 通过缓存仓库获取，减少重复 API 请求
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  final result = await cachedRepo.getEpisodes(
    query.seriesId,
    seasonId: query.seasonId,
    serverUrl: auth.embyServerUrl!,
    token: auth.token!,
  );
  return result.items;
});

// ============================
// 搜索提示
// ============================

final searchHintsProvider =
    FutureProvider.family<List<SearchHint>, String>((ref, query) async {
  if (query.isEmpty) return <SearchHint>[];
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return <SearchHint>[];
  final service = _authService(ref, auth);
  return service.searchHints(query);
});

// ============================
// 标记已看 / 未看
// ============================

Future<void> markItemPlayed(String itemId, Ref ref) async {
  final auth = ref.read(authProvider);
  if (!auth.isAuthenticated) return;
  final service = _authService(ref, auth);
  await service.markAsPlayed(itemId);

  // 失效相关缓存：播放状态变化影响续播、详情、NextUp 和观看历史数据
  final serverUrl = auth.embyServerUrl;
  final token = auth.token;
  if (serverUrl != null && token != null) {
    try {
      final cacheController = ref.read(cacheControllerProvider);
      cacheController.invalidateResume(serverUrl, token);
      cacheController.invalidateItemDetail(itemId, serverUrl);
      cacheController.invalidateNextUp(serverUrl);
      cacheController.invalidateWatchHistory(serverUrl);
    } catch (_) {}
  }

  // 刷新相关 Provider
  ref.invalidate(resumeItemsProvider);
  ref.invalidate(nextUpProvider);
  ref.invalidate(itemDetailProvider(itemId));
}

Future<void> markItemUnplayed(String itemId, Ref ref) async {
  final auth = ref.read(authProvider);
  if (!auth.isAuthenticated) return;
  final service = _authService(ref, auth);
  await service.markAsUnplayed(itemId);

  // 失效相关缓存：标记未看后观看历史需更新
  final serverUrl = auth.embyServerUrl;
  final token = auth.token;
  if (serverUrl != null && token != null) {
    try {
      final cacheController = ref.read(cacheControllerProvider);
      cacheController.invalidateResume(serverUrl, token);
      cacheController.invalidateItemDetail(itemId, serverUrl);
      cacheController.invalidateNextUp(serverUrl);
      cacheController.invalidateWatchHistory(serverUrl);
    } catch (_) {}
  }

  ref.invalidate(resumeItemsProvider);
  ref.invalidate(nextUpProvider);
  ref.invalidate(itemDetailProvider(itemId));
}

// ============================
// 播放设置（选中音轨/字幕）
// ============================

class PlaybackSettings {
  final List<MediaSource>? mediaSources;
  final String? selectedMediaSourceId;
  final int? selectedAudioStreamIndex;
  final int? selectedSubtitleStreamIndex;

  const PlaybackSettings({
    this.mediaSources,
    this.selectedMediaSourceId,
    this.selectedAudioStreamIndex,
    this.selectedSubtitleStreamIndex,
  });

  PlaybackSettings copyWith({
    List<MediaSource>? mediaSources,
    String? selectedMediaSourceId,
    int? selectedAudioStreamIndex,
    int? selectedSubtitleStreamIndex,
  }) {
    return PlaybackSettings(
      mediaSources: mediaSources ?? this.mediaSources,
      selectedMediaSourceId: selectedMediaSourceId ?? this.selectedMediaSourceId,
      selectedAudioStreamIndex: selectedAudioStreamIndex ?? this.selectedAudioStreamIndex,
      selectedSubtitleStreamIndex: selectedSubtitleStreamIndex ?? this.selectedSubtitleStreamIndex,
    );
  }
}

class PlaybackSettingsNotifier extends StateNotifier<PlaybackSettings> {
  PlaybackSettingsNotifier() : super(const PlaybackSettings());

  void resetFromItem(MediaItem item) {
    final sources = item.mediaSources ?? <MediaSource>[];
    final firstId = sources.isNotEmpty ? sources.first.id : null;
    final firstAudioIdx = sources.isNotEmpty && sources.first.audioStreams.isNotEmpty
        ? sources.first.audioStreams.first.index
        : null;
    state = PlaybackSettings(
      mediaSources: sources,
      selectedMediaSourceId: firstId,
      selectedAudioStreamIndex: firstAudioIdx,
      selectedSubtitleStreamIndex: -1,
    );
  }

  void selectMediaSource(String id) {
    state = state.copyWith(selectedMediaSourceId: id);
  }

  void selectAudio(int index) {
    state = state.copyWith(selectedAudioStreamIndex: index);
  }

  void selectSubtitle(int index) {
    state = state.copyWith(selectedSubtitleStreamIndex: index);
  }

  MediaSource? get selectedMediaSource {
    final sources = state.mediaSources;
    if (sources == null || sources.isEmpty) return null;
    final id = state.selectedMediaSourceId;
    if (id == null) return sources.first;
    try {
      return sources.firstWhere((s) => s.id == id);
    } catch (_) {
      return sources.first;
    }
  }
}

final playbackSettingsProvider =
    StateNotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>((ref) {
  return PlaybackSettingsNotifier();
});
