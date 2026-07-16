// 设置页面：主题、播放、字幕、存储、账户、关于等
// 优化：组件提取、配置化、UI 优化、新增功能

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/app_preferences.dart' show OrientationMode;
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
              // PR #85：用户控制 - 完播率门控开关 + 时间衰减半衰期
              _buildRecommendUseWatchHistoryTile(context, ref),
              _buildRecommendHalfLifeDaysTile(context, ref),
              // PR #88：用户控制 - 反推荐疲劳（X 天内不重推）
              _buildRecommendAntiFatigueEnabledTile(context, ref),
              _buildRecommendAntiFatigueDaysTile(context, ref),
              // PR #89：用户控制 - 用户评分加权
              _buildRecommendUserRatingEnabledTile(context, ref),
              _buildRecommendUserRatingMinTile(context, ref),
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
              _buildAboutTile(context),
              _buildVersionTile(context),
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
      subtitle: enabled
          ? '已开启：$ref.read(recommendAntiFatigueDaysProvider) 天内不重推'
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
      subtitle: enabled
          ? '已开启：跳过用户评分 < ${ref.read(recommendUserRatingMinProvider).toStringAsFixed(1)} 的 item（收藏项豁免）'
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
  Widget _buildAboutTile(BuildContext context) {
    return _TapTile(
      icon: Icons.info_outline,
      iconColor: Colors.blueGrey,
      title: '关于 EmbyTok',
      subtitle: '了解更多关于应用的信息',
      onTap: () => _showAboutDialog(context),
    );
  }

  // 关于 - 版本信息
  Widget _buildVersionTile(BuildContext context) {
    return _InfoTile(
      icon: Icons.new_releases_outlined,
      iconColor: Colors.blueGrey,
      title: '版本',
      subtitle: '1.82.0',
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
              icon: Icons.swipe,
              title: '上下滑动',
              description: '调节音量/亮度',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.touch_app,
              title: '左右滑动',
              description: '快进/快退 10 秒',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.double_arrow,
              title: '双击左右侧',
              description: '快进/快退 10 秒',
            ),
            const SizedBox(height: 12),
            _GestureItem(
              icon: Icons.pause,
              title: '单击',
              description: '播放/暂停',
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

  void _showAboutDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showAboutDialog(
      context: context,
      applicationName: 'EmbyTok',
      applicationVersion: '1.82.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
      ),
      children: [
        const SizedBox(height: 16),
        const Text('EmbyTok 是一个为 Emby 和 Plex 媒体服务器设计的竖屏视频浏览客户端，提供类似 TikTok 的体验。'),
        const SizedBox(height: 16),
        const Text('© 2024 EmbyTok'),
      ],
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
