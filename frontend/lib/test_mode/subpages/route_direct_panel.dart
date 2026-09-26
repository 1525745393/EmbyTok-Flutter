// 路由直达面板：手动维护路由列表，点击直接 context.go() 跳转
// 深层页面测试无需走正常登录和导航流程

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteDirectPanel extends StatelessWidget {
  const RouteDirectPanel({super.key});

  static const _routes = [
    ['首页', '/'],
    ['搜索', '/search'],
    ['收藏', '/favorites'],
    ['历史', '/history'],
    ['演员', '/actors'],
    ['推荐', '/recommend'],
    ['关注', '/follow'],
    ['发现', '/discover'],
    ['下载', '/downloads'],
    ['播放统计', '/play-stats'],
    ['数据备份', '/data-backup'],
    ['歌单', '/playlists'],
    ['设置', '/settings'],
    ['个人资料', '/profile'],
    ['登录', '/login'],
    ['测试模式', '/test-mode'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('路由直达')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '点击直接跳转路由，绕过正常导航流程。\n'
              '需登录的路由未登录时会被重定向到登录页。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          for (final r in _routes)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(r[0]),
              subtitle: Text(r[1]),
              onTap: () => context.go(r[1]),
            ),
        ],
      ),
    );
  }
}
