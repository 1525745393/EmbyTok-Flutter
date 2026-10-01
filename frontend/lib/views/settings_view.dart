// 设置页面：主题、播放、字幕、存储、账户、关于等
// 优化：组件提取、配置化、UI 优化、新增功能

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show LicenseRegistry, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/local_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/artist_metadata_provider.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/player_engine_provider.dart';
import '../providers/server_registry_provider.dart';
import '../widgets/video/playback_info_osd.dart';
import 'settings/cache_management_page.dart';
import 'settings/feedback_page.dart';
import 'settings/network_diagnostic_page.dart';
import 'settings/year_report_page.dart';
import '../providers/service_mode_provider.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../services/artist_metadata_service.dart' show BatchScanResult;
import '../utils/app_preferences.dart'
    show AppPreferencesService, OrientationMode, FeedType;
import '../utils/constants.dart';
import '../utils/donate_colors.dart';
import '../utils/formatters.dart' show formatBytes;
import '../utils/logger.dart';
import '../utils/performance_monitor.dart';
import '../test_mode/test_mode_switch.dart';
import '../widgets/library_selector.dart';
import 'music/artist_batch_scan_dialog.dart';
import 'settings/settings_components.dart';
import 'settings/settings_section_page.dart';

part 'settings/settings_recommend_rules.dart';
part 'settings/settings_recommend_rules_ext.dart';
part 'settings/settings_builders.dart';
part 'settings/settings_builders_extra.dart';
part 'settings/settings_dialogs.dart';
part 'settings/settings_dialogs_ext.dart';
part 'settings/settings_dialogs_update.dart';
part 'settings/settings_dialogs_update_extra.dart';

// 设置页面常量定义（分离到单独文件）
part 'settings/settings_constants.dart';

// 设置页面辅助组件（分离到单独文件）
part 'settings/settings_widgets.dart';
part 'settings/settings_search_sheet.dart';
part 'settings/settings_recommend_advanced.dart';
part 'settings/settings_about.dart';

// ==================== 主页面 ====================

