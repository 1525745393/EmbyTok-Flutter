// 演示模式：无服务器浏览完整 UI
//
// 激活后 ApiClient 拦截器返回预设 mock 数据，所有页面可正常浏览。
// 优先从 TMDB API 获取真实影片数据（海报/简介/评分），失败回退本地硬编码。
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
}

/// 演示模式 mock 数据生成器
class DemoMockData {
  // 真实热门影片库（片名、年份、类型、简介、导演、主演）
  static const List<Map<String, dynamic>> _movies = [
    {
      'name': '星际穿越',
      'year': 2014,
      'genres': ['科幻', '冒险', '剧情'],
      'overview': '一队探险家利用他们针对虫洞的新发现，超越人类对于太空旅行的极限，从而开始在广袤的宇宙中进行星际航行。',
      'director': '克里斯托弗·诺兰',
      'actors': ['马修·麦康纳', '安妮·海瑟薇', '杰西卡·查斯坦'],
      'rating': 8.7,
      'officialRating': 'PG-13',
    },
    {
      'name': '盗梦空间',
      'year': 2010,
      'genres': ['科幻', '动作', '悬疑'],
      'overview': '造梦师多姆·柯布带领团队进入他人梦境，窃取或植入思想。当一次任务反转，他必须完成不可能的盗梦任务以换取回家的机会。',
      'director': '克里斯托弗·诺兰',
      'actors': ['莱昂纳多·迪卡普里奥', '约瑟夫·高登-莱维特', '艾伦·佩吉'],
      'rating': 9.4,
      'officialRating': 'PG-13',
    },
    {
      'name': '肖申克的救赎',
      'year': 1994,
      'genres': ['剧情', '犯罪'],
      'overview': '银行家安迪被冤枉杀妻，在肖申克监狱中度过二十年，始终心怀希望，最终用一把小锤子凿出自由之路。',
      'director': '弗兰克·德拉邦特',
      'actors': ['蒂姆·罗宾斯', '摩根·弗里曼'],
      'rating': 9.7,
      'officialRating': 'R',
    },
    {
      'name': '泰坦尼克号',
      'year': 1997,
      'genres': ['剧情', '爱情', '灾难'],
      'overview': '穷画家杰克和贵族女露丝在泰坦尼克号上相爱，这艘"永不沉没"的巨轮在处女航中撞上冰山，演绎一段永恒的爱情悲剧。',
      'director': '詹姆斯·卡梅隆',
      'actors': ['莱昂纳多·迪卡普里奥', '凯特·温丝莱特'],
      'rating': 9.5,
      'officialRating': 'PG-13',
    },
    {
      'name': '阿凡达',
      'year': 2009,
      'genres': ['科幻', '动作', '冒险'],
      'overview': '人类退伍军人杰克通过阿凡达意识连接潘多拉星球，在与纳美人的接触中逐渐认同他们的立场，最终带领纳美人保卫家园。',
      'director': '詹姆斯·卡梅隆',
      'actors': ['萨姆·沃辛顿', '佐伊·索尔达娜', '西格妮·韦弗'],
      'rating': 8.9,
      'officialRating': 'PG-13',
    },
    {
      'name': '流浪地球2',
      'year': 2023,
      'genres': ['科幻', '冒险', '灾难'],
      'overview': '太阳即将毁灭，人类启动"流浪地球"计划，推着地球逃离太阳系寻找新家园。这是前传，讲述危机初现时的抉择与牺牲。',
      'director': '郭帆',
      'actors': ['吴京', '刘德华', '李雪健'],
      'rating': 8.3,
      'officialRating': 'PG-13',
    },
    {
      'name': '满江红',
      'year': 2023,
      'genres': ['剧情', '喜剧', '悬疑'],
      'overview': '南宋绍兴年间，岳飞死后四年，秦桧率兵与金国会谈。会谈前夜，金国使者死在驿馆，密信失踪，小兵张大与亲兵营副统领孙均被裹挟进巨大阴谋。',
      'director': '张艺谋',
      'actors': ['沈腾', '易烊千玺', '张译'],
      'rating': 7.0,
      'officialRating': 'PG-13',
    },
    {
      'name': '长津湖',
      'year': 2021,
      'genres': ['剧情', '历史', '战争'],
      'overview': '抗美援朝战争第二次战役东线，中国人民志愿军第9兵团在极寒严酷环境下，凭着钢铁意志和英勇无畏的战斗精神，扭转战场态势。',
      'director': '陈凯歌 / 徐克 / 林超贤',
      'actors': ['吴京', '易烊千玺', '段奕宏'],
      'rating': 7.4,
      'officialRating': 'PG-13',
    },
    {
      'name': '少年派的奇幻漂流',
      'year': 2012,
      'genres': ['剧情', '奇幻', '冒险'],
      'overview': '少年派在海难后与一只孟加拉虎同乘一艘救生艇，在太平洋上漂流227天，这段旅程既是生存之战，也是信仰与心灵的探索。',
      'director': '李安',
      'actors': ['苏拉·沙玛', '伊尔凡·可汗'],
      'rating': 9.1,
      'officialRating': 'PG',
    },
    {
      'name': '让子弹飞',
      'year': 2010,
      'genres': ['剧情', '喜剧', '动作'],
      'overview': '民国年间，土匪张麻子冒充县长马邦德上任鹅城，与恶霸黄四郎展开一场惊心动魄的博弈。',
      'director': '姜文',
      'actors': ['姜文', '葛优', '周润发'],
      'rating': 9.0,
      'officialRating': 'R',
    },
  ];

