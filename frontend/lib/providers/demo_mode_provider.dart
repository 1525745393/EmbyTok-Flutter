// 演示模式：无服务器浏览完整 UI
//
// 激活后 ApiClient 拦截器返回 mock 数据，所有影片元数据来自 TMDB API。
// 不使用任何本地硬编码影片，TMDB 加载失败时返回空列表。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tmdb_service.dart';

/// 演示模式开关
final demoModeProvider = StateProvider<bool>((ref) => false);

/// TMDB 真实数据缓存（演示模式启动时异步填充）
class DemoTmdbCache {
  static final List<Map<String, dynamic>> movies = [];
  static final List<Map<String, dynamic>> tvShows = [];
  static Map<int, String> genres = {};
  static final List<Map<String, dynamic>> people = [];
  static bool loaded = false;

  static Future<void> load() async {
    if (loaded) return;
    final results = await TmdbService.getTrendingMovies();
    final tv = await TmdbService.getTrendingTv();
    final genreMap = await TmdbService.getGenres();
    final popularPeople = await TmdbService.getPopularPeople();
    // 仅在有影片数据时标记 loaded，失败允许下次重试
    if (results.isNotEmpty || tv.isNotEmpty) {
      movies
        ..clear()
        ..addAll(results);
      tvShows
        ..clear()
        ..addAll(tv);
      genres = genreMap;
      people
        ..clear()
        ..addAll(popularPeople);
      loaded = true;
    }
  }

  /// 所有 TMDB 影片（电影 + 剧集）
  static List<Map<String, dynamic>> get allItems => [...movies, ...tvShows];
}

