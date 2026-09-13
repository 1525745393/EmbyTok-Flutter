// 歌手信息聚合缓存：头像/简介 + 数据出处
//
// 背景：歌手头像/简介来自多个数据源（Last.fm / 群晖 NAS / Wikipedia），
// UI 需要知道「实际用了哪个来源」来标注出处。本缓存统一聚合：
//
// 头像来源优先级：Last.fm 大图 → 群晖 cover.cgi → 无（首字母兜底）
// 简介来源优先级：Last.fm → Wikipedia → 无
//
// 用户可通过歌手详情弹层的「搜索」手动采用某个来源的结果
// （saveOverride），采用结果持久化到 SharedPreferences，
// 之后该歌手始终优先展示用户选择的数据。
//
// 特点：
// - 内存缓存（同一歌手只聚合一次，后续命中同步返回）
// - 并发安全：同一歌手并发请求共享同一个 future
// - 所有网络失败静默降级，不抛异常

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lastfm_service.dart';
import 'lastfm_provider.dart';
import 'synology_auth_provider.dart';

/// 歌手数据出处
enum ArtistInfoSource {
  lastfm('Last.fm'),
  synology('群晖 NAS'),
  wikipedia('Wikipedia'),
  none('');
  const ArtistInfoSource(this.label);

  final String label;
}

/// 歌手聚合信息（含出处标注）
class ArtistInfoResult {

  const ArtistInfoResult({
    this.imageUrl,
    this.imageSource = ArtistInfoSource.none,
    this.bio,
    this.bioSource = ArtistInfoSource.none,
  });
  /// 头像 URL（null = 无，UI 显示首字母兜底）
  final String? imageUrl;
  final ArtistInfoSource imageSource;

  /// 简介（null = 无）
  final String? bio;
  final ArtistInfoSource bioSource;

  /// 序列化为 SharedPreferences JSON
  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'imageSource': imageSource.name,
        'bio': bio,
        'bioSource': bioSource.name,
      };

  static ArtistInfoResult? fromJson(Map<String, dynamic> json) {
    try {
      return ArtistInfoResult(
        imageUrl: json['imageUrl'] as String?,
        imageSource: _sourceByName(json['imageSource'] as String?),
        bio: json['bio'] as String?,
        bioSource: _sourceByName(json['bioSource'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  static ArtistInfoSource _sourceByName(String? name) {
    for (final s in ArtistInfoSource.values) {
      if (s.name == name) return s;
    }
    return ArtistInfoSource.none;
  }
}

/// 歌手信息缓存（Provider 单例）
class ArtistInfoCache {
  ArtistInfoCache(this._ref);

  final Ref _ref;

  /// 歌手名 → 聚合结果（null 表示查询中）
  final Map<String, ArtistInfoResult> _cache = {};
  final Map<String, Future<ArtistInfoResult>> _inflight = {};

  /// 歌手名 → 用户手动采用的结果（内存镜像，持久化在 SharedPreferences）
  final Map<String, ArtistInfoResult> _overrides = {};
  bool _overridesLoaded = false;

  static const _storageKey = 'artist_info_overrides_v1';

  /// 获取歌手聚合信息（缓存命中同步返回；并发查询共享 future）
  Future<ArtistInfoResult> get(String artistName) async {
    final key = artistName.trim();
    if (key.isEmpty) return const ArtistInfoResult();

    // 用户手动采用的结果优先
    await _ensureOverridesLoaded();
    final override = _overrides[key];
    if (override != null) return override;

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

  /// 用户手动采用某个来源的结果（头像/简介），持久化后立即生效
  Future<void> saveOverride(String artistName, ArtistInfoResult result) async {
    final key = artistName.trim();
    if (key.isEmpty) return;
    _overrides[key] = result;
    await _persistOverrides();
  }

  /// 清除用户手动采用（恢复自动聚合）
  Future<void> clearOverride(String artistName) async {
    final key = artistName.trim();
    if (key.isEmpty) return;
    _overrides.remove(key);
    await _persistOverrides();
  }

  Future<void> _ensureOverridesLoaded() async {
    if (_overridesLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            final result = ArtistInfoResult.fromJson(value);
            if (result != null) _overrides[entry.key] = result;
          }
        }
      }
    } catch (e) {
      _overrides.clear();
    }
    _overridesLoaded = true;
  }

  Future<void> _persistOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        for (final e in _overrides.entries) e.key: e.value.toJson(),
      };
      await prefs.setString(_storageKey, jsonEncode(map));
    } catch (e) {
      // 持久化失败仅影响下次启动，当前会话仍生效
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

    // 3. Wikipedia 简介兜底（Last.fm 无简介或简介为空时）
    String? wikiBio;
    if (lastfm?.bio == null || (lastfm?.bio?.isEmpty ?? true)) {
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
      bio: (lastfm?.bio?.isNotEmpty ?? false) ? lastfm!.bio! : wikiBio,
      bioSource: (lastfm?.bio?.isNotEmpty ?? false)
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
