// 关于测试模式：版本信息与使用说明

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class TestModeAboutPage extends StatelessWidget {
  const TestModeAboutPage({super.key});

  static const String _dartDefine =
      String.fromEnvironment('TEST_MODE', defaultValue: 'false');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于测试模式')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.build_circle, size: 40, color: Colors.blue),
            title: Text('测试模式控制台'),
            subtitle: Text('版本 1.0.0'),
          ),
          const Divider(),
          ListTile(
            title: const Text('构建信息'),
            subtitle: Text(
              '模式: ${kDebugMode ? 'debug' : 'release/profile'}\n'
              'Dart define TEST_MODE: $_dartDefine\n'
              '平台: Android/iOS',
            ),
          ),
          const ListTile(
            title: Text('使用说明'),
            subtitle: Text(
              '1. 本控制台仅在 debug 构建或 --dart-define=TEST_MODE=true 时可用\n'
              '2. release 构建不包含任何测试入口与路由\n'
              '3. 测试数据（日志、环境覆盖）不影响正式用户配置\n'
              '4. 退出测试模式：返回设置页即可，环境切换在重启后自动恢复',
            ),
          ),
          const ListTile(
            title: Text('注意事项'),
            subtitle: Text(
              '· 环境切换仅临时覆盖 baseUrl，不写入服务器列表\n'
              '· 日志查看器读取的是 AppLogger 持久化日志（500 条环形缓冲）\n'
              '· 播放器测试使用公共样例源（Google Storage），需联网',
            ),
          ),
        ],
      ),
    );
  }
}