// 版本号连点计数（测试模式入口，仅 debug 生效）
int _versionTapCount = 0;
Timer? _versionTapResetTimer;

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 音乐服务模式下隐藏视频相关分组（视频库/推荐/播放/字幕/统计/视频方向等）
    final isMusicMode = ref.watch(serviceModeProvider) == AppServiceMode.music;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          children: [
            Icon(Icons.settings, color: scheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('设置'),
          ],
        ),
        // 搜索入口：快速定位 25+ 设置项
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索设置',
            onPressed: () => _showSettingsSearch(context, ref),
          ),
        ],
      ),
      body: ListView(
        // 底部避让刘海屏黑条区域
        padding: EdgeInsets.fromLTRB(
            0, 8, 0, 8 + MediaQuery.paddingOf(context).bottom),
        children: [
          // 本地媒体库模式入口（P2）：文件源管理 + 退出本地模式
          if (ref.watch(localModeProvider)) ...[
            _buildSectionEntry(
              context,
              ref,
              '本地媒体库',
              Icons.smartphone_outlined,
              Colors.purple,
              '文件源管理、退出本地模式',
              (context, ref) => [
                ListTile(
                  leading: const Icon(Icons.folder_special_outlined, color: Colors.purple),
                  title: const Text('文件源管理'),
                  subtitle: const Text('手机本地 / SMB / WebDAV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/file-sources'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('退出本地模式'),
                  subtitle: const Text('返回登录页，连接 Emby 服务器'),
                  onTap: () => _exitLocalMode(context, ref),
                ),
              ],
            ),
          ],
          // 视频库设置（PR #66：视频流 / 推荐可分别设置；音乐模式隐藏）
          if (!isMusicMode)
            _buildSectionEntry(
              context,
              ref,
              '视频库',
              Icons.video_library_outlined,
              Colors.deepPurple,
              '选择媒体库、排除已观看',
              (context, ref) => [
                _buildFeedLibraryTile(context, ref),
                _buildFeedExcludePlayedTile(context, ref),
              ],
            ),
          // 规则筛选（二级页面：推荐/关注/发现 三个 Tab）
          if (!isMusicMode)
            _buildSectionEntry(
              context,
              ref,
              '规则筛选',
              Icons.rule_outlined,
              Colors.pink,
              '推荐/关注/发现页的数据源、类型、评分等规则',
              (context, ref) => [
                ListTile(
                  leading: const Icon(Icons.tune_outlined, color: Colors.pink),
                  title: const Text('规则配置'),
                  subtitle: const Text('推荐页 / 关注页 / 发现页的筛选规则'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openRulesPage(context),
                ),
              ],
            ),
          // 播放设置（音乐模式隐藏：均为视频播放器设置）
          if (!isMusicMode)
            _buildSectionEntry(
              context,
              ref,
              '播放',
              Icons.play_circle_outline,
              Colors.green,
              '自动播放、倍速、手势控制',
              (context, ref) => [
                _buildAutoPlayTile(context, ref),
                _buildAutoResumeAfterInterruptionTile(context, ref),
                _buildFullscreenGestureBackTile(context, ref),
                _buildPlaybackRateTile(context, ref),
                _buildGestureControlTile(context, ref),
              ],
            ),
          // 播放器引擎设置（音乐模式隐藏）
          if (!isMusicMode)
            _buildSectionEntry(
              context,
              ref,
              '播放器',
              Icons.movie_outlined,
              Colors.orange,
              '引擎选择、硬解、画面缩放、弹幕',
              (context, ref) => [
                _buildPlayerEngineTile(context, ref),
                _buildThirdPartyFallbackTile(context, ref),
                _buildMpvHwDecTile(context, ref),
                _buildMpvCacheTile(context, ref),
                _buildMpvAssStyleTile(context, ref),
                _buildPlaybackInfoOsdTile(context, ref),
                _buildAudioOffsetTile(context, ref),
                _buildVideoFitTile(context, ref),
                _buildAutoPlayNextTile(context, ref),
                _buildDanmakuTile(context, ref),
              ],
            ),
          // 字幕设置（音乐模式隐藏）
          if (!isMusicMode)
            _buildSectionEntry(
              context,
              ref,
              '字幕',
              Icons.closed_caption_outlined,
              Colors.teal,
              '语言、字号、颜色、位置、时间偏移',
              (context, ref) => [
                _buildSubtitleLanguageTile(context, ref),
                _buildSubtitleSizeTile(context, ref),
                _buildSubtitleColorTile(context, ref),
                _buildSubtitlePositionTile(context, ref),
                _buildSubtitleShadowTile(context, ref),
                _buildSubtitleTimeOffsetTile(context, ref),
              ],
            ),
          // 外观设置
          _buildSectionEntry(
            context,
            ref,
            '外观',
            Icons.palette_outlined,
            Colors.indigo,
            '主题、语言、屏幕方向',
            (context, ref) => [
              _buildThemeTile(context, ref),
              _buildLanguageTile(context, ref),
              if (!isMusicMode) _buildOrientationTile(context, ref),
            ],
          ),
          // 服务器与账户设置（配置服务器是进入 App 的前提，放在靠前位置）
          _buildSectionEntry(
            context,
            ref,
            '服务器与账户',
            Icons.cloud_outlined,
            Colors.blue,
            'Emby 服务器、服务模式、账户证书',
            (context, ref) => [
              _buildServiceModeSelector(context, ref),
              _buildServerRegistryTile(context, ref),
              if (!isMusicMode) ...[
                _buildServerGroupLabel(
                    context, ref, '视频数据源', Icons.movie_outlined),
                _buildServerInfoTile(context, ref),
              ],
              _buildServerGroupLabel(
                  context, ref, '账户', Icons.account_circle_outlined),
              _buildProfileTile(context, ref),
              _buildSelfSignedCertificateTile(context, ref),
            ],
          ),
          // 存储与缓存设置
          _buildSectionEntry(
            context,
            ref,
            '存储与缓存',
            Icons.storage_outlined,
            Colors.grey,
            '缓存管理、日志、重置设置',
            (context, ref) => [
              _buildCacheTile(context, ref),
              _buildCacheManagementTile(context, ref),
              _buildSmartCacheTile(context, ref),
              _buildResetSettingsTile(context, ref),
              _buildExportLogsTile(context, ref),
              _buildClearLogsTile(context, ref),
            ],
          ),
          // 音乐库设置
          _buildSectionEntry(
            context,
            ref,
            '音乐库',
            Icons.library_music_outlined,
            const Color(0xFF2C8EF4),
            '群晖 Audio Station、歌手元数据',
            (context, ref) => [
              _buildServerGroupLabel(
                  context, ref, '音乐数据源', Icons.library_music_outlined),
              _buildSynologyMusicTile(context, ref),
              _buildLastFmTile(context, ref),
              _buildNasMetadataSyncTile(context, ref),
              _buildServerGroupLabel(
                  context, ref, '歌手元数据', Icons.person_outline),
              _buildArtistMetadataCacheTile(context, ref),
              _buildBatchScanTile(context, ref),
            ],
          ),
          // 通用工具
          _buildSectionEntry(
            context,
            ref,
            '通用工具',
            Icons.tune,
            Colors.teal,
            '观看统计、年度报告、网络诊断、反馈',
            (context, ref) => [
              if (!isMusicMode) _buildWatchStatsTile(context, ref),
              _buildYearReportTile(context, ref),
              _buildNetworkDiagnosticTile(context, ref),
              _buildFeedbackTile(context, ref),
              if (ref.watch(demoModeProvider)) _buildExitDemoTile(context, ref),
            ],
          ),
          // 家长控制
          _buildSectionEntry(
            context,
            ref,
            '家长控制',
            Icons.family_restroom,
            Colors.green,
            '儿童模式、评分限制、PIN 锁',
            (context, ref) => [
              SwitchListTile(
                title: const Text('儿童模式'),
                subtitle: const Text('启用后仅显示适合儿童的内容'),
                value: ref.watch(parentalControlProvider).kidsModeEnabled,
                onChanged: (v) =>
                    ref.read(parentalControlProvider.notifier).setKidsMode(v),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('最高允许评分'),
                subtitle: Text(
                    ref.watch(parentalControlProvider).maxRating ?? '不限制'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRatingPicker(context, ref),
              ),
              SwitchListTile(
                title: const Text('隐藏受限内容'),
                subtitle: const Text('隐藏超过评分限制的影片'),
                value:
                    ref.watch(parentalControlProvider).hideRestrictedContent,
                onChanged: (v) => ref
                    .read(parentalControlProvider.notifier)
                    .setHideRestricted(v),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('每日观影限时'),
                subtitle: const Text('限制儿童每日使用时长（预留）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('观影限时功能即将推出')),
                  );
                },
              ),
              // PIN 锁
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('应用 PIN 锁'),
                subtitle: Text(
                    ref.watch(pinLockProvider).isEmpty ? '未设置' : '已启用'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPinLockDialog(context, ref),
              ),
            ],
          ),
          // 关于
          _buildSectionEntry(
            context,
            ref,
            '关于',
            Icons.info_outline,
            Colors.blueGrey,
            '版本、检查更新、打赏支持',
            (context, ref) => [
              _buildAboutTile(context, ref),
              _buildCheckUpdateTile(context, ref),
              _buildDonateTile(context, ref),
              _buildVersionTile(context, ref),
            ],
          ),
          // 开发者选项（仅开发模式显示）
          if (kDebugMode)
            _buildSectionEntry(
              context,
              ref,
              '开发者选项',
              Icons.developer_mode,
              Colors.purple,
              '性能监控等调试工具',
              (context, ref) => [
                _buildPerformanceMonitorTile(context, ref),
              ],
            ),
          const SizedBox(height: _kSpacingXXLarge),
          _buildLogoutButton(context, ref),
          const SizedBox(height: _kSpacingXXXXLarge),
        ],
      ),
    );
  }

  /// 退出本地媒体库模式（P2）：重置状态并返回登录页
  void _exitLocalMode(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出本地模式'),
        content: const Text('确定退出本地媒体库模式并返回登录页？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(localModeProvider.notifier).state = false;
              // 重置认证状态
              ref.read(authProvider.notifier).state = const AuthState();
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 打开规则筛选二级页面（推荐/关注/发现 三个 Tab）
  void _openRulesPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('规则筛选'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.recommend_outlined), text: '推荐页'),
                  Tab(icon: Icon(Icons.person_pin_outlined), text: '关注页'),
                  Tab(icon: Icon(Icons.explore_outlined), text: '发现页'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 推荐页
                Consumer(
                  builder: (context, ref, _) => ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildRuleScopeHint(context, ref),
                      _buildRecommendLibraryTile(context, ref),
                      _buildRecommendMinRatingTile(context, ref),
                      _buildRecommendExcludePlayedTile(context, ref),
                      _buildRecommendMinRuntimeTile(context, ref),
                      _buildRecommendIncludeTypesTile(context, ref),
                      _RecommendAdvancedTile(
                        advancedTilesBuilder: () => [
                          _buildRecommendUseWatchHistoryTile(context, ref),
                          _buildRecommendHalfLifeDaysTile(context, ref),
                          _buildRecommendAntiFatigueEnabledTile(context, ref),
                          _buildRecommendAntiFatigueDaysTile(context, ref),
                          _buildRecommendUserRatingEnabledTile(context, ref),
                          _buildRecommendUserRatingMinTile(context, ref),
                        ],
                      ),
                      const _RecommendTagMappingTile(),
                    ],
                  ),
                ),
                // 关注页
                Consumer(
                  builder: (context, ref, _) => ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildRecommendNextUpSeriesCountTile(context, ref),
                      _buildFollowActorVideoCountTile(context, ref),
                      _buildFollowOnlyUnwatchedTile(context, ref),
                      _buildFollowMaxActorsTile(context, ref),
                      _buildSharedRuleHint(context, ref),
                    ],
                  ),
                ),
                // 发现页
                Consumer(
                  builder: (context, ref, _) => ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildDiscoverGenresTile(context, ref),
                      _buildDiscoverTagsTile(context, ref),
                      _buildDiscoverCollectionsTile(context, ref),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 分组构建 ====================

  // ==================== 设置项构建 ====================

  // 媒体库 - 视频流使用（PR #66）：chips 可视化预览已选数据源
  // 媒体库 - 视频流排除已观看
  // 媒体库 - 推荐使用（PR #66）：chips 可视化预览已选数据源
  // 媒体库 - 发现标签（首页顶栏「发现」数据源，PRD）
  /// 发现·标签设置项：多选 Emby 标签（Tags），首页「发现」合并展示标签下影片
  /// 发现·合集设置项：多选 Emby 合集（BoxSet），首页「发现」合并展示合集内影片
  // 发现来源多选对话框：拉取服务器条目列表（类型/合集），勾选保存
// PR #78：推荐 - 评分阈值
  // PR #78：推荐 - 排除已观看
  // PR #78：推荐 - 最短时长
  // 推荐评分阈值对话框
  // 推荐最短时长对话框
  // PR #79：推荐 - 类型偏好
  // 5 个可切换的类型（多选）
  static const Map<String, String> _kRecommendTypeLabels = {
    'Movie': '电影',
    'Episode': '剧集',
    'Video': '视频',
    'MusicVideo': '音乐视频',
    'Series': '电视剧',
  };

  // PR #85：完播率门控开关
  // - 关闭：推荐结果完全由 Emby 服务器决定（不应用黑名单/权重/种子）
  // - 开启：根据你的完播率历史优化推荐（默认）
  // PR #85：时间衰减半衰期（天）
  // - 0 天 = 不衰减（所有完播记录等权重）
  // - 14 天 = 默认（14 天前的记录权重衰减到 0.5）
  // - 范围 0-90 天
  // PR #88：反推荐疲劳开关
  // - 关闭：所有展示过的 item 也会被重推
  // - 开启：X 天内展示过的 item 不再推荐
  // PR #88：反推荐疲劳天数（默认 30，范围 1-90）
  // 关注：取最近几部剧的下一集（默认 5，范围 1-10）
  // 关注：收藏演员新作品条数（默认 20，范围 5-40）
  // 关注页：每演员视频数（默认 3，范围 1-10）
  // 关注页：只看未观看（默认开）
  // 通用数量滑块对话框
  // PR #89：用户评分加权开关
  // - 关闭：仅按 communityRating 过滤（已有逻辑）
  // - 开启：用户评分 < 阈值的 item 也跳过（除非收藏）
  // PR #89：用户评分最低阈值（0-10，默认 4.0）
  // 播放 - 自动播放
  // 播放 - 焦点恢复自动续播（来电结束后是否自动恢复播放）
  // 播放 - 全屏排除边缘返回手势（Android 手势导航）
  // 播放 - 默认倍速
  // 播放 - 手势控制
  // 字幕 - 默认语言
  // 字幕 - 字幕大小
  // 外观 - 主题
  // 外观 - 方向过滤
  // 存储 - 清除缓存
  // 存储 - 歌手元数据缓存管理（V1.1）
  // 查看歌手简介/头像缓存大小，支持单独清除
  // 存储 - 批量补全歌手元数据（V1.2）
  // 扫描音乐库中所有歌手，批量获取缺失的头像和简介
  // 开始批量扫描
  // 显示清除歌手元数据缓存对话框
  // 存储 - 重置所有偏好设置到默认值
  // 仅清除"设置类"偏好，不影响登录信息、观看历史、收藏等用户数据
  // 存储 - 导出错误日志（P2 新增）
  // 将内存中的 WARN/ERROR 日志导出到文件，并复制路径到剪贴板
  // 使用 Clipboard 替代 share_plus，避免引入额外依赖
  // 存储 - 清除已持久化的日志文件（P2 新增）
  // 清除内存缓冲区和磁盘上的日志文件
  // PR #81：观看统计 tile
  // - 显示总次数 + 平均完播率
  // - 点击查看详情 + 清除按钮
  // 服务器 - 服务器管理入口（多服务器控制台）
  // 服务器 - 服务模式选择（视频服务 / 音乐服务）
  // 服务器 - 数据源分组标签（视频 / 音乐）
  /// 规则筛选子分区折叠卡片：推荐/关注/发现 各页面设置分区
  /// 规则筛选分组顶部引导：说明分组结构与生效时机
  /// 规则筛选 - 关注页共享规则说明
  /// 评分/时长/类型等规则与推荐页共用同一开关（关注内容同样经过过滤），
  /// 避免用户误以为需要到推荐页单独配置。
  // 服务器 - 服务器信息
  // 服务器 - 群晖 Audio Station 音乐
  // 服务器 - Last.fm 音乐元数据补充（歌手头像/简介）
  /// NAS 歌手元数据同步开关（V1.1）
  ///
  /// 开启后，歌手元数据会同步到群晖 NAS（/appdata/EmbTok/artist_metadata/），
  /// 支持多设备共享。需要先登录群晖 Audio Station。
  /// Last.fm API Key 配置弹窗（免费申请：last.fm/api/account/create）
  // 关于 - 应用信息
  // 关于 - 检查更新
  // 关于 - 打赏支持
  // 关于 - 意见反馈
  // 关于 - 版本信息（动态读取，避免硬编码）
  // P2-5：性能监控面板（仅开发模式）
  // 开启后显示悬浮面板，监控内存使用、帧率、Widget 重建次数、API 请求统计
  // 账户 - 用户信息
  // P0-1：允许自签名证书（默认关闭，即启用 SSL 证书校验）
  // 开启时允许连接使用自签名证书的内网 NAS，存在中间人攻击风险
  /// 从 SharedPreferences 读取是否允许自签名证书
  Future<bool> _loadAllowSelfSignedCertificate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kStorageKeyAllowSelfSignedCertificate) ?? false;
  }

  /// 保存是否允许自签名证书到 SharedPreferences
  ///
  /// 注意：证书校验配置在 ApiClient 初始化时读取，
  /// 修改后需要重启 App 才能生效。
  /// 显示自签名证书安全风险提示对话框
  // 退出登录按钮
  // ==================== 设置搜索 ====================

  // 构建设置项搜索索引：每个入口包含标题、分组、关键词、点击回调
  // 点击回调捕获当前 context 和 ref，确保搜索结果可直接执行操作
  // 显示设置搜索对话框
  // ==================== 组件定义 ====================

  // 点击型设置项
  /// 数据源选择 tile：已选媒体库以 chips 可视化预览（全量展示，自动换行）
  ///
  /// 相比单一文本副标题，用户无需进入弹窗即可看清当前生效的媒体库集合；
  /// 收藏夹模式（视频流）以高亮 chip 标识。点击进入 [LibrarySelector] 弹窗。
  /// 媒体库类型图标（Emby Library.type）
  /// 可点击 chip 包装：提供点击反馈（用于媒体库快捷移除）
  /// 数据源 chip 胶囊
  // 开关型设置项
  // 信息型设置项（不可点击）
  /// 帮助按钮：helpText 非空时显示（?）图标，点击弹出详细帮助
  /// 弹出设置项帮助（底部弹层：标题 + 详细说明）
  // 图标容器
  // ==================== 对话框 ====================

  OrientationMode _parseOrientationMode(String value) {
    return switch (value) {
      'vertical' => OrientationMode.vertical,
      'horizontal' => OrientationMode.horizontal,
      _ => OrientationMode.both,
    };
  }

  // 重置设置对话框：清除所有偏好设置，提示用户重启生效
  // 导出日志：预览内容 + 复制/打开文件操作
  // 清除日志确认对话框
  // PR #81：观看统计详情对话框
  // - 显示总次数、平均完播率、最近 7 天统计、最近 10 条记录
  // - 提供"清除统计"按钮
  // 辅助：统计行
  // 检查更新：调 GitHub Releases API 对比版本号
  /// 开始下载 APK：显示进度对话框，下载完成后触发安装
  // 显示下载失败对话框
  // 显示安装确认对话框
  /// 安装 APK：使用 open_filex 调用系统安装器
  /// 失败时通过 SnackBar 告知用户原因，避免"点击无反应"的困惑
  // 显示更新结果对话框
  // 打开外部 URL；失败时提示用户，避免"点击无反应"
  /// 打赏支持对话框
  ///
  /// 组合方式：展示微信/支付宝收款码（如已提供），并提供外部打赏链接。
  /// 收款码图片放置在 assets/images/ 下，文件名固定为：
  /// - donate_wechat.png（微信收款码）
  /// - donate_alipay.png（支付宝收款码）
  /// 如未提供图片，则显示占位提示 + 跳转链接。
  /// 打开自定义中文许可证页面
  ///
  /// 替代框架内置的英文 [showLicensePage]，使用 [LicenseRegistry] 异步收集
  /// 所有依赖的许可证条目，渲染为中文界面的可展开列表。
  // ==================== 工具方法 ====================

  // 缓存管理入口
  Widget _buildCacheManagementTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.storage, color: Colors.teal),
      title: const Text('缓存管理'),
      subtitle: const Text('查看和清理图片缓存、日志'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CacheManagementPage()),
      ),
    );
  }

  // 反馈入口
  Widget _buildFeedbackTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.feedback_outlined, color: Colors.teal),
      title: const Text('反馈与帮助'),
      subtitle: const Text('遇到问题？一键提交反馈'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FeedbackPage()),
      ),
    );
  }

  // 网络诊断入口
  Widget _buildNetworkDiagnosticTile(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final serverUrl = auth.embyServerUrl ?? auth.backendUrl;
    return ListTile(
      leading: const Icon(Icons.network_check, color: Colors.teal),
      title: const Text('网络诊断'),
      subtitle: const Text('检测服务器连接、延迟和证书状态'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NetworkDiagnosticPage(serverUrl: serverUrl),
        ),
      ),
    );
  }

  // 退出演示模式
  Widget _buildExitDemoTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.exit_to_app, color: Colors.red),
      title: const Text('退出演示模式'),
      subtitle: const Text('返回登录页，连接真实服务器'),
      onTap: () {
        ApiClient.demoMode = false;
        ref.read(demoModeProvider.notifier).state = false;
        // 重置 auth state，避免 demo 登录状态残留
        ref.read(authProvider.notifier).state = const AuthState();
        // 清除演示模式缓存的 mock 数据，避免残留
        try {
          ref.read(cacheControllerProvider).invalidateAll();
        } catch (_) {}
        AppLogger.info('退出演示模式');
        context.go('/login');
      },
    );
  }

  // 年度报告入口
  Widget _buildYearReportTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.auto_graph, color: Colors.teal),
      title: const Text('年度报告'),
      subtitle: const Text('查看今年的观影统计'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const YearReportPage()),
      ),
    );
  }

  // 智能缓存清理开关
  Widget _buildSmartCacheTile(BuildContext context, WidgetRef ref) {
    return StatefulBuilder(
      builder: (context, setTileState) {
        return FutureBuilder<bool>(
          future: SharedPreferences.getInstance()
              .then((p) => p.getBool('smart_cache_cleanup') ?? true),
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? true;
            return SwitchListTile(
              secondary: const Icon(Icons.memory, color: Colors.teal),
              title: const Text('智能缓存清理'),
              subtitle: const Text('内存不足时自动清理图片和视频缓存'),
              value: enabled,
              onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('smart_cache_cleanup', v);
                setTileState(() {});
              },
            );
          },
        );
      },
    );
  }

  void _showRatingPicker(BuildContext context, WidgetRef ref) {
    const ratings = ['G', 'PG', 'PG-13', 'R', 'NC-17'];
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('选择最高允许评分'),
            ),
            ...ratings.map((r) => RadioListTile<String>(
                  title: Text(r),
                  value: r,
                  groupValue: ref.read(parentalControlProvider).maxRating,
                  onChanged: (v) {
                    Navigator.pop(context);
                    ref.read(parentalControlProvider.notifier).setMaxRating(v);
                  },
                )),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('不限制'),
              onTap: () {
                Navigator.pop(context);
                ref.read(parentalControlProvider.notifier).setMaxRating(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPinLockDialog(BuildContext context, WidgetRef ref) async {
    final currentPin = ref.read(pinLockProvider);
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentPin.isEmpty ? '设置 PIN 锁' : '修改/关闭 PIN 锁'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentPin.isEmpty
                ? '输入 4 位数字 PIN'
                : '输入当前 PIN 以验证'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (currentPin.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(pinLockProvider.notifier).setPin('');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN 锁已关闭')),
                );
              },
              child: const Text('关闭锁'),
            ),
          TextButton(
            onPressed: () {
              final input = controller.text;
              if (input.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入 4 位数字')),
                );
                return;
              }
              if (currentPin.isNotEmpty && input != currentPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN 不正确')),
                );
                return;
              }
              if (currentPin.isEmpty) {
                // 新设置
                ref.read(pinLockProvider.notifier).setPin(input);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN 锁已启用')),
                );
              } else {
                // 验证成功，提示输入新 PIN
                Navigator.pop(context);
                _showSetNewPinDialog(context, ref);
              }
            },
            child: Text(currentPin.isEmpty ? '设置' : '验证'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetNewPinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入新 PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: '••••', counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入 4 位数字')),
                );
                return;
              }
              ref.read(pinLockProvider.notifier).setPin(controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN 已更新')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

// 打赏收款码占位组件：尚未提供图片时显示提示
