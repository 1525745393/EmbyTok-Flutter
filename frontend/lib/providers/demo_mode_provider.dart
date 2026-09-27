// 演示模式：无服务器浏览完整 UI
//
// 激活后 ApiClient 拦截器返回预设 mock 数据，所有页面可正常浏览。
// 退出演示模式后回到登录页。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 演示模式开关
final demoModeProvider = StateProvider<bool>((ref) => false);

/// 演示模式 mock 数据生成器
///
/// 覆盖 Emby 主要 API：系统信息、用户视图、推荐/续看/最新、类型/演员/标签、
/// 收藏操作、搜索、相似推荐等。未匹配的路径返回 null，走真实请求
/// （在演示模式下会失败，由各页面错误态兜底显示）。
class DemoMockData {
  static const _genres = ['动作', '科幻', '剧情', '喜剧', '悬疑', '爱情', '动画', '纪录片'];
  static const _actors = ['演示演员甲', '演示演员乙', '演示演员丙', '演示演员丁', '演示演员戊'];
  static const _studios = ['演示影业', '演示影视', '演示工作室'];

  /// 根据请求路径返回 mock JSON 响应
  static dynamic handleRequest(String path,
      [Map<String, dynamic>? query]) {
    // ---- 系统与用户 ----
    if (path.contains('/System/Info/Public')) {
      return {
        'SystemUpdateLevel': 'Release',
        'Version': '10.8.13',
        'ProductName': 'EmbyTok Demo',
        'ServerName': '演示服务器',
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
          {'Name': '动漫', 'CollectionType': 'homevideos', 'Id': 'lib_anime'},
        ],
        'TotalRecordCount': 3,
      };
    }

    // ---- 媒体库 ----
    if (path.contains('/Library/VirtualFolders')) {
      return [
        {'Name': '电影', 'CollectionType': 'movies'},
        {'Name': '剧集', 'CollectionType': 'tvshows'},
        {'Name': '动漫', 'CollectionType': 'homevideos'},
      ];
    }

    // ---- 收藏 GET 列表 ----
    if (path.endsWith('/FavoriteItems') ||
        (path.contains('/FavoriteItems') && !RegExp(r'/FavoriteItems/\w+').hasMatch(path))) {
      return {'Items': <dynamic>[], 'TotalRecordCount': 0};
    }

    // ---- 收藏 POST/DELETE（返回成功）----
    if (path.contains('/FavoriteItems/') &&
        RegExp(r'/FavoriteItems/\w+').hasMatch(path)) {
      return {'Success': true};
    }

    // ---- 续看 / 最新（必须在单 item 正则之前匹配）----
    if (path.contains('/Items/Resume') || path.endsWith('/Resume')) {
      return _itemList(8, withPosition: true);
    }
    if (path.contains('/Items/Latest') || path.endsWith('/Latest')) {
      return _itemList(12, offset: 20);
    }
    if (path.contains('/Items/Counts')) {
      return {'Movie': 120, 'Series': 45, 'Episode': 800};
    }
    if (path.contains('/Shows/NextUp')) {
      return _itemList(6, type: 'Episode');
    }
    if (path.contains('/Shows/Recommended') ||
        path.contains('/Movies/Recommendations') ||
        path.contains('/Suggestions')) {
      return _itemList(10, offset: 5);
    }

    // ---- 相似推荐 ----
    if (path.contains('/Similar')) {
      return _itemList(10, offset: 10);
    }

    // ---- 类型 / 演员 / 工作室 / 标签 ----
    if (path.endsWith('/Genres')) {
      return {'Items': [for (var g in _genres) {'Name': g, 'MovieCount': 5}], 'TotalRecordCount': _genres.length};
    }
    if (path.endsWith('/Persons')) {
      return {'Items': [for (var i = 0; i < _actors.length; i++) {'Name': _actors[i], 'Type': 'Actor', 'Id': 'person_$i'}], 'TotalRecordCount': _actors.length};
    }
    if (path.contains('/Studios')) {
      return {'Items': [for (var s in _studios) {'Name': s}], 'TotalRecordCount': _studios.length};
    }
    if (path.contains('/Tags')) {
      return {'Items': [for (var t in ['4K', 'HDR', '杜比', '导演剪辑版', '经典']) {'Name': t}], 'TotalRecordCount': 5};
    }

    // ---- 搜索 ----
    if (path.contains('/Search/Hints')) {
      return _itemList(5);
    }

    // ---- 单 item 详情（排除保留字后最后匹配）----
    final singleItemMatch = RegExp(r'/Items/([^/?]+)').firstMatch(path);
    if (singleItemMatch != null) {
      final id = singleItemMatch.group(1)!;
      // 排除非 item 的保留路径段
      const reserved = {'Latest', 'Resume', 'Counts', 'Similar', 'Children'};
      if (!reserved.contains(id)) {
        final index = int.tryParse(id.replaceAll('demo_', '')) ?? 0;
        return _demoItem(index);
      }
    }

    // ---- 通用影片列表（兜底）----
    if (path.contains('/Items')) {
      final limit = query?['Limit'] ?? 30;
      final count = limit is int ? limit : 20;
      return _itemList(count);
    }

    return null;
  }

  // ---- 辅助方法 ----

  static Map<String, dynamic> _itemList(int count,
      {int offset = 0, String type = 'Movie', bool withPosition = false}) {
    final items = List.generate(count, (i) {
      final idx = offset + i;
      return _demoItem(idx, type: type, withPosition: withPosition);
    });
    return {'Items': items, 'TotalRecordCount': items.length, 'StartIndex': 0};
  }

  static Map<String, dynamic> _demoItem(int i,
      {String type = 'Movie', bool withPosition = false}) {
    final year = 2020 + (i % 5);
    return {
      'Id': 'demo_$i',
      'Name': type == 'Episode' ? '演示剧集 ${i + 1}' : '演示影片 ${i + 1}',
      'Type': type,
      'ProductionYear': year,
      'CommunityRating': 7.0 + (i % 3) + 0.5,
      'OfficialRating': i % 3 == 0 ? 'PG-13' : 'R',
      'RunTimeTicks': type == 'Episode' ? 2700000000 : 54000000000,
      'Overview': '这是演示模式下的示例内容简介，用于展示界面布局和交互效果。'
          '连接真实服务器后将显示实际影片信息。',
      'Genres': [_genres[i % _genres.length], _genres[(i + 1) % _genres.length]],
      'ImageTags': {'Primary': 'demo$i', 'Thumb': 'demo$i'},
      'UserData': {
        'IsFavorite': i % 4 == 0,
        'PlaybackPositionTicks': withPosition ? 1800000000 : (i % 3 == 0 ? 900000000 : 0),
        'PlayCount': i % 2,
      },
      'People': [
        {'Name': '演示导演', 'Type': 'Director', 'Id': 'person_dir'},
        {'Name': _actors[i % _actors.length], 'Type': 'Actor', 'Id': 'person_$i'},
        {'Name': _actors[(i + 1) % _actors.length], 'Type': 'Actor'},
      ],
      'Studios': [
        {'Name': _studios[i % _studios.length], 'Id': 'studio_$i'},
      ],
      'BackdropImageTags': ['demo${i}_backdrop'],
    };
  }
}