/// 演示模式 mock 数据生成器（影片数据全部来自 TMDB）
class DemoMockData {
  /// 根据请求路径返回 mock JSON 响应
  static Future<dynamic> handleRequest(String path,
      [Map<String, dynamic>? query]) async {
    // ---- 系统与用户 ----
    if (path.contains('/System/Info/Public')) {
      return {
        'SystemUpdateLevel': 'Release',
        'Version': '10.8.13',
        'ProductName': 'EmbyTok Demo',
        'ServerName': '演示媒体库',
      };
    }
    if (path.contains('/Users') && path.contains('/Policy')) {
      return {'IsAdministrator': true, 'IsDisabled': false};
    }
    if (path.contains('/Users') && path.endsWith('/Views')) {
      return {
        'Items': [
          {'Name': '电影', 'CollectionType': 'movies', 'Id': 'lib_movies'},
          {'Name': '剧集', 'CollectionType': 'tvshows', 'Id': 'lib_tv'},
        ],
        'TotalRecordCount': 2,
      };
    }

    // ---- 媒体库 ----
    if (path.contains('/Library/VirtualFolders')) {
      return [
        {'Name': '电影', 'CollectionType': 'movies'},
        {'Name': '剧集', 'CollectionType': 'tvshows'},
      ];
    }

    // ---- 收藏 GET 列表 ----
    if (path.endsWith('/FavoriteItems') ||
        (path.contains('/FavoriteItems') &&
            !RegExp(r'/FavoriteItems/\w+').hasMatch(path))) {
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }

    // ---- 收藏 POST/DELETE ----
    if (path.contains('/FavoriteItems/') &&
        RegExp(r'/FavoriteItems/\w+').hasMatch(path)) {
      return {'Success': true};
    }

    // ---- 续看 / 最新 / 计数 ----
    if (path.contains('/Items/Resume') || path.endsWith('/Resume')) {
      return _itemList(5, withPosition: true);
    }
    if (path.contains('/Items/Counts')) {
      return {
        'Movie': DemoTmdbCache.movies.length,
        'Series': DemoTmdbCache.tvShows.length,
        'Episode': 0,
      };
    }
    if (path.contains('/Items/Latest') || path.endsWith('/Latest')) {
      // 最新影片 = trending（已在缓存中）
      return _itemList(10, offset: 0);
    }
    if (path.contains('/Shows/NextUp')) {
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }
    if (path.contains('/Shows/Recommended') ||
        path.contains('/Movies/Recommendations') ||
        path.contains('/Suggestions')) {
      // 根据 query 参数选择不同 TMDB 分类
      if (query != null) {
        // 高分影片
        if (query['SortBy'] == 'CommunityRating' ||
            query['MinCommunityRating'] != null) {
          final results = await TmdbService.getMovieList('top_rated');
          if (results.isNotEmpty) {
            final items = results
                .asMap()
                .entries
                .map((e) => _buildTmdbItem(e.value, 400 + e.key))
                .toList();
            return {
              'Items': items,
              'TotalRecordCount': items.length,
              'StartIndex': 0,
            };
          }
        }
        // 即将上映
        if (query['IsAiring'] == 'false' &&
            query['Recursive'] == 'true' &&
            query['SortBy'] == 'PremiereDate,Ascending') {
          final results = await TmdbService.getMovieList('upcoming');
          if (results.isNotEmpty) {
            final items = results
                .asMap()
                .entries
                .map((e) => _buildTmdbItem(e.value, 500 + e.key))
                .toList();
            return {
              'Items': items,
              'TotalRecordCount': items.length,
              'StartIndex': 0,
            };
          }
        }
      }
      return _itemList(10);
    }

    // ---- 相似推荐 ----
    if (path.contains('/Similar')) {
      // 尝试从 /Items/{id}/Similar 提取影片 ID，调 TMDB recommendations
      final simMatch = RegExp(r'/Items/(tmdb_\d+)/Similar').firstMatch(path);
      if (simMatch != null) {
        final idx = int.tryParse(
                simMatch.group(1)!.replaceFirst('tmdb_', '')) ??
            -1;
        final all = DemoTmdbCache.allItems;
        if (idx >= 0 && idx < all.length) {
          final tmdbId = all[idx]['id'] as int?;
          if (tmdbId != null) {
            final recs = await TmdbService.getRecommendations(tmdbId);
            if (recs.isNotEmpty) {
              final items = recs
                  .asMap()
                  .entries
                  .map((e) => _buildTmdbItem(e.value, 200 + e.key))
                  .toList();
              return {
                'Items': items,
                'TotalRecordCount': items.length,
                'StartIndex': 0,
              };
            }
          }
        }
      }
      return _itemList(6, offset: 3);
    }

    // ---- 类型筛选：/Items?Genres=xxx ----
    if (path.contains('/Items') && query != null) {
      final genreName = query['Genres'] as String?;
      if (genreName != null && genreName.isNotEmpty) {
        // 反查 genre ID
        final genreId = DemoTmdbCache.genres.entries
            .firstWhere(
              (e) => e.value == genreName,
              orElse: () => const MapEntry(0, ''),
            )
            .key;
        if (genreId > 0) {
          final results = await TmdbService.discoverByGenre(genreId);
          if (results.isNotEmpty) {
            final items = results
                .asMap()
                .entries
                .map((e) => _buildTmdbItem(e.value, 300 + e.key))
                .toList();
            return {
              'Items': items,
              'TotalRecordCount': items.length,
              'StartIndex': 0,
            };
          }
        }
      }
    }

    // ---- 类型 ----
    if (path.endsWith('/Genres')) {
      if (DemoTmdbCache.genres.isNotEmpty) {
        return {
          'Items': [
            for (var entry in DemoTmdbCache.genres.entries)
              {'Name': entry.value, 'MovieCount': 5, 'Id': 'genre_${entry.key}'}
          ],
          'TotalRecordCount': DemoTmdbCache.genres.length,
        };
      }
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }

    // ---- 演员 ----
    if (path.endsWith('/Persons')) {
      if (DemoTmdbCache.people.isNotEmpty) {
        return {
          'Items': [
            for (var i = 0; i < DemoTmdbCache.people.length; i++)
              {
                'Name': DemoTmdbCache.people[i]['name'] ?? 'Unknown',
                'Type': 'Actor',
                'Id': 'person_popular_$i',
                'PrimaryImageTag':
                    DemoTmdbCache.people[i]['profile_path'] ?? '',
              }
          ],
          'TotalRecordCount': DemoTmdbCache.people.length,
        };
      }
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }

    // ---- 工作室 / 标签 ----
    if (path.contains('/Studios')) {
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }
    if (path.contains('/Tags')) {
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }

    // ---- 搜索 ----
    if (path.contains('/Search/Hints')) {
      final searchTerm = query?['searchTerm'] as String? ?? '';
      if (searchTerm.isNotEmpty && DemoTmdbCache.loaded) {
        final results = await TmdbService.searchMovies(searchTerm);
        if (results.isNotEmpty) {
          final items = results
              .asMap()
              .entries
              .map((e) => _buildTmdbItem(e.value, 100 + e.key))
              .toList();
          return {
            'Items': items,
            'TotalRecordCount': items.length,
            'StartIndex': 0,
          };
        }
      }
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }

    // ---- 单 item 详情 ----
    final singleItemMatch = RegExp(r'/Items/([^/?]+)').firstMatch(path);
    if (singleItemMatch != null) {
      final id = singleItemMatch.group(1)!;
      const reserved = {'Latest', 'Resume', 'Counts', 'Similar', 'Children'};
      if (!reserved.contains(id) && id.startsWith('tmdb_')) {
        final idx = int.tryParse(id.replaceFirst('tmdb_', '')) ?? -1;
        final all = DemoTmdbCache.allItems;
        if (idx >= 0 && idx < all.length) {
          final item = _buildTmdbItem(all[idx], idx);
          // 异步加载真实演职员（导演+演员），替换随机演员
          final tmdbId = all[idx]['id'] as int?;
          if (tmdbId != null) {
            final credits = await TmdbService.getMovieCredits(tmdbId);
            if (credits.isNotEmpty) {
              final castList = (credits['cast'] as List?) ?? [];
              final crewList = (credits['crew'] as List?) ?? [];
              final people = <Map<String, dynamic>>[];
              // 导演
              for (final c in crewList) {
                if (c['job'] == 'Director') {
                  people.add({
                    'Name': c['name'] ?? 'Unknown',
                    'Type': 'Director',
                    'Id': 'person_dir_${tmdbId}',
                    'PrimaryImageTag': c['profile_path'] ?? '',
                  });
                }
              }
              // 前 5 个演员
              for (var i = 0; i < castList.length && i < 5; i++) {
                final c = castList[i] as Map<String, dynamic>;
                people.add({
                  'Name': c['name'] ?? 'Unknown',
                  'Type': 'Actor',
                  'Id': 'person_tmdbcast_${c['id']}',
                  'Role': c['character'] ?? '',
                  'PrimaryImageTag': c['profile_path'] ?? '',
                });
              }
              if (people.isNotEmpty) item['People'] = people;
            }
          }
          return item;
        }
      }
    }

    // ---- 演员详情 /Persons/{id} ----
    final personMatch = RegExp(r'/Persons/(person_\w+)').firstMatch(path);
    if (personMatch != null) {
      final pid = personMatch.group(1)!;
      // 从 popular people 中找
      for (var i = 0; i < DemoTmdbCache.people.length; i++) {
        final p = DemoTmdbCache.people[i];
        if ('person_popular_$i' == pid) {
          return {
            'Name': p['name'] ?? 'Unknown',
            'Type': 'Actor',
            'Id': pid,
            'Overview': p['known_for_department'] ?? 'Actor',
            'Birthday': p['birthday'] ?? '',
            'PlaceOfBirth': p['place_of_birth'] ?? '',
            'ProductionYear':
                p['known_for'] is List && (p['known_for'] as List).isNotEmpty
                    ? 0
                    : 0,
            'ImageTags': {
              'Primary': p['profile_path'] ?? '',
            },
          };
        }
      }
      return {'Name': pid, 'Type': 'Actor', 'Overview': ''};
    }

    // ---- 通用影片列表（兜底）----
    if (path.contains('/Items')) {
      return _itemList(20);
    }

    return null;
  }

