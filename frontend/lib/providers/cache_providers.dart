// 缓存相关 Provider：统一管理应用级别的缓存配置和实例
//
// 提供的 Provider：
// - mediaRepositoryProvider：基础媒体仓库（EmbyRepository）
// - cachedMediaRepositoryProvider：带缓存的媒体仓库（装饰器模式）
// - cacheControllerProvider：缓存控制器，用于手动失效缓存

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/cached_media_repository.dart';
import '../repositories/emby_repository.dart';
import '../repositories/media_repository.dart';
import '../utils/constants.dart';

/// 基础媒体仓库 Provider
///
/// 默认提供 EmbyRepository 实例，测试时可 override 为 mock。
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return EmbyRepository();
});

/// 带缓存的媒体仓库 Provider
///
/// 使用 CachedMediaRepository 包装基础仓库，为列表查询添加内存缓存。
/// 缓存配置：
/// - TTL：kCacheDefaultTtl（默认 5 分钟）
/// - 最大条目数：kCacheMaxEntries（默认 100）
final cachedMediaRepositoryProvider = Provider<CachedMediaRepository>((ref) {
  final baseRepo = ref.watch(mediaRepositoryProvider);
  return CachedMediaRepository(
    baseRepo,
    ttl: kCacheDefaultTtl,
    maxCacheEntries: kCacheMaxEntries,
  );
});

/// 缓存控制器：提供手动失效缓存的方法
///
/// 使用场景：
/// - 用户下拉刷新（强制刷新）
/// - 用户登出/切换账号
/// - 标记已观看、收藏切换等可能影响列表数据的操作
class CacheController {
  final CachedMediaRepository _cachedRepo;

  CacheController(this._cachedRepo);

  /// 清除所有缓存
  void invalidateAll() {
    _cachedRepo.clearAll();
  }

  /// 失效指定媒体库的列表缓存
  void invalidateLibrary(String libraryId, String serverUrl) {
    _cachedRepo.invalidateLibraryItems(
      libraryId: libraryId,
      serverUrl: serverUrl,
    );
  }

  /// 失效收藏缓存（影片 + 合集 + 人物）
  ///
  /// toggleFavorite 后调用，统一失效三类收藏缓存。
  /// 之前的 invalidateFavoritePeople 已合并到此处，避免调用方需要分别调用。
  void invalidateFavorites(String serverUrl, String token, String? userId) {
    _cachedRepo.invalidateFavorites(
      serverUrl: serverUrl,
      token: token,
      userId: userId,
    );
  }

  /// 失效续播列表缓存
  void invalidateResume(String serverUrl, String token) {
    _cachedRepo.invalidateResume(
      serverUrl: serverUrl,
      token: token,
    );
  }

  /// 失效单个媒体条目的详情缓存
  void invalidateItemDetail(String itemId, String serverUrl) {
    _cachedRepo.invalidateItemDetail(
      itemId: itemId,
      serverUrl: serverUrl,
    );
  }

  /// 失效 NextUp 缓存
  void invalidateNextUp(String serverUrl) {
    _cachedRepo.invalidateNextUp(serverUrl: serverUrl);
  }

  /// 失效剧集相关缓存（季 + 集）
  void invalidateSeries(String seriesId, String serverUrl) {
    _cachedRepo.invalidateSeries(seriesId: seriesId, serverUrl: serverUrl);
  }

  /// 失效演员作品列表缓存
  ///
  /// 用于 markAsPlayed/markAsUnplayed 后，确保演员作品页的观看状态及时更新。
  void invalidatePersonItems(String serverUrl) {
    _cachedRepo.invalidatePersonItems(serverUrl: serverUrl);
  }

  /// 失效观看历史缓存
  ///
  /// 用于 markAsPlayed/reportPlaybackStopped/toggleFavorite 后，
  /// 确保观看历史及时更新。
  void invalidateWatchHistory(String serverUrl) {
    _cachedRepo.invalidateWatchHistory(serverUrl: serverUrl);
  }

  /// 失效子项列表缓存
  ///
  /// 用于 BoxSet 子项结构变化时（如添加/移除子项）。
  void invalidateChildren(String serverUrl) {
    _cachedRepo.invalidateChildren(serverUrl: serverUrl);
  }
}

/// 缓存控制器 Provider
final cacheControllerProvider = Provider<CacheController>((ref) {
  final cachedRepo = ref.watch(cachedMediaRepositoryProvider);
  return CacheController(cachedRepo);
});
