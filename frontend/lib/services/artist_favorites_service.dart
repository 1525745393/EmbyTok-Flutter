// 歌手收藏管理服务
//
// 歌手简介功能 V1.1
// 管理歌手收藏状态，支持本地持久化和 NAS 同步。
//
// 收藏数据存储：
// - 本地：SharedPreferences（key: favorite_artists）
// - NAS：/appdata/EmbTok/favorites/artists.json

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'nas_metadata_sync_service.dart';
import 'synology_audio_api.dart';

/// 歌手收藏管理服务
class ArtistFavoritesService {
  ArtistFavoritesService({
    required SharedPreferences prefs,
    NasMetadataSyncService? nasSyncService,
  })  : _prefs = prefs,
        _nasSyncService = nasSyncService;

  final SharedPreferences _prefs;
  final NasMetadataSyncService? _nasSyncService;

  /// SharedPreferences key
  static const String _prefsKey = 'favorite_artists';

  /// NAS 收藏文件路径
  static const String _nasFavoritesPath =
      '/appdata/EmbTok/favorites/artists.json';

  /// 内存缓存：收藏的歌手名集合
  Set<String> _favorites = {};

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化：从本地加载收藏列表
  Future<void> init() async {
    if (_initialized) return;
    try {
      final jsonStr = _prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        _favorites = list.map((e) => e.toString()).toSet();
      }
      _initialized = true;
      AppLogger.info('歌手收藏初始化完成', data: {'count': _favorites.length});
    } catch (e) {
      AppLogger.error('歌手收藏初始化失败', error: e);
      _initialized = true;
    }
  }

  /// 是否收藏了该歌手
  bool isFavorite(String artistName) {
    return _favorites.contains(artistName.trim());
  }

  /// 获取所有收藏的歌手名
  Set<String> getAllFavorites() {
    return Set.unmodifiable(_favorites);
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(String artistName) async {
    final name = artistName.trim();
    if (name.isEmpty) return false;

    bool newState;
    if (_favorites.contains(name)) {
      _favorites.remove(name);
      newState = false;
    } else {
      _favorites.add(name);
      newState = true;
    }

    // 保存到本地
    await _saveToLocal();

    // 异步同步到 NAS
    _syncToNas();

    return newState;
  }

  /// 保存收藏状态到本地
  Future<void> _saveToLocal() async {
    try {
      await _prefs.setString(_prefsKey, json.encode(_favorites.toList()));
    } catch (e) {
      AppLogger.error('保存歌手收藏到本地失败', error: e);
    }
  }

  /// 同步收藏列表到 NAS
  Future<void> _syncToNas() async {
    if (_nasSyncService == null) return;
    try {
      // TODO: 实现 NAS 收藏同步
      // 暂时只保存到本地
      AppLogger.info('歌手收藏已保存到本地', data: {'count': _favorites.length});
    } catch (e) {
      AppLogger.error('同步歌手收藏到 NAS 失败', error: e);
    }
  }

  /// 从 NAS 下载收藏列表并合并
  Future<void> syncFromNas(SynologyAudioApi api) async {
    if (_nasSyncService == null) return;
    try {
      // TODO: 实现从 NAS 下载收藏列表
      AppLogger.info('从 NAS 同步歌手收藏', data: {'localCount': _favorites.length});
    } catch (e) {
      AppLogger.error('从 NAS 下载歌手收藏失败', error: e);
    }
  }
}
