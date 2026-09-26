// 测试模式主导航页：列出全部测试模块入口
// 仅在 isAppTestMode == true 时可路由到达

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'subpages/api_mock_panel.dart';
import 'subpages/basic_test_page.dart';
import 'subpages/crash_simulator_page.dart';
import 'subpages/environment_switch_page.dart';
import 'subpages/http_capture_panel.dart';
import 'subpages/log_viewer_page.dart';
import 'subpages/lock_screen_control_test_page.dart';
import 'subpages/network_weak_test_page.dart';
import 'subpages/performance_debug_page.dart';
import 'subpages/player_test_page.dart';
import 'subpages/proxy_settings_page.dart';
import 'subpages/route_direct_panel.dart';
import 'subpages/sandbox_browser_page.dart';
import 'subpages/storage_viewer_page.dart';
import 'subpages/test_config_transfer_page.dart';
import 'subpages/test_mode_about_page.dart';

/// 测试模块入口定义
class _TestModuleEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _TestModuleEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

/// 测试模式主导航页
class TestModeHomePage extends StatelessWidget {
  const TestModeHomePage({super.key});

  static const List<_TestModuleEntry> _modules = [
    _TestModuleEntry(
      icon: Icons.play_circle_outline,
      color: Colors.red,
      title: '播放器专项测试',
      subtitle: '多格式播放、字幕、倍速、快速切流、前后台恢复',
      builder: _buildPlayer,
    ),
    _TestModuleEntry(
      icon: Icons.wifi_find_outlined,
      color: Colors.orange,
      title: '网络与弱网测试',
      subtitle: '超时模拟、错误码、重试逻辑验证',
      builder: _buildNetwork,
    ),
    _TestModuleEntry(
      icon: Icons.build_circle_outlined,
      color: Colors.blue,
      title: '基础功能测试',
      subtitle: '页面跳转、返回栈、权限申请、弹窗',
      builder: _buildBasic,
    ),
    _TestModuleEntry(
      icon: Icons.swap_horiz,
      color: Colors.purple,
      title: '环境切换',
      subtitle: '切换 Emby 后端地址（开发/测试/正式）',
      builder: _buildEnv,
    ),
    _TestModuleEntry(
      icon: Icons.speed,
      color: Colors.teal,
      title: '性能调试工具',
      subtitle: '内存读数、PerformanceOverlay 开关',
      builder: _buildPerf,
    ),
    _TestModuleEntry(
      icon: Icons.article_outlined,
      color: Colors.brown,
      title: '日志查看器',
      subtitle: '本地运行日志按级别筛选、复制导出',
      builder: _buildLog,
    ),
    _TestModuleEntry(
      icon: Icons.link,
      color: Colors.deepPurple,
      title: '路由直达面板',
      subtitle: '直接跳转任意路由，无需走正常导航',
      builder: _buildRoute,
    ),
    _TestModuleEntry(
      icon: Icons.bug_report,
      color: Colors.redAccent,
      title: '崩溃模拟面板',
      subtitle: '验证异常捕获逻辑与日志记录',
      builder: _buildCrash,
    ),
    _TestModuleEntry(
      icon: Icons.wifi,
      color: Colors.blue,
      title: '网络抓包面板',
      subtitle: '记录 App 所有 HTTP 请求，按路径筛选',
      builder: _buildCapture,
    ),
    _TestModuleEntry(
      icon: Icons.vpn_key,
      color: Colors.deepOrange,
      title: 'HTTP 代理设置',
      subtitle: '配置 Charles/mitmproxy 外部抓包代理',
      builder: _buildProxy,
    ),
    _TestModuleEntry(
      icon: Icons.storage,
      color: Colors.brown,
      title: '存储查看器',
      subtitle: '查看 shared_preferences 所有 key-value',
      builder: _buildStorage,
    ),
    _TestModuleEntry(
      icon: Icons.folder_outlined,
      color: Colors.indigo,
      title: '沙盒文件浏览器',
      subtitle: '遍历应用文档目录，查看缓存与日志文件',
      builder: _buildSandbox,
    ),
    _TestModuleEntry(
      icon: Icons.swap_horiz,
      color: Colors.teal,
      title: '测试配置导入导出',
      subtitle: '分享 SharedPreferences 快照复现 bug（自动脱敏）',
      builder: _buildConfigTransfer,
    ),
    _TestModuleEntry(
      icon: Icons.lock_clock,
      color: Colors.deepPurple,
      title: '锁屏/蓝牙控制专项',
      subtitle: '验证通知栏与蓝牙耳机媒体控制',
      builder: _buildLockScreen,
    ),
    _TestModuleEntry(
      icon: Icons.api,
      color: Colors.cyan,
      title: 'API Mock',
      subtitle: '按路径拦截请求返回预设 JSON，测试空状态/错误态',
      builder: _buildMock,
    ),
    _TestModuleEntry(
      icon: Icons.info_outline,
      color: Colors.grey,
      title: '关于测试模式',
      subtitle: '版本信息与使用说明',
      builder: _buildAbout,
    ),
  ];

  static Widget _buildPlayer(BuildContext _) => const PlayerTestPage();
  static Widget _buildNetwork(BuildContext _) => const NetworkWeakTestPage();
  static Widget _buildBasic(BuildContext _) => const BasicTestPage();
  static Widget _buildEnv(BuildContext _) => const EnvironmentSwitchPage();
  static Widget _buildPerf(BuildContext _) => const PerformanceDebugPage();
  static Widget _buildLog(BuildContext _) => const LogViewerPage();
  static Widget _buildRoute(BuildContext _) => const RouteDirectPanel();
  static Widget _buildCrash(BuildContext _) => const CrashSimulatorPage();
  static Widget _buildCapture(BuildContext _) => const HttpCapturePanel();
  static Widget _buildProxy(BuildContext _) => const ProxySettingsPage();
  static Widget _buildStorage(BuildContext _) => const StorageViewerPage();
  static Widget _buildSandbox(BuildContext _) => const SandboxBrowserPage();
  static Widget _buildConfigTransfer(BuildContext _) => const TestConfigTransferPage();
  static Widget _buildLockScreen(BuildContext _) => const LockScreenControlTestPage();
  static Widget _buildMock(BuildContext _) => const ApiMockPanel();
  static Widget _buildAbout(BuildContext _) => const TestModeAboutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('测试模式控制台'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '仅在 debug 构建内可用，release 不包含此入口',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          for (final m in _modules)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: Icon(m.icon, color: m.color),
                title: Text(m.title),
                subtitle: Text(m.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: m.builder),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