  static const List<Map<String, dynamic>> _tvShows = [
    {
      'name': '权力的游戏',
      'year': 2011,
      'genres': ['剧情', '奇幻', '冒险'],
      'overview': '维斯特洛大陆上，各大家族为争夺铁王座展开血腥博弈，而真正的威胁来自北方绝境长城之外。',
      'director': '大卫·贝尼奥夫',
      'actors': ['基特·哈灵顿', '艾米莉亚·克拉克', '彼特·丁拉基'],
      'rating': 9.3,
      'officialRating': 'TV-MA',
    },
    {
      'name': '绝命毒师',
      'year': 2008,
      'genres': ['剧情', '犯罪', '惊悚'],
      'overview': '高中化学老师沃尔特·怀特确诊癌症后，为给家人留下财产制造冰毒，一步步从老实人沦为毒枭"海森堡"。',
      'director': '文斯·吉里根',
      'actors': ['布莱恩·科兰斯顿', '亚伦·保尔'],
      'rating': 9.6,
      'officialRating': 'TV-MA',
    },
    {
      'name': '三体',
      'year': 2023,
      'genres': ['科幻', '悬疑'],
      'overview': '纳米科学家汪淼被警方协助调查科学家自杀案，由此揭开地外文明"三体"对地球的入侵预警，人类文明面临终极抉择。',
      'director': '杨磊',
      'actors': ['张鲁一', '于和伟', '陈瑾'],
      'rating': 8.7,
      'officialRating': 'TV-14',
    },
    {
      'name': '沉默的真相',
      'year': 2020,
      'genres': ['剧情', '悬疑', '犯罪'],
      'overview': '一起地铁抛尸案牵扯出多年前的支教老师遇害案，检察官江阳以生命为代价，历经七载终将真相大白。',
      'director': '陈奕甫',
      'actors': ['廖凡', '白宇', '谭卓'],
      'rating': 9.1,
      'officialRating': 'TV-MA',
    },
    {
      'name': '漫长的季节',
      'year': 2023,
      'genres': ['剧情', '犯罪'],
      'overview': '东北小城桦林，出租车司机王响在碎尸案调查中揭开18年前的往事，三个老人在命运的洪流中与时代和解。',
      'director': '辛爽',
      'actors': ['范伟', '秦昊', '陈明昊'],
      'rating': 9.4,
      'officialRating': 'TV-MA',
    },
  ];

