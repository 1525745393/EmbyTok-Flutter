// TMDB 手动搜索选择页（刮削 P1）
// 长按本地文件 → 输入关键词 → 选择结果 → 更新缓存
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/tmdb_service.dart';

class TmdbSearchPage extends StatefulWidget {

  const TmdbSearchPage({
    super.key,
    required this.initialQuery,
    required this.pathHash,
    required this.filename,
  });
  final String initialQuery;
  final String pathHash;
  final String filename;

  @override
  State<TmdbSearchPage> createState() => _TmdbSearchPageState();
}

class _TmdbSearchPageState extends State<TmdbSearchPage> {
  late TextEditingController _ctrl;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _type = 'movie'; // movie | tv

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

  Future<void> _search() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final q = _ctrl.text.trim();
    final results = _type == 'movie'
        ? await TmdbService.searchMovies(q)
        : await TmdbService.searchTv(q);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _select(Map<String, dynamic> item) async {
    final id = item['id'] as int;
    // 获取详情
    final details = _type == 'movie'
        ? await TmdbService.getMovieDetails(id)
        : await TmdbService.getTvDetails(id);
    final d = details.isEmpty ? item : details;
    // 保存到缓存
    final sp = await SharedPreferences.getInstance();
    final data = {
      'tmdbId': id,
      'type': _type,
      'title': d[_type == 'movie' ? 'title' : 'name'] ?? '',
      'year': null,
      'posterPath': d['poster_path'],
      'backdropPath': d['backdrop_path'],
      'overview': d['overview'],
      'rating': (d['vote_average'] as num?)?.toDouble(),
      'genres': (d['genres'] as List?)?.map((g) => g['name'] as String).toList() ?? [],
      'cast': ((d['credits']?['cast'] as List?) ?? [])
          .take(10)
          .map((c) => {
                'name': c['name'] as String? ?? '',
                'role': c['character'] as String? ?? '',
              })
          .toList(),
      'scrapedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await sp.setString('scrape_${widget.pathHash}', jsonEncode(data));
    if (mounted) Navigator.pop(context, true);
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
