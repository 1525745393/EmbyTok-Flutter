// 测试数据初始化：一键填充/清空常见测试场景所需的本地数据
//
// 使用场景：
// - 冷启动测试前清空所有数据
// - 收藏演员测试前填充假 ID
// - 发现页筛选测试前设置筛选条件
// - 回归测试后恢复基线数据

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestDataSetupPage extends StatelessWidget {
  const TestDataSetupPage({super.key});

  // 业务数据 key 前缀（清空时保留登录态和服务器地址）
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
  ];

  Future<void> _clearBusinessData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _businessKeys) {
      await prefs.remove(key);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空业务数据（保留登录态）')),
      );
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空所有数据，重启 App 回到首次安装')),
      );
    }
  }

  Future<void> _fillFavoriteActors(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // 填充假演员 ID，用于测试关注页
    await prefs.setStringList('embytok_favorite_people_ids', [
      'actor_001',
      'actor_002',
      'actor_003',
      'actor_004',
      'actor_005',
    ]);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已填充 5 个测试收藏演员 ID')),
      );
    }
  }

  Future<void> _fillDiscoverFilters(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('discover_selected_genres',
        jsonEncode(['Action', 'Sci-Fi', 'Drama']));
    await prefs.setString('discover_selected_media_types',
        jsonEncode(['Movie', 'Series']));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已填充发现页筛选条件（3类型+2媒体类型）')),
      );
    }
  }

  Future<void> _fillPlayHistory(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString('recent_playbacks', jsonEncode([
      {
        'itemId': 'test_movie_1',
        'name': '测试影片 1',
        'progressMs': 1200000,
        'durationMs': 7200000,
        'playedAt': now - 3600000,
      },
      {
        'itemId': 'test_series_1',
        'name': '测试剧集 S01E01',
        'progressMs': 600000,
        'durationMs': 2700000,
        'playedAt': now - 7200000,
      },
    ]));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已填充 2 条测试播放历史')),
      );
    }
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
              '一键填充或清空测试场景所需的本地数据。\n'
              '操作后需重启对应页面或 App 生效。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('填充测试数据',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('填充收藏演员 ID'),
            subtitle: const Text('5 个假 ID，用于关注页测试'),
            onTap: () => _fillFavoriteActors(context),
          ),
          ListTile(
            leading: const Icon(Icons.filter_list, color: Colors.blue),
            title: const Text('填充发现页筛选条件'),
            subtitle: const Text('3 类型 + 2 媒体类型'),
            onTap: () => _fillDiscoverFilters(context),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.green),
            title: const Text('填充播放历史'),
            subtitle: const Text('2 条假记录，用于继续观看测试'),
            onTap: () => _fillPlayHistory(context),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('清空数据',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
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
}