  static const List<String> _allGenres = [
    '剧情', '喜剧', '动作', '科幻', '悬疑', '爱情', '犯罪', '惊悚',
    '冒险', '奇幻', '战争', '历史', '动画', '纪录片',
  ];

  /// 根据请求路径返回 mock JSON 响应
  static dynamic handleRequest(String path,
      [Map<String, dynamic>? query]) {
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
      return {'Movie': _movies.length, 'Series': _tvShows.length, 'Episode': 42};
    }
    if (path.contains('/Items/Latest') || path.endsWith('/Latest')) {
      return _itemList(6, offset: 5);
    }
    if (path.contains('/Shows/NextUp')) {
      return _itemList(3, type: 'Episode');
    }
    if (path.contains('/Shows/Recommended') ||
        path.contains('/Movies/Recommendations') ||
        path.contains('/Suggestions')) {
      return _itemList(8, offset: 2);
    }

    // ---- 相似推荐 ----
    if (path.contains('/Similar')) {
      return _itemList(6, offset: 3);
    }

    // ---- 类型 / 演员 / 工作室 / 标签 ----
    if (path.endsWith('/Genres')) {
      // 优先用 TMDB 真实类型
      if (DemoTmdbCache.genres.isNotEmpty) {
        return {
          'Items': [
            for (var entry in DemoTmdbCache.genres.entries)
              {'Name': entry.value, 'MovieCount': 5, 'Id': 'genre_${entry.key}'}
          ],
          'TotalRecordCount': DemoTmdbCache.genres.length,
        };
      }
      return {
        'Items': [for (var g in _allGenres) {'Name': g, 'MovieCount': 3}],
        'TotalRecordCount': _allGenres.length,
      };
    }
    if (path.endsWith('/Persons')) {
      // 优先用 TMDB 热门演员
      if (DemoTmdbCache.people.isNotEmpty) {
        return {
          'Items': [
            for (var i = 0; i < DemoTmdbCache.people.length; i++)
              {
                'Name': DemoTmdbCache.people[i]['name'] ?? 'Unknown',
                'Type': 'Actor',
                'Id': 'person_popular_$i',
                'PrimaryImageTag': DemoTmdbCache.people[i]['profile_path'] ?? '',
              }
          ],
          'TotalRecordCount': DemoTmdbCache.people.length,
        };
      }
      final allActors = <String>{};
      for (var m in _movies) {
        allActors.addAll((m['actors'] as List).cast<String>());
      }
      for (var t in _tvShows) {
        allActors.addAll((t['actors'] as List).cast<String>());
      }
      final list = allActors.toList();
      return {
        'Items': [
          for (var i = 0; i < list.length; i++)
            {'Name': list[i], 'Type': 'Actor', 'Id': 'person_$i'}
        ],
        'TotalRecordCount': list.length,
      };
    }
    if (path.contains('/Studios')) {
      return {
        'Items': [
          {'Name': '华纳兄弟', 'Id': 'studio_wb'},
          {'Name': '传奇影业', 'Id': 'studio_legend'},
          {'Name': 'Netflix', 'Id': 'studio_nf'},
        ],
        'TotalRecordCount': 3,
      };
    }
    if (path.contains('/Tags')) {
      return {
        'Items': [
          for (var t in ['4K 超清', 'HDR', '杜比全景声', '导演剪辑版', '经典重温'])
            {'Name': t}
        ],
        'TotalRecordCount': 5,
      };
    }

    // ---- 搜索 ----
    if (path.contains('/Search/Hints')) {
      return _itemList(4);
    }

