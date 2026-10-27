// TMDB 手动搜索选择页（刮削 P1）
// 长按本地文件 → 输入关键词 → 选择结果 → 落盘元数据 + 写刮削记录
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_video_item.dart';
import '../../services/tmdb_service.dart';
import '../../services/scrape_service.dart';
import '../../services/scrape_media_store.dart';

class TmdbSearchPage extends StatefulWidget {

  const TmdbSearchPage({
    super.key,
    required this.initialQuery,
    required this.pathHash,
    required this.filename,
    this.videoItem,
  });
  final String initialQuery;
  final String pathHash;
  final String filename;
  /// 完整视频项（提供后才会落盘到中央目录和写历史记录）
  final LocalVideoItem? videoItem;

  @override
  State<TmdbSearchPage> createState() => _TmdbSearchPageState();
}

class _TmdbSearchPageState extends State<TmdbSearchPage> {
  late TextEditingController _ctrl;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _type = 'movie'; // movie | tv
  // batch50-F1：请求序号守卫，快速切换类型/连续搜索时丢弃过期响应
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    // 根据文件名自动判断类型
    if (RegExp(r'[Ss]\d{1,2}[Ee]\d{1,2}').hasMatch(widget.filename)) {
      _type = 'tv';
    }
    _search();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_ctrl.text.trim().isEmpty) return;
    final seq = ++_searchSeq;
    setState(() => _loading = true);
    final q = _ctrl.text.trim();
    final results = _type == 'movie'
        ? await TmdbService.searchMovies(q)
        : await TmdbService.searchTv(q);
    // batch50-F1：过期响应丢弃，避免旧类型结果覆盖当前类型
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _select(Map<String, dynamic> result) async {
    final id = result['id'] as int;
    setState(() => _loading = true);
    try {
      // 获取详情
      final details = _type == 'movie'
          ? await TmdbService.getMovieDetails(id)
          : await TmdbService.getTvDetails(id);
      final d = details.isEmpty ? result : details;

      // 提取年份
      final dateStr = d[_type == 'movie' ? 'release_date' : 'first_air_date'] as String?;
      int? year;
      if (dateStr != null && dateStr.length >= 4) {
        year = int.tryParse(dateStr.substring(0, 4));
      }

      // 构造完整 ScrapedMedia
      final media = ScrapedMedia(
        tmdbId: id,
        type: _type,
        title: d[_type == 'movie' ? 'title' : 'name'] ?? '',
        year: year,
        posterPath: d['poster_path'],
        backdropPath: d['backdrop_path'],
        overview: d['overview'],
        rating: (d['vote_average'] as num?)?.toDouble(),
        genres: (d['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? const [],
        cast: ((d['credits']?['cast'] as List?) ?? [])
            .take(10)
            .map((c) => {
                  'id': (c['id'] as num?)?.toString() ?? '',
                  'name': c['name'] as String? ?? '',
                  'role': c['character'] as String? ?? '',
                  'profilePath': c['profile_path'] as String? ?? '',
                })
            .toList(),
        directors: ((d['credits']?['crew'] as List?) ?? [])
            .where((c) => c['job'] == 'Director')
            .map((c) => c['name'] as String)
            .toList(),
        scrapedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // 1) 写 SharedPreferences 缓存（即时刷新 UI）
      final sp = await SharedPreferences.getInstance();
      await sp.setString('scrape_${widget.pathHash}', jsonEncode(media.toJson()));

      // 2) 落盘：中央目录 JSON + 视频旁 .nfo + 海报/头像图片
      if (widget.videoItem != null) {
        await ScrapeMediaStore.save(widget.videoItem!, media);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // batch50-F1：详情获取失败时恢复可操作状态并提示，避免卡 loading
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取详情失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手动匹配 TMDB')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: '输入片名搜索',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'movie', label: Text('电影')),
                    ButtonSegment(value: 'tv', label: Text('剧集')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) {
                    setState(() => _type = s.first);
                    _search();
                  },
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('无结果'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final poster = r['poster_path'] as String?;
                      final title = r[_type == 'movie' ? 'title' : 'name'] ?? '';
                      final date = r[_type == 'movie'
                              ? 'release_date'
                              : 'first_air_date'] ??
                          '';
                      return ListTile(
                        leading: poster != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: TmdbService.posterUrl(poster,
                                      size: 'w92'),
                                  width: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const SizedBox(
                                width: 40, child: Icon(Icons.movie)),
                        title: Text(title, maxLines: 1),
                        subtitle: Text(
                          '$date${(r['overview'] as String? ?? '').isNotEmpty ? ' · ${r['overview']}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _select(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
