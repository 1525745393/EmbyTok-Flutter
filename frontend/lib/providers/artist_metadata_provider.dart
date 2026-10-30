// 歌手元数据 Provider
//
// 歌手简介功能 V1.0
// 提供 ArtistMetadataService 实例和歌手元数据的异步加载状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artist_metadata.dart';
import '../models/audio_models.dart';
import '../services/artist_metadata_service.dart';
import '../services/lastfm_service.dart';
import 'synology_auth_provider.dart';

/// ArtistMetadataService 单例 Provider
final artistMetadataServiceProvider = Provider<ArtistMetadataService>((ref) {
  final lastFmService = ref.watch(lastFmServiceProvider);
  final synologyApi = ref.watch(synologyAuthProvider.notifier).api;
  final service = ArtistMetadataService(
    lastFmService: lastFmService,
    synologyApi: synologyApi,
  );
  // 异步初始化（加载 SharedPreferences）
  service.init();
  return service;
});

/// 歌手元数据异步加载 Provider（family 模式，按歌手名缓存）
///
/// 使用方式：
/// ```dart
/// final metadata = ref.watch(artistMetadataProvider('周杰伦'));
/// metadata.when(
///   data: (data) => Text(data.bioSummary ?? '暂无简介'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('加载失败'),
/// );
/// ```
final artistMetadataProvider =
    FutureProvider.family<ArtistMetadata, String>((ref, artistName) async {
  final service = ref.watch(artistMetadataServiceProvider);
  return service.getArtistMetadata(artistName);
});

/// 歌手歌曲列表 Provider（family 模式，按歌手名筛选）
///
/// 循环分页拉全量：NAS 单次 getSongs 上限 200，歌手歌曲超过该数时若只取
/// 一页，详情页歌曲列表与「播放全部」会被静默截断（与 watchlist/favorites
/// 单页截断同族缺陷，此处统一按 offset 递增拉全量）。
final artistSongsProvider =
    FutureProvider.family<List<AudioSong>, String>((ref, artistName) async {
  final isLoggedIn = ref.read(synologyAuthProvider).isLoggedIn;
  if (!isLoggedIn) return [];
  final api = ref.read(synologyAuthProvider.notifier).api;
  const pageSize = 200;
  final all = <AudioSong>[];
  var offset = 0;
  while (true) {
    final page =
        await api.getSongs(artist: artistName, limit: pageSize, offset: offset);
    all.addAll(page);
    if (page.length < pageSize) break;
    offset += page.length;
  }
  return all;
});

/// 歌手专辑列表 Provider（family 模式，按歌手名筛选）
///
/// 注意：getAlbums 不支持按歌手筛选，获取所有专辑后在本地过滤；
/// 循环分页拉全量：NAS 单次 getAlbums 上限 200，专辑总数超过该数时
/// 若只取一页（旧实现 limit 500），名称排序靠后的专辑会缺失，导致
/// 该歌手的部分专辑从详情页专辑区与专辑详情弹层消失。
final artistAlbumsProvider =
    FutureProvider.family<List<AudioAlbum>, String>((ref, artistName) async {
  final isLoggedIn = ref.read(synologyAuthProvider).isLoggedIn;
  if (!isLoggedIn) return [];
  final api = ref.read(synologyAuthProvider.notifier).api;
  const pageSize = 200;
  final allAlbums = <AudioAlbum>[];
  var offset = 0;
  while (true) {
    final page = await api.getAlbums(limit: pageSize, offset: offset);
    allAlbums.addAll(page);
    if (page.length < pageSize) break;
    offset += page.length;
  }
  // 在本地按歌手名筛选（匹配 albumArtist 或 artist 或 displayArtist）
  return allAlbums
      .where((album) =>
          album.albumArtist?.contains(artistName) == true ||
          album.artist?.contains(artistName) == true ||
          album.displayArtist?.contains(artistName) == true)
      .toList();
});

/// Last.fm 服务 Provider（可能为 null，未配置 API Key 时）
final lastFmServiceProvider = Provider<LastFmService?>((ref) {
  // 从配置中读取 Last.fm API Key
  // TODO: 集成到设置页的 Last.fm API Key 配置
  const apiKey = String.fromEnvironment('LASTFM_API_KEY');
  if (apiKey.isEmpty) return null;
  return LastFmService(apiKey: apiKey);
});