    // ---- 单 item 详情 ----
    final singleItemMatch = RegExp(r'/Items/([^/?]+)').firstMatch(path);
    if (singleItemMatch != null) {
      final id = singleItemMatch.group(1)!;
      const reserved = {'Latest', 'Resume', 'Counts', 'Similar', 'Children'};
      if (!reserved.contains(id)) {
        // TMDB 数据
        if (id.startsWith('tmdb_')) {
          final idx = int.tryParse(id.replaceFirst('tmdb_', '')) ?? 0;
          final tmdbAll = [
            ...DemoTmdbCache.movies,
            ...DemoTmdbCache.tvShows,
          ];
          if (idx < tmdbAll.length) {
            return _buildTmdbItem(tmdbAll[idx], idx);
          }
        }
        final index = int.tryParse(id.replaceAll('demo_', '')) ?? 0;
        return _buildItem(index);
      }
    }

    // ---- 通用影片列表（兜底）----
    if (path.contains('/Items')) {
      return _itemList(10);
    }

    return null;
  }

  // ---- 辅助方法 ----

  static Map<String, dynamic> _itemList(int count,
      {int offset = 0, String type = 'Movie', bool withPosition = false}) {
    // 优先使用 TMDB 真实数据
    if (DemoTmdbCache.movies.isNotEmpty || DemoTmdbCache.tvShows.isNotEmpty) {
      final tmdbAll = [
        ...DemoTmdbCache.movies,
        ...DemoTmdbCache.tvShows,
      ];
      final total = tmdbAll.length;
      if (total > 0) {
        final items = List.generate(count, (i) {
          final idx = (offset + i) % total;
          return _buildTmdbItem(tmdbAll[idx], idx, withPosition: withPosition);
        });
        return {'Items': items, 'TotalRecordCount': total, 'StartIndex': 0};
      }
    }
    // 回退本地硬编码
    final total = _movies.length + _tvShows.length;
    final items = List.generate(count, (i) {
      final idx = (offset + i) % total;
      return _buildItem(idx, withPosition: withPosition);
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
          'Type': j == 0 ? 'Actor' : 'Actor',
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

  /// 从本地硬编码影片库构建 Emby item
  static Map<String, dynamic> _buildItem(int i, {bool withPosition = false}) {
    final total = _movies.length + _tvShows.length;
    final idx = i % total;
    final isTv = idx >= _movies.length;
    final data = isTv ? _tvShows[idx - _movies.length] : _movies[idx];
    final seed = 'embytok_$idx';

    return {
      'Id': 'demo_$idx',
      'Name': data['name'],
      'Type': isTv ? 'Series' : 'Movie',
      'ProductionYear': data['year'],
      'PremiereDate': '${data['year']}-06-15',
      'CommunityRating': data['rating'],
      'CriticRating': ((data['rating'] as double) * 10).toInt(),
      'OfficialRating': data['officialRating'],
      'RunTimeTicks': isTv ? 36000000000 : 60000000000,
      'Overview': data['overview'],
      'Genres': data['genres'],
      'Tags': const ['4K 超清'],
      'ImageTags': {'Primary': seed, 'Thumb': '${seed}_thumb'},
      'BackdropImageTags': ['${seed}_bg'],
      'Width': 1920,
      'Height': 1080,
      'UserData': {
        'IsFavorite': idx % 3 == 0,
        'PlaybackPositionTicks': withPosition ? 1800000000 : 0,
        'PlayCount': idx % 2,
      },
      'People': [
        {
          'Name': data['director'],
          'Type': 'Director',
          'Id': 'person_dir_$idx'
        },
        for (var j = 0; j < (data['actors'] as List).length; j++)
          {
            'Name': data['actors'][j],
            'Type': 'Actor',
            'Id': 'person_${idx}_$j',
            'Role': j == 0 ? '主演' : '配角',
          },
      ],
      'Studios': [
        {'Name': '华纳兄弟', 'Id': 'studio_wb'},
      ],
      'MediaSources': [
        {
          'Id': 'src_demo_$idx',
          'Name': 'Blu-ray 1080p',
          'Container': 'mkv',
          'Size': 8000000000,
        },
      ],
    };
  }
}
