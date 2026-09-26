// 测试数据初始化：一键填充/清空常见测试场景所需的本地数据
//
// 覆盖场景：
// - 收藏演员（不同数量）
// - 播放历史（不同进度）
// - 发现页筛选（类型/标签/合集/媒体类型）
// - 收藏影片/合集缓存
// - Last.fm 配置
// - 页面导航位置
// - 排除已观看开关

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestDataSetupPage extends StatelessWidget {
  const TestDataSetupPage({super.key});

  static const _businessKeys = [
    'embytok_favorite_people_ids',
    'favorite_artists',
    'discover_selected_genres',
    'discover_selected_tags',
    'discover_selected_collections',
    'discover_selected_media_types',
    'recent_playbacks',
    'play_events',
    'lastfm_api_key',
    'kStorageKeyLastPageIndex',
  ];

  Future<void> _toast(BuildContext context, String msg) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // === 填充：收藏演员 ===
  Future<void> _fillFavoriteActors(BuildContext context, int count) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = List.generate(count, (i) => 'actor_${i + 1}'.padLeft(9, '0'));
    await prefs.setStringList('embytok_favorite_people_ids', ids);
    await _toast(context, '已填充 $count 个收藏演员 ID');
  }

  // === 填充：播放历史（不同进度） ===
  Future<void> _fillPlayHistory(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final history = [
      {
        'itemId': 'test_movie_1',
        'name': '测试影片-刚看(5%)',
        'progressMs': 360000,
        'durationMs': 7200000,
        'playedAt': now - 1800000,
      },
      {
        'itemId': 'test_movie_2',
        'name': '测试影片-看一半(50%)',
        'progressMs': 3600000,
        'durationMs': 7200000,
        'playedAt': now - 3600000,
      },
      {
        'itemId': 'test_series_1',
        'name': '测试剧集S01E01-快看完(80%)',
        'progressMs': 2160000,
        'durationMs': 2700000,
        'playedAt': now - 7200000,
      },
      {
        'itemId': 'test_movie_3',
        'name': '测试影片-已看完(100%)',
        'progressMs': 7200000,
        'durationMs': 7200000,
        'playedAt': now - 86400000,
      },
    ];
    await prefs.setString('recent_playbacks', jsonEncode(history));
    await _toast(context, '已填充 4 条播放历史（5%/50%/80%/100%）');
  }

  // === 填充：发现页筛选 ===
  Future<void> _fillDiscoverFilters(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('discover_selected_genres',
        jsonEncode(['Action', 'Sci-Fi', 'Drama', 'Comedy']));
    await prefs.setString(
        'discover_selected_tags', jsonEncode(['4K', 'HDR', 'Dolby']));
    await prefs.setString(
        'discover_selected_collections', jsonEncode(['collection_1', 'collection_2']));
    await prefs.setString(
        'discover_selected_media_types', jsonEncode(['Movie', 'Series']));
    await _toast(context, '已填充发现页筛选：4类型+3标签+2合集+2媒体类型');
  }

  // === 填充：收藏影片缓存 ===
  Future<void> _fillFavoritesCache(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorites_movies_cache', jsonEncode([
      {'Id': 'fav_movie_1', 'Name': '收藏影片 A', 'ProductionYear': 2024},
      {'Id': 'fav_movie_2', 'Name': '收藏影片 B', 'ProductionYear': 2023},
      {'Id': 'fav_movie_3', 'Name': '收藏影片 C', 'ProductionYear': 2022},
    ]));
    await prefs.setString('favorites_boxsets_cache', jsonEncode([
      {'Id': 'fav_box_1', 'Name': '收藏合集-漫威宇宙', 'ChildCount': 12},
      {'Id': 'fav_box_2', 'Name': '收藏合集-诺兰合集', 'ChildCount': 5},
    ]));
    await prefs.setString('favorites_people_cache', jsonEncode([
      {'Id': 'fav_person_1', 'Name': '测试演员 A', 'Type': 'Person'},
      {'Id': 'fav_person_2', 'Name': '测试演员 B', 'Type': 'Person'},
    ]));
    await _toast(context, '已填充收藏缓存：3影片+2合集+2人物');
  }

  // === 填充：Last.fm 配置 ===
  Future<void> _fillLastFmConfig(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastfm_api_key', 'test_api_key_12345');
    await _toast(context, '已填充 Last.fm 测试 API Key');
  }

  // === 填充：页面导航位置 ===
  Future<void> _fillNavPosition(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('kStorageKeyLastPageIndex', 2); // 收藏页
    await _toast(context, '已设置下次启动打开收藏页');
  }

  // === 填充：排除已观看开关 ===
  Future<void> _toggleExcludeWatched(BuildContext context, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('discover_exclude_watched', value);
    await _toast(context, '排除已观看开关：${value ? "开" : "关"}');
  }

  // === 清空 ===
  Future<void> _clearBusinessData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _businessKeys) {
      await prefs.remove(key);
    }
    await _toast(context, '已清空业务数据（保留登录态）');
  }

  Future<void> _clearAll(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _toast(context, '已清空所有数据，重启 App 回到首次安装');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('测试数据初始化')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '一键填充或清空测试场景所需的本地数据。\n操作后需重启对应页面或 App 生效。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),

          // 收藏相关
          _sectionTitle('收藏数据'),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('填充收藏演员（5个）'),
            subtitle: const Text('用于关注页/追剧测试'),
            onTap: () => _fillFavoriteActors(context, 5),
          ),
          ListTile(
            leading: const Icon(Icons.star_border, color: Colors.amber),
            title: const Text('填充收藏演员（20个）'),
            subtitle: const Text('长列表滚动测试'),
            onTap: () => _fillFavoriteActors(context, 20),
          ),
          ListTile(
            leading: const Icon(Icons.collections_bookmark, color: Colors.pink),
            title: const Text('填充收藏影片/合集/人物缓存'),
            subtitle: const Text('3影片+2合集+2人物，用于收藏页测试'),
            onTap: () => _fillFavoritesCache(context),
          ),

          // 播放历史
          _sectionTitle('播放历史'),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.green),
            title: const Text('填充播放历史（4种进度）'),
            subtitle: const Text('5%/50%/80%/100%，测试继续观看'),
            onTap: () => _fillPlayHistory(context),
          ),

          // 发现页
          _sectionTitle('发现页筛选'),
          ListTile(
            leading: const Icon(Icons.filter_list, color: Colors.blue),
            title: const Text('填充完整筛选条件'),
            subtitle: const Text('4类型+3标签+2合集+2媒体类型'),
            onTap: () => _fillDiscoverFilters(context),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off, color: Colors.grey),
            title: const Text('打开"排除已观看"开关'),
            onTap: () => _toggleExcludeWatched(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.visibility, color: Colors.grey),
            title: const Text('关闭"排除已观看"开关'),
            onTap: () => _toggleExcludeWatched(context, false),
          ),

          // 配置
          _sectionTitle('其他配置'),
          ListTile(
            leading: const Icon(Icons.music_note, color: Colors.purple),
            title: const Text('填充 Last.fm API Key'),
            subtitle: const Text('测试歌手简介功能'),
            onTap: () => _fillLastFmConfig(context),
          ),
          ListTile(
            leading: const Icon(Icons.tab, color: Colors.teal),
            title: const Text('设置启动页为收藏页'),
            subtitle: const Text('验证导航位置记忆'),
            onTap: () => _fillNavPosition(context),
          ),

          const Divider(),
          _sectionTitle('清空数据', color: Colors.red),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.orange),
            title: const Text('清空业务数据'),
            subtitle: const Text('保留登录态，清收藏/历史/筛选等'),
            onTap: () => _clearBusinessData(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('清空所有数据'),
            subtitle: const Text('含登录态，重启后回到首次安装'),
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('确认清空所有数据？'),
                content: const Text('包括登录态、服务器地址、所有缓存。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearAll(context);
                    },
                    child: const Text('确认清空'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    );
  }
}
