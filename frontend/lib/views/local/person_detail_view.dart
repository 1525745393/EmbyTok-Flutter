import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/tmdb_service.dart';

/// 演员详情页（本地模式，基于 TMDB）
class PersonDetailPage extends StatefulWidget {
  final int personId;
  final String name;
  final String? profilePath;

  const PersonDetailPage({
    super.key,
    required this.personId,
    required this.name,
    this.profilePath,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  Map<String, dynamic>? _details;
  Map<String, dynamic>? _credits;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      TmdbService.getPersonDetails(widget.personId),
      TmdbService.getPersonCredits(widget.personId),
    ]);
    if (mounted) {
      setState(() {
        _details = results[0];
        _credits = results[1];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bio = _details?['biography'] as String?;
    final birthday = _details?['birthday'] as String?;
    final place = _details?['place_of_birth'] as String?;
    final alsoKnown = (_details?['also_known_as'] as List?)?.cast<String>() ?? [];

    final castList = (_credits?['cast'] as List?) ?? [];
    final movies = castList
        .where((c) => c['media_type'] == 'movie')
        .toList()
      ..sort((a, b) => ((b['vote_count'] as num?) ?? 0)
          .compareTo((a['vote_count'] as num?) ?? 0));
    final tvs = castList
        .where((c) => c['media_type'] == 'tv')
        .toList()
      ..sort((a, b) => ((b['vote_count'] as num?) ?? 0)
          .compareTo((a['vote_count'] as num?) ?? 0));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.profilePath != null
                      ? CachedNetworkImage(
                          imageUrl: TmdbService.personUrl(widget.profilePath!, size: 'h632'),
                          fit: BoxFit.cover,
                        )
                      : Container(color: scheme.surfaceContainerHighest),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Text(
                      _details?['name'] as String? ?? widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (_details == null && _credits == null)
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.person_off, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text('暂无法获取演员信息',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 基本信息
                        if (birthday != null || place != null)
                          Wrap(
                            spacing: 12,
                            children: [
                              if (birthday != null)
                                Text(birthday, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              if (place != null)
                                Text(place, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            ],
                          ),
                        if (alsoKnown.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('别名: ${alsoKnown.take(3).join("、")}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                        const SizedBox(height: 16),
                        // 简介
                        if (bio != null && bio.isNotEmpty) ...[
                          const Text('简介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            bio,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.6),
                          ),
                          const SizedBox(height: 24),
                        ],
                        // 电影
                        if (movies.isNotEmpty) ...[
                          Text('电影（${movies.length}）',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: movies.take(20).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, i) {
                                final m = movies[i] as Map<String, dynamic>;
                                final poster = m['poster_path'] as String?;
                                return SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: poster != null
                                            ? CachedNetworkImage(
                                                imageUrl: TmdbService.posterUrl(poster, size: 'w185'),
                                                height: 150,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                height: 150,
                                                color: scheme.surfaceContainerHighest,
                                                child: const Icon(Icons.movie),
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        m['title'] as String? ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        (m['release_date'] as String? ?? '').isNotEmpty
                                            ? m['release_date'].toString().substring(0, 4)
                                            : '',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        // 电视剧
                        if (tvs.isNotEmpty) ...[
                          Text('电视剧（${tvs.length}）',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: tvs.take(20).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, i) {
                                final t = tvs[i] as Map<String, dynamic>;
                                final poster = t['poster_path'] as String?;
                                return SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: poster != null
                                            ? CachedNetworkImage(
                                                imageUrl: TmdbService.posterUrl(poster, size: 'w185'),
                                                height: 150,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                height: 150,
                                                color: scheme.surfaceContainerHighest,
                                                child: const Icon(Icons.tv),
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t['name'] as String? ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        (t['first_air_date'] as String? ?? '').isNotEmpty
                                            ? t['first_air_date'].toString().substring(0, 4)
                                            : '',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
