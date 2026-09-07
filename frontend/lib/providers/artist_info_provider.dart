// 歌手信息聚合缓存：头像/简介 + 数据出处
//
// 背景：歌手头像/简介来自多个数据源（Last.fm / 群晖 NAS / Wikipedia），
// UI 需要知道「实际用了哪个来源」来标注出处。本缓存统一聚合：
//
// 头像来源优先级：Last.fm 大图 → 群晖 cover.cgi → 无（首字母兜底）
// 简介来源优先级：Last.fm → Wikipedia → 无
//
// 特点：
// - 内存缓存（同一歌手只聚合一次，后续命中同步返回）
// - 并发安全：同一歌手并发请求共享同一个 future
// - 所有网络失败静默降级，不抛异常

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lastfm_service.dart';
import 'lastfm_provider.dart';
import 'synology_auth_provider.dart';

/// 歌手数据出处
enum ArtistInfoSource {
  lastfm('Last.fm'),
  synology('群晖 NAS'),
  wikipedia('Wikipedia'),
  none('');

  final String label;
  const ArtistInfoSource(this.label);
}

/// 歌手聚合信息（含出处标注）
class ArtistInfoResult {
  /// 头像 URL（null = 无，UI 显示首字母兜底）
  final String? imageUrl;
  final ArtistInfoSource imageSource;

  /// 简介（null = 无）
  final String? bio;
  final ArtistInfoSource bioSource;

  const ArtistInfoResult({
    this.imageUrl,
    this.imageSource = ArtistInfoSource.none,
    this.bio,
    this.bioSource = ArtistInfoSource.none,
  });
}

/// 歌手信息缓存（Provider 单例）
class ArtistInfoCache {
  ArtistInfoCache(this._ref);

  final Ref _ref;

  /// 歌手名 → 聚合结果（null 表示查询中）
  final Map<String, ArtistInfoResult> _cache = {};
  final Map<String, Future<ArtistInfoResult>> _inflight = {};

  /// 获取歌手聚合信息（缓存命中同步返回；并发查询共享 future）
  Future<ArtistInfoResult> get(String artistName) async {
    final key = artistName.trim();
    if (key.isEmpty) return const ArtistInfoResult();
    final cached = _cache[key];
    if (cached != null) return cached;
    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final future = _fetch(key);
    _inflight[key] = future;
    try {
      final result = await future;
      _cache[key] = result;
      return result;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<ArtistInfoResult> _fetch(String key) async {
    // 1. Last.fm（头像 + 简介，需配置 API Key）
    LastFmArtistInfo? lastfm;
    final lastfmService = _ref.read(lastfmServiceProvider);
    if (lastfmService != null) {
      try {
        lastfm = await lastfmService.fetchArtistInfo(key);
      } catch (_) {
        lastfm = null;
      }
    }

    // 2. 群晖原生头像 URL（同步构造，纯 URL 不请求）
    String? synoUrl;
    try {
      synoUrl =
          _ref.read(synologyAuthProvider.notifier).api.getArtistCoverUrl(key);
    } catch (_) {
      synoUrl = null;
    }

    // 3. Wikipedia 简介兜底（Last.fm 无简介时）
    String? wikiBio;
    if (lastfm?.bio == null) {
      try {
        wikiBio =
            (await _ref.read(artistInfoServiceProvider).fetchArtistInfo(key))
                ?.bio;
      } catch (_) {
        wikiBio = null;
      }
    }

    return ArtistInfoResult(
      imageUrl: lastfm?.imageUrl ?? synoUrl,
      imageSource: lastfm?.imageUrl != null
          ? ArtistInfoSource.lastfm
          : (synoUrl != null
              ? ArtistInfoSource.synology
              : ArtistInfoSource.none),
      bio: lastfm?.bio ?? wikiBio,
      bioSource: lastfm?.bio != null
          ? ArtistInfoSource.lastfm
          : (wikiBio != null
              ? ArtistInfoSource.wikipedia
              : ArtistInfoSource.none),
    );
  }
}

/// 歌手信息缓存 Provider（全局单例）
final artistInfoCacheProvider = Provider<ArtistInfoCache>((ref) {
  return ArtistInfoCache(ref);
});
