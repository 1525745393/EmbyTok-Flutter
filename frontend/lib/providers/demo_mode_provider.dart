// 演示模式：无服务器浏览完整 UI
//
// 激活后 ApiClient 拦截器返回预设 mock 数据，所有页面可正常浏览。
// 退出演示模式后回到登录页。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 演示模式开关
final demoModeProvider = StateProvider<bool>((ref) => false);

/// 演示模式 mock 数据生成器
class DemoMockData {
  /// 根据请求路径返回 mock JSON 响应
  static dynamic handleRequest(String path,
      [Map<String, dynamic>? query]) {
    // 系统信息
    if (path.contains('/System/Info/Public')) {
      return {
        'SystemUpdateLevel': 'Release',
        'Version': '10.8.13',
        'ProductName': 'EmbyTok Demo',
        'ServerName': 'Demo Server',
      };
    }

    // 用户信息
    if (path.contains('/Users') && path.contains('/Policy')) {
      return {
        'IsAdministrator': true,
        'IsDisabled': false,
      };
    }

    // 媒体库列表
    if (path.contains('/Library/VirtualFolders')) {
      return [
        {'Name': '电影', 'CollectionType': 'movies'},
        {'Name': '剧集', 'CollectionType': 'tvshows'},
        {'Name': '动漫', 'CollectionType': 'homevideos'},
      ];
    }

    // 影片列表（推荐/最新/类型等）
    if (path.contains('/Items')) {
      final limit = query?['Limit'] ?? 30;
      final items = List.generate(
        limit is int ? limit : 20,
        (i) => {
          'Id': 'demo_$i',
          'Name': '演示影片 ${i + 1}',
          'Type': i % 5 == 0 ? 'Episode' : 'Movie',
          'ProductionYear': 2020 + (i % 5),
          'CommunityRating': 7.0 + (i % 3),
          'OfficialRating': i % 3 == 0 ? 'PG-13' : 'R',
          'RunTimeTicks': 54000000000,
          'Overview':
              '这是演示模式下的示例影片简介，用于展示界面布局和交互效果。连接真实服务器后将显示实际内容。',
          'Genres': ['动作', '科幻', i % 2 == 0 ? '冒险' : '剧情'],
          'ImageTags': {'Primary': 'demo$i', 'Thumb': 'demo$i'},
          'UserData': {
            'IsFavorite': i % 4 == 0,
            'PlaybackPositionTicks': i % 3 == 0 ? 1800000000 : 0,
            'PlayCount': i % 2,
          },
          'People': [
            {'Name': '演示导演', 'Type': 'Director'},
            {'Name': '演示演员 A', 'Type': 'Actor'},
            {'Name': '演示演员 B', 'Type': 'Actor'},
          ],
        },
      );
      return {
        'Items': items,
        'TotalRecordCount': items.length,
        'StartIndex': 0,
      };
    }

    // 收藏
    if (path.contains('/FavoriteItems')) {
      return {'Items': [], 'TotalRecordCount': 0};
    }

    return null; // 未匹配的路径返回 null，走正常请求
  }
}