  // ---- 辅助方法 ----

  /// 从 TMDB 缓存生成影片列表
  static Map<String, dynamic> _itemList(int count,
      {int offset = 0, bool withPosition = false}) {
    final all = DemoTmdbCache.allItems;
    final total = all.length;
    if (total == 0) {
      return {'Items': <dynamic>[], 'TotalRecordCount': 0, 'StartIndex': 0};
    }
    final items = List.generate(count, (i) {
      final idx = (offset + i) % total;
      return _buildTmdbItem(all[idx], idx, withPosition: withPosition);
    });
    return {'Items': items, 'TotalRecordCount': total, 'StartIndex': 0};
  }

  /// 从 TMDB JSON 构建 Emby item
  static Map<String, dynamic> _buildTmdbItem(Map<String, dynamic> m, int idx,
      {bool withPosition = false}) {
    final isTv = m['title'] == null;
    final poster = m['poster_path'] as String? ?? '';
    final backdrop = m['backdrop_path'] as String? ?? '';
    final release = m['release_date'] ?? m['first_air_date'] ?? '';
    final year = release.isNotEmpty ? int.tryParse(release.substring(0, 4)) : 0;

    // genre_ids → 类型名
    final genreIds = (m['genre_ids'] as List?)?.cast<int>() ?? [];
    final genreNames = genreIds
        .map((id) => DemoTmdbCache.genres[id])
        .whereType<String>()
        .toList();

    // 从热门演员中取 3 个作为本片演员
    final people = DemoTmdbCache.people;
    final cast = <Map<String, dynamic>>[];
    if (people.isNotEmpty) {
      for (var j = 0; j < 3 && j < people.length; j++) {
        final p = people[(idx + j) % people.length];
        cast.add({
          'Name': p['name'] ?? 'Unknown',
          'Type': 'Actor',
          'Id': 'person_tmdb_${idx}_$j',
          'Role': j == 0 ? '主演' : '配角',
          'PrimaryImageTag': p['profile_path'] ?? '',
        });
      }
    }

    return {
      'Id': 'tmdb_$idx',
      'Name': m['title'] ?? m['name'] ?? 'Unknown',
      'Type': isTv ? 'Series' : 'Movie',
      'ProductionYear': year ?? 0,
      'PremiereDate': release,
      'CommunityRating': (m['vote_average'] as num?)?.toDouble() ?? 0.0,
      'Overview': m['overview'] ?? '',
      'Genres': genreNames,
      'Tags': const ['TMDB'],
      'ImageTags': {'Primary': poster, 'Thumb': backdrop},
      'BackdropImageTags': [backdrop],
      'Width': 1920,
      'Height': 1080,
      'UserData': {
        'IsFavorite': idx % 3 == 0,
        'PlaybackPositionTicks': withPosition ? 1800000000 : 0,
        'PlayCount': idx % 2,
      },
      'Studios': const [
        {'Name': 'TMDB Studio', 'Id': 'studio_tmdb'},
      ],
      'MediaSources': [
        {
          'Id': 'src_tmdb_$idx',
          'Name': 'Blu-ray 1080p',
          'Container': 'mkv',
          'Size': 8000000000,
        },
      ],
      'People': cast,
    };
  }
}
