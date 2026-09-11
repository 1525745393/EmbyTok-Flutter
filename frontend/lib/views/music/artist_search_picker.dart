// 同名歌手选择界面（V1.2）
//
// 当搜索到多个同名歌手时，让用户选择正确的歌手。
// 支持 Deezer 和 Last.fm 两个数据源的搜索结果。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist_metadata.dart';
import '../../services/deezer_service.dart';
import '../../services/lastfm_service.dart';
import '../../utils/logger.dart';

/// 歌手搜索结果项
class ArtistSearchResult {
  /// 歌手名称
  final String name;

  /// 歌手头像 URL
  final String? imageUrl;

  /// 数据来源
  final ArtistMetadataSource source;

  /// 额外信息（如听众数、专辑数等）
  final String? extraInfo;

  const ArtistSearchResult({
    required this.name,
    this.imageUrl,
    required this.source,
    this.extraInfo,
  });
}

/// 同名歌手选择界面
///
/// 使用方式：
/// ```dart
/// final selected = await showModalBottomSheet<ArtistSearchResult>(
///   context: context,
///   isScrollControlled: true,
///   builder: (context) => ArtistSearchPicker(
///     searchQuery: '周杰伦',
///     lastFmService: lastFmService,
///     deezerService: deezerService,
///   ),
/// );
/// ```
class ArtistSearchPicker extends ConsumerStatefulWidget {
  /// 搜索关键词（通常是歌手名）
  final String searchQuery;

  /// Last.fm 服务（可空，未配置 API Key 时为空）
  final LastFmService? lastFmService;

  /// Deezer 服务
  final DeezerService deezerService;

  const ArtistSearchPicker({
    super.key,
    required this.searchQuery,
    this.lastFmService,
    required this.deezerService,
  });

  @override
  ConsumerState<ArtistSearchPicker> createState() => _ArtistSearchPickerState();
}

class _ArtistSearchPickerState extends ConsumerState<ArtistSearchPicker> {
  /// 搜索结果
  List<ArtistSearchResult> _results = [];

  /// 是否正在加载
  bool _isLoading = true;

  /// 错误信息
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchArtists();
  }

  /// 搜索歌手（同时搜索 Deezer 和 Last.fm）
  Future<void> _searchArtists() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final results = <ArtistSearchResult>[];
    final seenNames = <String>{};

    try {
      // 1. 搜索 Deezer（无需 API Key，优先）
      final deezerResults = await _searchDeezer(widget.searchQuery);
      for (final result in deezerResults) {
        if (seenNames.add(result.name.toLowerCase())) {
          results.add(result);
        }
      }

      // 2. 搜索 Last.fm（如果已配置 API Key）
      if (widget.lastFmService != null) {
        final lastFmResults = await _searchLastFm(widget.searchQuery);
        for (final result in lastFmResults) {
          if (seenNames.add(result.name.toLowerCase())) {
            results.add(result);
          }
        }
      }

      if (results.isEmpty) {
        _error = '未找到匹配的歌手';
      } else {
        _results = results;
      }
    } catch (e) {
      AppLogger.warn('歌手搜索失败',
          data: {'query': widget.searchQuery, 'error': e.toString()});
      _error = '搜索失败：${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 搜索 Deezer（返回多个匹配结果）
  Future<List<ArtistSearchResult>> _searchDeezer(String query) async {
    try {
      final results = await widget.deezerService.searchArtists(query, limit: 10);
      return results
          .map((info) => ArtistSearchResult(
                name: info.name,
                imageUrl: info.bestImageUrl,
                source: ArtistMetadataSource.deezer,
                extraInfo: info.nbFan != null ? '${info.nbFan} 粉丝' : null,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 搜索 Last.fm
  Future<List<ArtistSearchResult>> _searchLastFm(String query) async {
    try {
      // Last.fm 的 artist.search API 可以返回多个结果
      // 但当前 LastFmService 只实现了 fetchArtistInfo（返回第一个）
      // 这里暂时只返回一个结果，后续可以扩展。
      final info = await widget.lastFmService!.fetchArtistInfo(query);
      if (info == null) return [];
      return [
        ArtistSearchResult(
          name: query,
          imageUrl: info.imageUrl,
          source: ArtistMetadataSource.lastFm,
          extraInfo: 'Last.fm',
        ),
      ];
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖拽条
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择歌手',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 搜索关键词
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '搜索："${widget.searchQuery}"',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 内容区域
              Expanded(
                child: _buildContent(scheme, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建内容区域
  Widget _buildContent(ColorScheme scheme, ScrollController controller) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildResultItem(context, scheme, result);
      },
    );
  }

  /// 构建搜索结果项
  Widget _buildResultItem(
    BuildContext context,
    ColorScheme scheme,
    ArtistSearchResult result,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage:
            result.imageUrl != null ? NetworkImage(result.imageUrl!) : null,
        backgroundColor: scheme.surfaceVariant,
        child: result.imageUrl != null
            ? null
            : Icon(Icons.person, size: 28, color: scheme.onSurfaceVariant),
      ),
      title: Text(
        result.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          // 数据来源标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getSourceColor(result.source).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getSourceLabel(result.source),
              style: TextStyle(
                fontSize: 11,
                color: _getSourceColor(result.source),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (result.extraInfo != null) ...[
            const SizedBox(width: 8),
            Text(
              result.extraInfo!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: () {
        Navigator.of(context).pop(result);
      },
    );
  }

  /// 获取数据来源标签
  String _getSourceLabel(ArtistMetadataSource source) {
    switch (source) {
      case ArtistMetadataSource.lastFm:
        return 'Last.fm';
      case ArtistMetadataSource.deezer:
        return 'Deezer';
      case ArtistMetadataSource.wikipedia:
        return 'Wikipedia';
      case ArtistMetadataSource.synology:
        return '群晖';
      case ArtistMetadataSource.manual:
        return '手动修正';
      case ArtistMetadataSource.none:
        return '未知';
    }
  }

  /// 获取数据来源颜色
  Color _getSourceColor(ArtistMetadataSource source) {
    switch (source) {
      case ArtistMetadataSource.lastFm:
        return const Color(0xFFD51007); // Last.fm 红色
      case ArtistMetadataSource.deezer:
        return const Color(0xFF00C7F2); // Deezer 青色
      case ArtistMetadataSource.wikipedia:
        return const Color(0xFF636466); // Wikipedia 灰色
      case ArtistMetadataSource.synology:
        return const Color(0xFF0088CC); // 群晖蓝色
      case ArtistMetadataSource.manual:
        return Colors.orange; // 手动修正橙色
      case ArtistMetadataSource.none:
        return Colors.grey;
    }
  }
}
