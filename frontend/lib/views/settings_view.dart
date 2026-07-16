// 设置页面：主题、播放、字幕、存储、账户、关于等
// 优化：组件提取、配置化、UI 优化、新增功能

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../utils/app_preferences.dart' show AppPreferencesService, OrientationMode;
import '../utils/logger.dart';
import '../widgets/library_selector.dart';

// ==================== 主页面 ====================

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

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
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 媒体库设置（PR #66：视频流 / 推荐可分别设置）
          _buildSection(
            context,
            ref,
            '媒体库',
            Icons.video_library_outlined,
            Colors.deepPurple,
            [
              _buildFeedLibraryTile(context, ref),
              _buildFeedExcludePlayedTile(context, ref),
              _buildRecommendLibraryTile(context, ref),
            ],
          ),
          // 推荐设置（PR #78：推荐规则优化）
          // 高级选项默认折叠，避免一次性展示 10 项造成视觉负担
          _buildSection(
            context,
            ref,
            '推荐',
            Icons.recommend_outlined,
            Colors.pink,
            [
              _buildRecommendMinRatingTile(context, ref),
              _buildRecommendExcludePlayedTile(context, ref),
              _buildRecommendMinRuntimeTile(context, ref),
              _buildRecommendIncludeTypesTile(context, ref),
              // 高级选项折叠区：完播率门控、时间衰减、反疲劳、用户评分
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
            ],
          ),
          // 播放设置
          _buildSection(
            context,
            ref,
            '播放',
            Icons.play_circle_outline,
            Colors.green,
            [
              _buildAutoPlayTile(context, ref),
              _buildPlaybackRateTile(context, ref),
              _buildVideoQualityTile(context, ref),
              _buildGestureControlTile(context, ref),
            ],
          ),
          // 字幕设置
          _buildSection(
            context,
            ref,
            '字幕',
            Icons.closed_caption_outlined,
            Colors.teal,
            [
              _buildSubtitleLanguageTile(context, ref),
              _buildSubtitleSizeTile(context, ref),
            ],
          ),
          // 外观设置
          _buildSection(
            context,
            ref,
            '外观',
            Icons.palette_outlined,
            Colors.indigo,
            [
              _buildThemeTile(context, ref),
              _buildOrientationTile(context, ref),
            ],
          ),
          // 存储设置
          _buildSection(
            context,
            ref,
            '存储',
            Icons.storage_outlined,
            Colors.grey,
            [
              _buildCacheTile(context, ref),
              _buildResetSettingsTile(context, ref),
            ],
          ),
          // PR #81：观看统计
          _buildSection(
            context,
            ref,
            '统计',
            Icons.analytics_outlined,
            Colors.deepPurple,
            [
              _buildWatchStatsTile(context, ref),
            ],
          ),
          // 服务器设置
          _buildSection(
            context,
            ref,
            '服务器',
            Icons.cloud_outlined,
            Colors.blue,
            [
              _buildServerInfoTile(context, ref),
            ],
          ),
          // 关于
          _buildSection(
            context,
            ref,
            '关于',
            Icons.info_outline,
            Colors.blueGrey,
            [
              _buildAboutTile(context, ref),
              _buildCheckUpdateTile(context, ref),
              _buildDonateTile(context, ref),
              _buildVersionTile(context, ref),
            ],
          ),
          // 账户
          _buildSection(
            context,
            ref,
            '账户',
            Icons.account_circle_outlined,
            Colors.blue,
            [
              _buildProfileTile(context, ref),
            ],
          ),
          const SizedBox(height: 16),
          _buildLogoutButton(context, ref),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== 分组构建 ====================

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData sectionIcon,
    Color sectionColor,
    List<Widget> children,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题：图标 + 文字，增加视觉层次
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: sectionColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(sectionIcon, color: sectionColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // 卡片容器：圆角 + 阴影 + 边框
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withOpacity(0.06),
              width: 0.5,
            ),
          ),
          child: Column(
            children: _buildItemList(children),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildItemList(List<Widget> children) {
    final widgets = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      widgets.add(children[i]);
      if (i < children.length - 1) {
        widgets.add(const Divider(height: 1, indent: 56));
      }
    }
    return widgets;
  }

  // ==================== 设置项构建 ====================

  // 媒体库 - 视频流使用（PR #66）
  Widget _buildFeedLibraryTile(BuildContext context, WidgetRef ref) {
    final selectedLibraries = ref.watch(selectedLibrariesProvider);
    final subtitle = _libraryNamesSubtitle(selectedLibraries);
    return _TapTile(
      icon: Icons.video_library_outlined,
      iconColor: Colors.deepPurple,
      title: '视频流使用',
      subtitle: subtitle,
      onTap: () =>
          LibrarySelector.show(context, scope: LibraryScope.feed),
    );
  }

  // 媒体库 - 视频流排除已观看
  Widget _buildFeedExcludePlayedTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(feedExcludePlayedProvider);
    return _SwitchTile(
      icon: Icons.visibility_off_outlined,
      iconColor: Colors.teal,
      title: '排除已观看',
      subtitle: exclude ? '视频流不显示已看过的视频' : '已看过的也会显示',
      value: exclude,
      onChanged: (value) {
        ref.read(feedExcludePlayedProvider.notifier).setExclude(value);
      },
    );
  }

  // 媒体库 - 推荐使用（PR #66）
  Widget _buildRecommendLibraryTile(BuildContext context, WidgetRef ref) {
    final recommendLibraries = ref.watch(recommendLibrariesProvider);
    final subtitle = _libraryNamesSubtitle(recommendLibraries);
    return _TapTile(
      icon: Icons.recommend_outlined,
      iconColor: Colors.pink,
      title: '推荐使用',
      subtitle: subtitle,
      onTap: () =>
          LibrarySelector.show(context, scope: LibraryScope.recommend),
    );
  }

  // 媒体库选择副标题：显示已选媒体库的名字（最多 3 个）
  String _libraryNamesSubtitle(List<Library> libraries) {
    if (libraries.isEmpty) return '未选择';
    if (libraries.length <= 3) {
      return libraries.map((l) => l.name).join('、');
    }
    return '${libraries.take(3).map((l) => l.name).join('、')} 等 ${libraries.length} 个';
  }

  // PR #78：推荐 - 评分阈值
  Widget _buildRecommendMinRatingTile(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(recommendMinRatingProvider);
    return _TapTile(
      icon: Icons.star_outline,
      iconColor: Colors.amber,
      title: '评分阈值',
      subtitle: rating == 0 ? '不过滤' : '≥ $rating',
      onTap: () => _showRecommendRatingDialog(context, ref, rating),
    );
  }

  // PR #78：推荐 - 排除已观看
  Widget _buildRecommendExcludePlayedTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(recommendExcludePlayedProvider);
    return _SwitchTile(
      icon: Icons.visibility_off_outlined,
      iconColor: Colors.brown,
      title: '排除已观看',
      subtitle: exclude ? '不再推荐已看过的视频' : '已看过的也会推荐',
      value: exclude,
      onChanged: (value) {
        ref.read(recommendExcludePlayedProvider.notifier).setExclude(value);
      },
    );
  }

  // PR #78：推荐 - 最短时长
  Widget _buildRecommendMinRuntimeTile(BuildContext context, WidgetRef ref) {
    final sec = ref.watch(recommendMinRuntimeSecProvider);
    return _TapTile(
      icon: Icons.timer_outlined,
      iconColor: Colors.deepOrange,
      title: '最短时长',
      subtitle: sec == 0 ? '不过滤' : '$sec 秒以上',
      onTap: () => _showRecommendRuntimeDialog(context, ref, sec),
    );
  }

  // 推荐评分阈值对话框
  void _showRecommendRatingDialog(
      BuildContext context, WidgetRef ref, double current) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('评分阈值'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current == 0 ? '不过滤' : '≥ ${current.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              min: 0,
              max: 10,
              divisions: 20,
              value: current,
              label: current == 0 ? '不过滤' : current.toStringAsFixed(1),
              onChanged: (v) {
                ref.read(recommendMinRatingProvider.notifier).setRating(v);
              },
            ),
            const Text(
              '0 = 不过滤；越高越严格（小众片变少）',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  // 推荐最短时长对话框
  void _showRecommendRuntimeDialog(
      BuildContext context, WidgetRef ref, int current) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('最短时长'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current == 0 ? '不过滤' : '$current 秒以上',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              min: 0,
              max: 600,
              divisions: 30,
              value: current.toDouble().clamp(0, 600),
              label: current == 0 ? '不过滤' : '${current}s',
              onChanged: (v) {
                ref.read(recommendMinRuntimeSecProvider.notifier).setMinRuntime(v.round());
              },
            ),
            const Text(
              '过滤测试片 / 预告片（默认 30s）',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  // PR #79：推荐 - 类型偏好
  // 5 个可切换的类型（多选）
  static const Map<String, String> _kRecommendTypeLabels = {
    'Movie': '电影',
    'Episode': '剧集',
    'Video': '视频',
    'MusicVideo': '音乐视频',
    'Series': '电视剧',
  };

  Widget _buildRecommendIncludeTypesTile(BuildContext context, WidgetRef ref) {
    final types = ref.watch(recommendIncludeTypesProvider);
    return _TapTile(
      icon: Icons.category_outlined,
      iconColor: Colors.indigo,
      title: '推荐类型',
      subtitle: _formatTypes(types),
      onTap: () => _showRecommendTypesDialog(context, ref, types),
    );
  }

  String _formatTypes(Set<String> types) {
    if (types.length == 5) return '全部类型';
    return types
        .map((t) => _kRecommendTypeLabels[t] ?? t)
        .toList()
        .join('、');
  }

  void _showRecommendTypesDialog(
      BuildContext context, WidgetRef ref, Set<String> current) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('推荐类型'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: _kRecommendTypeLabels.entries.map((entry) {
                  final type = entry.key;
                  final label = entry.value;
                  final checked = current.contains(type);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (_) async {
                      await ref
                          .read(recommendIncludeTypesProvider.notifier)
                          .toggle(type);
                      if (!context.mounted) return;
                      setLocalState(() {});
                    },
                    title: Text(label),
                    dense: true,
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // PR #85：完播率门控开关
  // - 关闭：推荐结果完全由 Emby 服务器决定（不应用黑名单/权重/种子）
  // - 开启：根据你的完播率历史优化推荐（默认）
  Widget _buildRecommendUseWatchHistoryTile(
      BuildContext context, WidgetRef ref) {
    final useWatchHistory = ref.watch(recommendUseWatchHistoryProvider);
    return _SwitchTile(
      icon: Icons.history_toggle_off_outlined,
      iconColor: Colors.deepPurple,
      title: '使用观看历史优化推荐',
      subtitle: useWatchHistory
          ? '已开启：黑名单、源权重、相似种子生效'
          : '已关闭：推荐结果仅由 Emby 服务器决定',
      value: useWatchHistory,
      onChanged: (value) {
        ref.read(recommendUseWatchHistoryProvider.notifier).setUse(value);
      },
    );
  }

  // PR #85：时间衰减半衰期（天）
  // - 0 天 = 不衰减（所有完播记录等权重）
  // - 14 天 = 默认（14 天前的记录权重衰减到 0.5）
  // - 范围 0-90 天
  Widget _buildRecommendHalfLifeDaysTile(
      BuildContext context, WidgetRef ref) {
    final halfLifeDays = ref.watch(recommendHalfLifeDaysProvider);
    return _TapTile(
      icon: Icons.timelapse_outlined,
      iconColor: Colors.brown,
      title: '记忆半衰期（天）',
      subtitle: halfLifeDays == 0
          ? '不衰减，所有记录等权重'
          : '$halfLifeDays 天前的记录权重衰减到 0.5',
      onTap: () => _showHalfLifeDaysDialog(context, ref, halfLifeDays),
    );
  }

  void _showHalfLifeDaysDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 预设值：0, 3, 7, 14, 30, 60, 90
    final options = <double>[0, 3, 7, 14, 30, 60, 90];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('记忆半衰期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '越短 = 推荐越关注最近的偏好；越长 = 老的偏好也会影响推荐。\n0 = 不衰减',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ...options.map((days) {
                final selected = current == days;
                return RadioListTile<double>(
                  value: days,
                  groupValue: current,
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref
                        .read(recommendHalfLifeDaysProvider.notifier)
                        .setDays(v);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  title: Text(days == 0
                      ? '不衰减 (0 天)'
                      : '$days 天'),
                  dense: true,
                  selected: selected,
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  // PR #88：反推荐疲劳开关
  // - 关闭：所有展示过的 item 也会被重推
  // - 开启：X 天内展示过的 item 不再推荐
  Widget _buildRecommendAntiFatigueEnabledTile(
      BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(recommendAntiFatigueEnabledProvider);
    return _SwitchTile(
      icon: Icons.repeat_on_outlined,
      iconColor: Colors.indigo,
      title: '避免重复推荐',
      // 同时 watch 天数 provider，使 subtitle 随天数变化实时更新
      subtitle: enabled
          ? '已开启：${ref.watch(recommendAntiFatigueDaysProvider)} 天内不重推'
          : '已关闭：所有 item 都可能被推荐',
      value: enabled,
      onChanged: (value) {
        ref.read(recommendAntiFatigueEnabledProvider.notifier).setEnabled(value);
      },
    );
  }

  // PR #88：反推荐疲劳天数（默认 30，范围 1-90）
  Widget _buildRecommendAntiFatigueDaysTile(
      BuildContext context, WidgetRef ref) {
    final days = ref.watch(recommendAntiFatigueDaysProvider);
    return _TapTile(
      icon: Icons.history_toggle_off,
      iconColor: Colors.deepOrange,
      title: '不重推天数',
      subtitle: '$days 天内展示过的 item 不再推荐',
      onTap: () => _showAntiFatigueDaysDialog(context, ref, days),
    );
  }

  void _showAntiFatigueDaysDialog(
      BuildContext context, WidgetRef ref, int current) {
    // 预设值：1, 3, 7, 14, 30, 60, 90
    final options = <int>[1, 3, 7, 14, 30, 60, 90];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('不重推天数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '越长 = 越不容易看到重复内容；越短 = 推荐变化越快。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ...options.map((d) {
                final selected = current == d;
                return RadioListTile<int>(
                  value: d,
                  groupValue: current,
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref
                        .read(recommendAntiFatigueDaysProvider.notifier)
                        .setDays(v);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  title: Text('$d 天'),
                  dense: true,
                  selected: selected,
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  // PR #89：用户评分加权开关
  // - 关闭：仅按 communityRating 过滤（已有逻辑）
  // - 开启：用户评分 < 阈值的 item 也跳过（除非收藏）
  Widget _buildRecommendUserRatingEnabledTile(
      BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(recommendUserRatingEnabledProvider);
    return _SwitchTile(
      icon: Icons.star_rate_outlined,
      iconColor: Colors.purple,
      title: '用户评分加权',
      // 同时 watch 阈值 provider，使 subtitle 随阈值变化实时更新
      subtitle: enabled
          ? '已开启：跳过用户评分 < ${ref.watch(recommendUserRatingMinProvider).toStringAsFixed(1)} 的 item（收藏项豁免）'
          : '已关闭：仅按社区评分过滤',
      value: enabled,
      onChanged: (value) {
        ref.read(recommendUserRatingEnabledProvider.notifier).setEnabled(value);
      },
    );
  }

  // PR #89：用户评分最低阈值（0-10，默认 4.0）
  Widget _buildRecommendUserRatingMinTile(
      BuildContext context, WidgetRef ref) {
    final minRating = ref.watch(recommendUserRatingMinProvider);
    return _TapTile(
      icon: Icons.star_half,
      iconColor: Colors.deepPurple,
      title: '最低用户评分',
      subtitle: minRating == 0
          ? '不过滤'
          : '≥ $minRating（0-10）',
      onTap: () => _showUserRatingMinDialog(context, ref, minRating),
    );
  }

  void _showUserRatingMinDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 预设值：0（关闭）/ 3.0 / 4.0 / 5.0 / 6.0 / 7.0 / 8.0
    final options = <double>[0, 3, 4, 5, 6, 7, 8];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('最低用户评分'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '用户评分 < 阈值的 item 不再推荐（收藏项豁免）。0 = 关闭该过滤。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ...options.map((d) {
                final selected = (current - d).abs() < 0.01;
                return RadioListTile<double>(
                  value: d,
                  groupValue: current,
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref
                        .read(recommendUserRatingMinProvider.notifier)
                        .setMin(v);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  title: Text(d == 0 ? '0（关闭）' : '≥ $d'),
                  dense: true,
                  selected: selected,
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  // 播放 - 自动播放
  Widget _buildAutoPlayTile(BuildContext context, WidgetRef ref) {
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    return _SwitchTile(
      icon: Icons.play_circle_outline,
      iconColor: Colors.green,
      title: '自动播放',
      subtitle: '视频结束后自动播放下一个',
      value: isAutoPlay,
      onChanged: (value) {
        ref.read(isAutoPlayProvider.notifier).setEnabled(value);
      },
    );
  }

  // 播放 - 默认倍速
  Widget _buildPlaybackRateTile(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(defaultPlaybackRateProvider);
    return _TapTile(
      icon: Icons.speed_outlined,
      iconColor: Colors.orange,
      title: '默认播放倍速',
      subtitle: '${rate.toStringAsFixed(1)}x',
      onTap: () => _showPlaybackRateDialog(context, ref, rate),
    );
  }

  // 播放 - 画质偏好
  Widget _buildVideoQualityTile(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(videoQualityProvider);
    return _TapTile(
      icon: Icons.high_quality_outlined,
      iconColor: Colors.blue,
      title: '画质偏好',
      subtitle: _videoQualityLabel(quality),
      onTap: () => _showVideoQualityDialog(context, ref, quality),
    );
  }

  // 播放 - 手势控制
  Widget _buildGestureControlTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.touch_app_outlined,
      iconColor: Colors.purple,
      title: '手势控制',
      subtitle: '配置滑动和双击手势',
      onTap: () => _showGestureControlDialog(context),
    );
  }

  // 字幕 - 默认语言
  Widget _buildSubtitleLanguageTile(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(defaultSubtitleLanguageProvider);
    return _TapTile(
      icon: Icons.closed_caption_outlined,
      iconColor: Colors.teal,
      title: '默认字幕语言',
      subtitle: lang.isEmpty ? '关闭' : _getLanguageName(lang),
      onTap: () => _showSubtitleDialog(context, ref, lang),
    );
  }

  // 字幕 - 字幕大小
  Widget _buildSubtitleSizeTile(BuildContext context, WidgetRef ref) {
    final size = ref.watch(subtitleSizeProvider);
    return _TapTile(
      icon: Icons.format_size_outlined,
      iconColor: Colors.teal,
      title: '字幕大小',
      subtitle: _subtitleSizeLabel(size),
      onTap: () => _showSubtitleSizeDialog(context, ref, size),
    );
  }

  // 外观 - 主题
  Widget _buildThemeTile(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return _TapTile(
      icon: Icons.dark_mode_outlined,
      iconColor: Colors.indigo,
      title: '主题',
      subtitle: _themeLabel(themeMode),
      onTap: () => _showThemeDialog(context, ref, themeMode),
    );
  }

  // 外观 - 方向过滤
  Widget _buildOrientationTile(BuildContext context, WidgetRef ref) {
    final orientationMode = ref.watch(orientationModeProvider);
    return _TapTile(
      icon: Icons.screen_rotation_outlined,
      iconColor: Colors.indigo,
      title: '视频方向',
      subtitle: orientationMode.zhLabel,
      onTap: () => _showOrientationDialog(context, ref, orientationMode),
    );
  }

  // 存储 - 清除缓存
  Widget _buildCacheTile(BuildContext context, WidgetRef ref) {
    final cacheSize = ref.watch(cacheSizeProvider);
    return _TapTile(
      icon: Icons.cleaning_services_outlined,
      iconColor: Colors.grey,
      title: '清除缓存',
      subtitle: _formatSize(cacheSize),
      onTap: () => _showClearCacheDialog(context, ref),
    );
  }

  // 存储 - 重置所有偏好设置到默认值
  // 仅清除"设置类"偏好，不影响登录信息、观看历史、收藏等用户数据
  Widget _buildResetSettingsTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.restore,
      iconColor: Colors.deepOrange,
      title: '重置设置',
      subtitle: '恢复所有偏好为默认值（不影响登录/历史/收藏）',
      onTap: () => _showResetSettingsDialog(context, ref),
    );
  }

  // PR #81：观看统计 tile
  // - 显示总次数 + 平均完播率
  // - 点击查看详情 + 清除按钮
  Widget _buildWatchStatsTile(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(watchStatsProvider);
    final avg = (stats.avgCompletion * 100).toStringAsFixed(0);
    return _TapTile(
      icon: Icons.analytics_outlined,
      iconColor: Colors.deepPurple,
      title: '观看统计',
      subtitle: stats.totalCount == 0
          ? '暂无数据'
          : '总 ${stats.totalCount} 次 · 平均完播率 $avg%',
      onTap: () => _showWatchStatsDialog(context, ref),
    );
  }

  // 服务器 - 服务器信息
  Widget _buildServerInfoTile(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return _InfoTile(
      icon: Icons.cloud_outlined,
      iconColor: Colors.blue,
      title: '当前服务器',
      subtitle: auth.backendUrl ?? '未连接',
    );
  }

  // 关于 - 应用信息
  Widget _buildAboutTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.info_outline,
      iconColor: Colors.blueGrey,
      title: '关于 EmbyTok',
      subtitle: '了解更多关于应用的信息',
      onTap: () => _showAboutDialog(context, ref),
    );
  }

  // 关于 - 检查更新
  Widget _buildCheckUpdateTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.system_update_outlined,
      iconColor: Colors.green,
      title: '检查更新',
      subtitle: '检查是否有新版本',
      onTap: () => _checkForUpdate(context, ref),
    );
  }

  // 关于 - 打赏支持
  Widget _buildDonateTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.volunteer_activism_outlined,
      iconColor: Colors.red,
      title: '打赏支持',
      subtitle: '请作者喝杯咖啡',
      onTap: () => _showDonateDialog(context),
    );
  }

  // 关于 - 版本信息（动态读取，避免硬编码）
  Widget _buildVersionTile(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final subtitle = versionAsync.when(
      data: (v) => v,
      loading: () => '加载中…',
      error: (_, __) => '未知',
    );
    return _InfoTile(
      icon: Icons.new_releases_outlined,
      iconColor: Colors.blueGrey,
      title: '版本',
      subtitle: subtitle,
    );
  }

  // 账户 - 用户信息
  Widget _buildProfileTile(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final name = auth.user?.name ?? '未登录';
    return _InfoTile(
      icon: Icons.account_circle_outlined,
      iconColor: Colors.blue,
      title: name,
      subtitle: auth.backendUrl ?? '未连接服务器',
    );
  }

  // 退出登录按钮
  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(Icons.logout, color: scheme.onError),
          label: Text(
            '退出登录',
            style: TextStyle(color: scheme.onError, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showLogoutDialog(context, ref),
        ),
      ),
    );
  }

  // ==================== 设置搜索 ====================

  // 构建设置项搜索索引：每个入口包含标题、分组、关键词、点击回调
  // 点击回调捕获当前 context 和 ref，确保搜索结果可直接执行操作
  List<_SettingEntry> _buildSearchIndex(BuildContext context, WidgetRef ref) {
    return <_SettingEntry>[
      // 媒体库
      _SettingEntry(
        title: '视频流使用',
        section: '媒体库',
        keywords: '视频流 媒体库 feed library',
        onTap: (ctx) => LibrarySelector.show(ctx, scope: LibraryScope.feed),
      ),
      _SettingEntry(
        title: '排除已观看',
        section: '媒体库',
        keywords: '视频流 排除 已观看 played',
        onTap: (ctx) {
          final value = ref.read(feedExcludePlayedProvider);
          ref.read(feedExcludePlayedProvider.notifier).setExclude(!value);
        },
      ),
      _SettingEntry(
        title: '推荐使用',
        section: '媒体库',
        keywords: '推荐 媒体库 recommend library',
        onTap: (ctx) => LibrarySelector.show(ctx, scope: LibraryScope.recommend),
      ),
      // 推荐
      _SettingEntry(
        title: '评分阈值',
        section: '推荐',
        keywords: '推荐 评分 阈值 rating',
        onTap: (ctx) =>
            _showRecommendRatingDialog(ctx, ref, ref.read(recommendMinRatingProvider)),
      ),
      _SettingEntry(
        title: '排除已观看',
        section: '推荐',
        keywords: '推荐 排除 已观看 played',
        onTap: (ctx) {
          final value = ref.read(recommendExcludePlayedProvider);
          ref.read(recommendExcludePlayedProvider.notifier).setExclude(!value);
        },
      ),
      _SettingEntry(
        title: '最短时长',
        section: '推荐',
        keywords: '推荐 最短 时长 runtime',
        onTap: (ctx) =>
            _showRecommendRuntimeDialog(ctx, ref, ref.read(recommendMinRuntimeSecProvider)),
      ),
      _SettingEntry(
        title: '推荐类型',
        section: '推荐',
        keywords: '推荐 类型 movie episode video musicvideo series',
        onTap: (ctx) =>
            _showRecommendTypesDialog(ctx, ref, ref.read(recommendIncludeTypesProvider)),
      ),
      _SettingEntry(
        title: '使用观看历史优化推荐',
        section: '推荐',
        keywords: '推荐 观看历史 完播率 门控 watch history',
        onTap: (ctx) {
          final value = ref.read(recommendUseWatchHistoryProvider);
          ref.read(recommendUseWatchHistoryProvider.notifier).setUse(!value);
        },
      ),
      _SettingEntry(
        title: '记忆半衰期',
        section: '推荐',
        keywords: '推荐 半衰期 衰减 halflife',
        onTap: (ctx) =>
            _showHalfLifeDaysDialog(ctx, ref, ref.read(recommendHalfLifeDaysProvider)),
      ),
      _SettingEntry(
        title: '避免重复推荐',
        section: '推荐',
        keywords: '推荐 反疲劳 重复 anti fatigue',
        onTap: (ctx) {
          final value = ref.read(recommendAntiFatigueEnabledProvider);
          ref.read(recommendAntiFatigueEnabledProvider.notifier).setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '不重推天数',
        section: '推荐',
        keywords: '推荐 反疲劳 天数 days',
        onTap: (ctx) =>
            _showAntiFatigueDaysDialog(ctx, ref, ref.read(recommendAntiFatigueDaysProvider)),
      ),
      _SettingEntry(
        title: '用户评分加权',
        section: '推荐',
        keywords: '推荐 用户评分 加权 rating',
        onTap: (ctx) {
          final value = ref.read(recommendUserRatingEnabledProvider);
          ref.read(recommendUserRatingEnabledProvider.notifier).setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '最低用户评分',
        section: '推荐',
        keywords: '推荐 最低 用户评分 min rating',
        onTap: (ctx) =>
            _showUserRatingMinDialog(ctx, ref, ref.read(recommendUserRatingMinProvider)),
      ),
      // 播放
      _SettingEntry(
        title: '自动播放',
        section: '播放',
        keywords: '播放 自动 autoplay',
        onTap: (ctx) {
          final value = ref.read(isAutoPlayProvider);
          ref.read(isAutoPlayProvider.notifier).setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '默认播放倍速',
        section: '播放',
        keywords: '播放 倍速 rate speed',
        onTap: (ctx) =>
            _showPlaybackRateDialog(ctx, ref, ref.read(defaultPlaybackRateProvider)),
      ),
      _SettingEntry(
        title: '画质偏好',
        section: '播放',
        keywords: '播放 画质 quality 1080p 720p',
        onTap: (ctx) =>
            _showVideoQualityDialog(ctx, ref, ref.read(videoQualityProvider)),
      ),
      _SettingEntry(
        title: '手势控制',
        section: '播放',
        keywords: '播放 手势 gesture 滑动 双击 长按',
        onTap: (ctx) => _showGestureControlDialog(ctx),
      ),
      // 字幕
      _SettingEntry(
        title: '默认字幕语言',
        section: '字幕',
        keywords: '字幕 语言 subtitle 中英日韩',
        onTap: (ctx) => _showSubtitleDialog(ctx, ref, ref.read(defaultSubtitleLanguageProvider)),
      ),
      _SettingEntry(
        title: '字幕大小',
        section: '字幕',
        keywords: '字幕 大小 size small medium large',
        onTap: (ctx) => _showSubtitleSizeDialog(ctx, ref, ref.read(subtitleSizeProvider)),
      ),
      // 外观
      _SettingEntry(
        title: '主题',
        section: '外观',
        keywords: '外观 主题 深色 浅色 theme dark light',
        onTap: (ctx) => _showThemeDialog(ctx, ref, ref.read(themeModeProvider)),
      ),
      _SettingEntry(
        title: '视频方向',
        section: '外观',
        keywords: '外观 方向 竖屏 横屏 orientation',
        onTap: (ctx) => _showOrientationDialog(ctx, ref, ref.read(orientationModeProvider)),
      ),
      // 存储
      _SettingEntry(
        title: '清除缓存',
        section: '存储',
        keywords: '存储 缓存 清除 cache',
        onTap: (ctx) => _showClearCacheDialog(ctx, ref),
      ),
      _SettingEntry(
        title: '重置设置',
        section: '存储',
        keywords: '存储 重置 设置 reset restore 默认',
        onTap: (ctx) => _showResetSettingsDialog(ctx, ref),
      ),
      // 统计
      _SettingEntry(
        title: '观看统计',
        section: '统计',
        keywords: '统计 观看 完播率 stats',
        onTap: (ctx) => _showWatchStatsDialog(ctx, ref),
      ),
      // 关于
      _SettingEntry(
        title: '关于 EmbyTok',
        section: '关于',
        keywords: '关于 about embytok',
        onTap: (ctx) => _showAboutDialog(ctx, ref),
      ),
      _SettingEntry(
        title: '检查更新',
        section: '关于',
        keywords: '检查更新 update 升级 版本',
        onTap: (ctx) => _checkForUpdate(ctx, ref),
      ),
      _SettingEntry(
        title: '打赏支持',
        section: '关于',
        keywords: '打赏 赞赏 捐款 赞助 donate 咖啡',
        onTap: (ctx) => _showDonateDialog(ctx),
      ),
    ];
  }

  // 显示设置搜索对话框
  void _showSettingsSearch(BuildContext context, WidgetRef ref) {
    final entries = _buildSearchIndex(context, ref);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _SettingsSearchSheet(entries: entries),
    );
  }

  // ==================== 组件定义 ====================

  // 点击型设置项
  static Widget _TapTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 13,
                ),
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: onTap,
      );
    });
  }

  // 开关型设置项
  static Widget _SwitchTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 13,
                ),
              )
            : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: scheme.primary,
        ),
      );
    });
  }

  // 信息型设置项（不可点击）
  static Widget _InfoTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: 15),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 13,
                ),
              )
            : null,
      );
    });
  }

  // 图标容器
  static Widget _IconContainer({required IconData icon, required Color color}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ==================== 对话框 ====================

  void _showThemeDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '选择主题',
        options: const [
          ('跟随系统', 'system'),
          ('深色', 'dark'),
          ('浅色', 'light'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(themeModeProvider.notifier).setTheme(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showPlaybackRateDialog(
    BuildContext context,
    WidgetRef ref,
    double current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '默认播放倍速',
        options: const [
          ('0.5x', 0.5),
          ('0.75x', 0.75),
          ('1.0x', 1.0),
          ('1.25x', 1.25),
          ('1.5x', 1.5),
          ('2.0x', 2.0),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(defaultPlaybackRateProvider.notifier).set(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showVideoQualityDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '画质偏好',
        options: const [
          ('自动（最佳画质）', 'auto'),
          ('1080p', '1080p'),
          ('720p', '720p'),
          ('480p', '480p'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(videoQualityProvider.notifier).set(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showGestureControlDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 手势说明与 fullscreen_video_page.dart 中实际实现保持一致：
    // - 单击：切换控制栏显隐（非播放/暂停）
    // - 双击左右 1/3：快进/快退 10 秒；双击中间 1/3：点赞（收藏）
    // - 长按：2x 倍速播放（松开恢复）
    // - 上下滑动：左半屏调亮度，右半屏调音量
    // - 左右滑动：拖动进度条（每像素 100ms）
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('手势控制', style: TextStyle(color: scheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GestureItem(
              icon: Icons.touch_app,
              title: '单击',
              description: '显示/隐藏控制栏',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.double_arrow,
              title: '双击左右侧',
              description: '快退 / 快进 10 秒',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.favorite,
              title: '双击中间',
              description: '点赞（加入收藏）',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.fast_forward,
              title: '长按',
              description: '2x 倍速播放，松开恢复',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.swipe_up,
              title: '上下滑动（左半屏）',
              description: '调节屏幕亮度',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.volume_up,
              title: '上下滑动（右半屏）',
              description: '调节音量',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.swipe,
              title: '左右滑动',
              description: '拖动进度条定位',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSubtitleDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '默认字幕语言',
        options: const [
          ('关闭', ''),
          ('中文（简体）', 'zh-CN'),
          ('中文（繁体）', 'zh-TW'),
          ('英语', 'en'),
          ('日语', 'ja'),
          ('韩语', 'ko'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(defaultSubtitleLanguageProvider.notifier).set(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSubtitleSizeDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '字幕大小',
        options: const [
          ('小', 'small'),
          ('中', 'medium'),
          ('大', 'large'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(subtitleSizeProvider.notifier).set(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showOrientationDialog(
    BuildContext context,
    WidgetRef ref,
    OrientationMode current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '视频方向',
        options: const [
          ('全部', 'both'),
          ('只看竖屏', 'vertical'),
          ('只看横屏', 'horizontal'),
        ],
        currentValue: _orientationModeToString(current),
        onSelect: (v) {
          ref.read(orientationModeProvider.notifier).setMode(
            _parseOrientationMode(v),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  String _orientationModeToString(OrientationMode mode) {
    return switch (mode) {
      OrientationMode.vertical => 'vertical',
      OrientationMode.horizontal => 'horizontal',
      OrientationMode.both => 'both',
    };
  }

  OrientationMode _parseOrientationMode(String value) {
    return switch (value) {
      'vertical' => OrientationMode.vertical,
      'horizontal' => OrientationMode.horizontal,
      _ => OrientationMode.both,
    };
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('清除缓存', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '确定要清除全部缓存吗？这将删除临时下载的缩略图和字幕文件。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cacheSizeProvider.notifier).clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('缓存已清除'),
                  backgroundColor: scheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('清除', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // 重置设置对话框：清除所有偏好设置，提示用户重启生效
  void _showResetSettingsDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('重置设置', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '将所有偏好设置恢复为默认值，包括：播放、字幕、外观、推荐、媒体库等。\n\n'
          '不影响：登录信息、观看历史、搜索历史、收藏。\n\n'
          '重置后需要重启应用以完全生效。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              await const AppPreferencesService().resetAllSettings();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('设置已重置，请重启应用以完全生效'),
                  backgroundColor: scheme.primary,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('重置', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // PR #81：观看统计详情对话框
  // - 显示总次数、平均完播率、最近 7 天统计、最近 10 条记录
  // - 提供"清除统计"按钮
  void _showWatchStatsDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final stats = ref.watch(watchStatsProvider);
        return AlertDialog(
          backgroundColor: scheme.surface,
          title: Text('观看统计', style: TextStyle(color: scheme.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 概览
                  _buildStatRow(scheme, '总观看次数', '${stats.totalCount}'),
                  _buildStatRow(
                    scheme,
                    '平均完播率',
                    '${(stats.avgCompletion * 100).toStringAsFixed(0)}%',
                  ),
                  _buildStatRow(
                      scheme, '最近 7 天', '${stats.last7DaysCount} 次'),
                  _buildStatRow(
                    scheme,
                    '近 7 天完播率',
                    '${(stats.last7DaysAvgCompletion * 100).toStringAsFixed(0)}%',
                  ),
                  const SizedBox(height: 16),
                  // 最近 10 条
                  if (stats.records.isNotEmpty) ...[
                    Text(
                      '最近观看',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...stats.records.take(10).map((r) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.itemTitle ?? r.itemId,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(r.completionRate * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: r.completionRate >= 0.8
                                    ? Colors.green
                                    : scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '暂无观看记录。开始播放视频后这里会显示统计。',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('关闭', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            if (stats.totalCount > 0)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: scheme.surface,
                      title: Text('清除统计',
                          style: TextStyle(color: scheme.onSurface)),
                      content: Text('确定要清除所有观看统计吗？',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('取消',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.error),
                          child: Text('清除',
                              style: TextStyle(color: scheme.onError)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(watchStatsProvider.notifier).clear();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: Text('清除统计', style: TextStyle(color: scheme.error)),
              ),
          ],
        );
      }),
    );
  }

  // 辅助：统计行
  Widget _buildStatRow(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          Text(value,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('退出登录', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '确定要退出当前账号吗？',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('退出', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // 检查更新：调 GitHub Releases API 对比版本号
  Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;

    // 1. 读取当前版本号
    final versionAsync = ref.read(appVersionProvider);
    final currentVersion = versionAsync.maybeWhen(
      data: (v) => v,
      orElse: () => '0.0.0',
    );
    // 去掉 buildNumber，只保留 x.y.z
    var currentVer = currentVersion;
    final plusIdx = currentVer.indexOf('+');
    if (plusIdx > 0) currentVer = currentVer.substring(0, plusIdx);

    // 2. 显示加载对话框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 20),
            Text('正在检查更新…',
                style: TextStyle(color: scheme.onSurface, fontSize: 15)),
          ],
        ),
      ),
    );

    // 3. 调用 GitHub API 检查
    final updateService = ref.read(updateCheckServiceProvider);
    final result = await updateService.checkForUpdate(currentVer);

    // 关闭加载对话框
    if (context.mounted) Navigator.pop(context);

    if (!context.mounted) return;

    // 4. 展示结果
    if (result.latestRelease == null) {
      // 无法获取 Release 信息（网络错误或无 Release）
      _showUpdateResultDialog(
        context,
        icon: Icons.cloud_off,
        title: '检查失败',
        message: '无法获取更新信息，请检查网络连接后重试。',
        actionText: '关闭',
        onAction: null,
        secondaryActionText: '前往 GitHub',
        onSecondaryAction: () => _launchUrl(updateService.releasePageUrl),
      );
    } else if (result.hasUpdate) {
      // 有新版本
      final release = result.latestRelease!;
      // 查找 APK 下载链接
      final apkAssets = release.assets.where((a) => a.isApk).toList();
      final hasApk = apkAssets.isNotEmpty;
      _showUpdateResultDialog(
        context,
        icon: Icons.system_update,
        title: '发现新版本',
        message: '当前版本：$currentVer\n最新版本：${release.version}\n\n'
            '${release.body.isNotEmpty ? release.body : release.name}',
        actionText: hasApk ? '下载安装' : '前往下载',
        onAction: () {
          if (hasApk) {
            _startDownloadApk(context, ref, apkAssets.first, release);
          } else {
            _launchUrl(release.htmlUrl);
          }
        },
        secondaryActionText: '稍后再说',
        onSecondaryAction: null,
      );
    } else {
      // 已是最新版本
      _showUpdateResultDialog(
        context,
        icon: Icons.check_circle,
        title: '已是最新版本',
        message: '当前版本：$currentVer\n您使用的是最新版本。',
        actionText: '关闭',
        onAction: null,
        secondaryActionText: null,
        onSecondaryAction: null,
      );
    }
  }

  /// 开始下载 APK：显示进度对话框，下载完成后触发安装
  void _startDownloadApk(
    BuildContext context,
    WidgetRef ref,
    ReleaseAsset apkAsset,
    ReleaseInfo release,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final updateService = ref.read(updateCheckServiceProvider);
    final cancelToken = CancelToken();
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('准备下载...');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // 启动下载
        WidgetsBinding.instance.addPostFrameCallback((_) {
          updateService
              .downloadApk(
            apkAsset,
            onProgress: (p) {
              progressNotifier.value = p;
              statusNotifier.value =
                  '${(p * 100).toStringAsFixed(0)}%  ·  ${_formatSize(apkAsset.size)}';
            },
            cancelToken: cancelToken,
          )
              .then((savePath) {
            if (ctx.mounted) {
              Navigator.pop(ctx);
              _showInstallDialog(ctx, savePath, release, scheme);
            }
          })
              .catchError((e) {
            if (CancelToken.isCancel(e)) return;
            if (ctx.mounted) {
              Navigator.pop(ctx);
              _showDownloadError(ctx, e.toString(), apkAsset.downloadUrl);
            }
          });
        });

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading, size: 28, color: scheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    '正在下载更新',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) {
                  return LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(scheme.primary),
                  );
                },
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) {
                  return Text(
                    status,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelToken.cancel();
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    ).then((_) {
      // 对话框关闭时释放资源
      progressNotifier.dispose();
      statusNotifier.dispose();
    });
  }

  // 显示下载失败对话框
  void _showDownloadError(BuildContext context, String error, String fallbackUrl) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            const Text(
              '下载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchUrl(fallbackUrl);
            },
            child: const Text('浏览器下载'),
          ),
        ],
      ),
    );
  }

  // 显示安装确认对话框
  void _showInstallDialog(
    BuildContext context,
    String apkPath,
    ReleaseInfo release,
    ColorScheme scheme,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              '下载完成',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '版本 ${release.version} 已下载完成，是否立即安装？',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后安装'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _installApk(apkPath);
            },
            child: const Text('立即安装'),
          ),
        ],
      ),
    );
  }

  /// 安装 APK：使用 open_filex 调用系统安装器
  Future<void> _installApk(String apkPath) async {
    try {
      final file = File(apkPath);
      if (!await file.exists()) {
        AppLogger.error('安装失败：文件不存在 $apkPath');
        return;
      }
      final result = await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');
      AppLogger.debug('APK 安装结果：${result.type} / ${result.message}');
    } catch (e) {
      AppLogger.error('安装 APK 失败', error: e);
    }
  }

  // 显示更新结果对话框
  void _showUpdateResultDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String actionText,
    VoidCallback? onAction,
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          if (secondaryActionText != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSecondaryAction?.call();
              },
              child: Text(secondaryActionText),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction?.call();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  // 打开外部 URL
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('打开链接失败', error: e);
    }
  }

  /// 打赏支持对话框
  ///
  /// 组合方式：展示微信/支付宝收款码（如已提供），并提供外部打赏链接。
  /// 收款码图片放置在 assets/images/ 下，文件名固定为：
  /// - donate_wechat.png（微信收款码）
  /// - donate_alipay.png（支付宝收款码）
  /// 如未提供图片，则显示占位提示 + 跳转链接。
  void _showDonateDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                '打赏支持',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '如果这个应用对你有帮助，\n可以请作者喝杯咖啡 ☕',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 收款码区域：用 errorBuilder 处理图片缺失
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_wechat.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _DonatePlaceholder(
                    icon: Icons.chat_outlined,
                    label: '微信收款码',
                    hint: '尚未提供，敬请期待',
                    color: const Color(0xFF07C160),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 支付宝收款码
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_alipay.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _DonatePlaceholder(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '支付宝收款码',
                    hint: '尚未提供，敬请期待',
                    color: const Color(0xFF1677FF),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 外部打赏链接（如爱发电等）
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl('https://github.com/1525745393/EmbyTok-Flutter'),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new,
                          size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '前往 GitHub 仓库',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 动态读取版本号
    final versionAsync = ref.read(appVersionProvider);
    final version = versionAsync.maybeWhen(
      data: (v) => v,
      orElse: () => 'unknown',
    );
    // 版权年份动态
    const startYear = 2024;
    final currentYear = DateTime.now().year;
    final copyrightYear = currentYear > startYear
        ? '$startYear-$currentYear'
        : '$startYear';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.play_circle_filled,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 12),
              // 应用名
              Text(
                'EmbyTok',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              // 版本号
              Text(
                '版本 $version',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              // 应用介绍
              Text(
                'EmbyTok 是一个为 Emby 和 Plex 媒体服务器设计的竖屏视频浏览客户端，提供类似 TikTok 的上下滑动体验，让你以更现代、便捷的方式浏览个人媒体库。',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // 功能亮点
              _AboutFeatureRow(
                icon: Icons.swipe_vertical,
                text: '上下滑动，沉浸式刷片体验',
              ),
              const SizedBox(height: 10),
              _AboutFeatureRow(
                icon: Icons.favorite_border,
                text: '收藏管理，快速访问心仪内容',
              ),
              const SizedBox(height: 10),
              _AboutFeatureRow(
                icon: Icons.tv,
                text: '支持 Emby / Plex 媒体服务器',
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // GitHub 仓库入口：点击跳转到项目仓库
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl('https://github.com/1525745393/EmbyTok-Flutter'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'GitHub 仓库',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 14, color: scheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 版权
              Text(
                '© $copyrightYear EmbyTok  contributors',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '本软件基于开源协议发布',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 打开自定义中文许可证页面（替代框架英文 showLicensePage）
              _showLicensePage(context, version: version, scheme: scheme);
            },
            child: const Text('开源许可证'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 打开自定义中文许可证页面
  ///
  /// 替代框架内置的英文 [showLicensePage]，使用 [LicenseRegistry] 异步收集
  /// 所有依赖的许可证条目，渲染为中文界面的可展开列表。
  void _showLicensePage(
    BuildContext context, {
    required String version,
    required ColorScheme scheme,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LicensePage(
          applicationName: 'EmbyTok',
          applicationVersion: version,
          primaryColor: scheme.primary,
        ),
      ),
    );
  }

  // ==================== 工具方法 ====================

  String _themeLabel(String mode) {
    switch (mode) {
      case 'dark':
        return '深色';
      case 'light':
        return '浅色';
      case 'system':
      default:
        return '跟随系统';
    }
  }

  String _videoQualityLabel(String quality) {
    switch (quality) {
      case '1080p':
        return '1080p';
      case '720p':
        return '720p';
      case '480p':
        return '480p';
      case 'auto':
      default:
        return '自动选择最佳画质';
    }
  }

  String _subtitleSizeLabel(String size) {
    switch (size) {
      case 'small':
        return '小';
      case 'large':
        return '大';
      case 'medium':
      default:
        return '中等';
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'zh-CN':
        return '中文（简体）';
      case 'zh-TW':
        return '中文（繁体）';
      case 'en':
        return '英语';
      case 'ja':
        return '日语';
      case 'ko':
        return '韩语';
      default:
        return code;
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '暂无缓存';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// 打赏收款码占位组件：尚未提供图片时显示提示
class _DonatePlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;

  const _DonatePlaceholder({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// 关于页的功能亮点行
class _AboutFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutFeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 自定义中文许可证页面 ====================

/// 自定义中文许可证页面
///
/// 替代 Flutter 框架内置的英文 [showLicensePage]，使用 [LicenseRegistry]
/// 异步收集所有依赖的许可证条目，渲染为中文界面的可展开列表，
/// 支持按包名搜索过滤。
class _LicensePage extends StatefulWidget {
  final String applicationName;
  final String applicationVersion;
  final Color primaryColor;

  const _LicensePage({
    required this.applicationName,
    required this.applicationVersion,
    required this.primaryColor,
  });

  @override
  State<_LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends State<_LicensePage> {
  // 收集到的所有许可证条目
  List<_LicenseEntryView> _entries = const [];
  bool _isLoading = true;
  String? _error;
  // 搜索状态
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 收集 LicenseRegistry.licenses 流并聚合为列表
  Future<void> _loadLicenses() async {
    try {
      final entries = <_LicenseEntryView>[];
      // LicenseRegistry.licenses 是单订阅流，await for 一次性消费
      await for (final entry in LicenseRegistry.licenses) {
        final packages = entry.packages.toList();
        final body = entry.paragraphs.map((p) => p.text).join('\n');
        if (packages.isEmpty) {
          // 无包名的条目归入"未命名包"
          entries.add(_LicenseEntryView(
            packageName: '(未命名包)',
            body: body,
          ));
        } else {
          // 一个 LicenseEntry 可能覆盖多个包，分别建立条目以便搜索
          for (final pkg in packages) {
            entries.add(_LicenseEntryView(packageName: pkg, body: body));
          }
        }
      }
      // 按包名排序，便于查找
      entries.sort((a, b) =>
          a.packageName.toLowerCase().compareTo(b.packageName.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载许可证失败：$e';
        _isLoading = false;
      });
    }
  }

  // 按搜索关键词过滤包名
  List<_LicenseEntryView> get _filtered {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries
        .where((e) => e.packageName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索包名...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
                style: TextStyle(color: scheme.onSurface, fontSize: 16),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('开源许可证'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消搜索',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索包名',
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  // 主体内容：加载中 / 错误 / 空态 / 列表 四种状态
  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: widget.primaryColor),
            const SizedBox(height: 12),
            Text(
              '正在加载许可证...',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: scheme.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? '暂无许可证信息' : '没有匹配「$_searchQuery」的包',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length + 1, // +1 为顶部说明卡片
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeaderCard(scheme, list.length);
        final entry = list[index - 1];
        return _buildLicenseTile(scheme, entry);
      },
    );
  }

  // 顶部说明卡片：致谢与应用信息
  Widget _buildHeaderCard(ColorScheme scheme, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: widget.primaryColor),
              const SizedBox(width: 6),
              Text(
                '${widget.applicationName} · 版本 ${widget.applicationVersion}',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '本应用使用了 $count 个开源软件包，谨向以下项目的作者致以诚挚谢意。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 单个许可证条目：点击展开查看全文
  Widget _buildLicenseTile(ColorScheme scheme, _LicenseEntryView entry) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(
        entry.packageName,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '点击查看许可证全文',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
      ),
      children: [
        SelectableText(
          entry.body.isEmpty ? '（无许可证文本）' : entry.body,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// 许可证条目视图模型
class _LicenseEntryView {
  final String packageName;
  final String body;
  const _LicenseEntryView({required this.packageName, required this.body});
}


// ==================== 推荐高级选项折叠组件 ====================

/// 推荐高级选项折叠 tile
///
/// 基础推荐设置始终显示；高级选项（完播率门控、时间衰减、反疲劳、用户评分）
/// 默认折叠，点击"高级选项"后展开。展开状态为局部 state，页面重建后重置为折叠。
class _RecommendAdvancedTile extends StatefulWidget {
  /// 高级选项 tile 构建器：每次 build 时调用，确保 ref.watch 生效
  final List<Widget> Function() advancedTilesBuilder;

  const _RecommendAdvancedTile({required this.advancedTilesBuilder});

  @override
  State<_RecommendAdvancedTile> createState() => _RecommendAdvancedTileState();
}

class _RecommendAdvancedTileState extends State<_RecommendAdvancedTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: SettingsView._IconContainer(
            icon: Icons.tune,
            color: Colors.pink,
          ),
          title: Text(
            '高级选项',
            style: TextStyle(color: scheme.onSurface, fontSize: 15),
          ),
          subtitle: Text(
            '完播率门控、时间衰减、反疲劳、用户评分',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: scheme.onSurfaceVariant,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        // 仅在展开时构建高级 tiles，避免折叠状态下触发不必要的 ref.watch
        if (_expanded) ...[
          const Divider(height: 1, indent: 56),
          ...widget.advancedTilesBuilder().expand((tile) => [tile, const Divider(height: 1, indent: 56)]).toList()..removeLast(),
        ],
      ],
    );
  }
}

// ==================== 手势项组件 ====================

class _GestureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _GestureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.primary, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== 通用选项对话框 ====================

class _OptionDialog<T> extends StatelessWidget {
  final String title;
  final List<(String label, T value)> options;
  final T currentValue;
  final ValueChanged<T> onSelect;

  const _OptionDialog({
    required this.title,
    required this.options,
    required this.currentValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      title: Text(title, style: TextStyle(color: scheme.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final selected = opt.$2 == currentValue;
          return ListTile(
            title: Text(
              opt.$1,
              style: TextStyle(
                color: selected ? scheme.primary : scheme.onSurface,
                fontSize: 15,
              ),
            ),
            trailing: selected
                ? Icon(Icons.check, color: scheme.primary)
                : null,
            onTap: () => onSelect(opt.$2),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

// ==================== 设置搜索 ====================

/// 单个可搜索的设置入口
class _SettingEntry {
  final String title;
  final String section;
  final String keywords;
  final void Function(BuildContext context) onTap;

  const _SettingEntry({
    required this.title,
    required this.section,
    required this.keywords,
    required this.onTap,
  });

  /// 判断该入口是否匹配搜索词（标题、分组、关键词任一命中即可）
  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        section.toLowerCase().contains(q) ||
        keywords.toLowerCase().contains(q);
  }
}

/// 设置搜索底部表单：实时过滤设置项，点击后执行对应操作并关闭
class _SettingsSearchSheet extends StatefulWidget {
  final List<_SettingEntry> entries;

  const _SettingsSearchSheet({required this.entries});

  @override
  State<_SettingsSearchSheet> createState() => _SettingsSearchSheetState();
}

class _SettingsSearchSheetState extends State<_SettingsSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_SettingEntry> get _filtered {
    if (_query.isEmpty) return widget.entries;
    return widget.entries.where((e) => e.matches(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _filtered;
    // 设置为屏幕高度的 70%，确保 Expanded 有明确的高度约束
    final sheetHeight = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: sheetHeight,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索设置项…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            // 搜索结果列表
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配的设置项',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return ListTile(
                          leading: Icon(Icons.settings_outlined,
                              color: scheme.primary),
                          title: Text(entry.title),
                          subtitle: Text(
                            entry.section,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            entry.onTap(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
