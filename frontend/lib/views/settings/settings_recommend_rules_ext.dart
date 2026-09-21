// 从 settings 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== 推荐规则设置（下半） ====================

extension _SettingsRecommendRules2 on SettingsView {
  void _showRecommendRatingDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 使用 StatefulBuilder 让 Slider 拖动时能局部刷新显示值
    // 避免 provider 更新后 dialog 内显示值仍为旧值的 UI 不一致问题
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('评分阈值'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current == 0 ? '不过滤' : '≥ ${current.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: _kFontSizeXXLarge, fontWeight: FontWeight.bold),
                ),
                Slider(
                  min: 0,
                  max: 10,
                  divisions: 20,
                  value: current,
                  label: current == 0 ? '不过滤' : current.toStringAsFixed(1),
                  // 拖动时仅更新 UI 显示值，松手时才写入持久化，减少无效写入
                  onChanged: (v) {
                    setDialogState(() => current = v);
                  },
                  onChangeEnd: (v) {
                    ref.read(recommendMinRatingProvider.notifier).setRating(v);
                  },
                ),
                const Text(
                  '0 = 不过滤；越高越严格（小众片变少）',
                  style:
                      TextStyle(fontSize: _kFontSizeSmall, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecommendRuntimeDialog(
      BuildContext context, WidgetRef ref, int current) {
    // StatefulBuilder：Slider 拖动时局部刷新显示值
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('最短时长'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current == 0 ? '不过滤' : '$current 秒以上',
                  style: const TextStyle(
                      fontSize: _kFontSizeXXLarge, fontWeight: FontWeight.bold),
                ),
                Slider(
                  min: 0,
                  max: 600,
                  divisions: 30,
                  value: current.toDouble().clamp(0, 600),
                  label: current == 0 ? '不过滤' : '${current}s',
                  // 拖动时仅更新 UI 显示值，松手时才写入持久化，减少无效写入
                  onChanged: (v) {
                    setDialogState(() => current = v.round());
                  },
                  onChangeEnd: (v) {
                    ref
                        .read(recommendMinRuntimeSecProvider.notifier)
                        .setMinRuntime(v.round());
                  },
                ),
                const Text(
                  '过滤测试片 / 预告片（默认 30s）',
                  style:
                      TextStyle(fontSize: _kFontSizeSmall, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecommendIncludeTypesTile(BuildContext context, WidgetRef ref) {
    final types = ref.watch(recommendIncludeTypesProvider);
    return settingsTapTile(
      icon: Icons.category_outlined,
      iconColor: Colors.indigo,
      title: '推荐类型',
      subtitle: _formatTypes(types),
      onTap: () => _showRecommendTypesDialog(context, ref, types),
      helpText:
          '选择推荐页包含的内容类型。\n\n可勾选：电影 / 剧集 / 单集 / 视频 / 音乐视频等。\n\n未勾选的类型不会出现在推荐结果中，用于控制推荐内容的体裁范围。',
    );
  }

  String _formatTypes(Set<String> types) {
    if (types.length == 5) return '全部类型';
    return types
        .map((t) => SettingsView._kRecommendTypeLabels[t] ?? t)
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
                children:
                    SettingsView._kRecommendTypeLabels.entries.map((entry) {
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

  Widget _buildRecommendUseWatchHistoryTile(
      BuildContext context, WidgetRef ref) {
    final useWatchHistory = ref.watch(recommendUseWatchHistoryProvider);
    return settingsSwitchTile(
      icon: Icons.history_toggle_off_outlined,
      iconColor: Colors.deepPurple,
      title: '使用观看历史优化推荐',
      subtitle:
          useWatchHistory ? '已开启：黑名单、源权重、相似种子生效' : '已关闭：推荐结果仅由 Emby 服务器决定',
      value: useWatchHistory,
      onChanged: (value) {
        ref.read(recommendUseWatchHistoryProvider.notifier).setUse(value);
      },
      helpText:
          '开启后，推荐算法会参考你的观看历史计算相似推荐与「为你推荐」。\n\n· 开启 → 推荐更贴合你的口味（需要服务器端有播放记录）\n· 关闭 → 推荐退化为冷启动策略（按评分/热度）\n\n关闭时「相似」标签可能没有数据。',
    );
  }

  Widget _buildRecommendHalfLifeDaysTile(BuildContext context, WidgetRef ref) {
    final halfLifeDays = ref.watch(recommendHalfLifeDaysProvider);
    return settingsTapTile(
      icon: Icons.timelapse_outlined,
      iconColor: Colors.brown,
      title: '记忆半衰期（天）',
      subtitle:
          halfLifeDays == 0 ? '不衰减，所有记录等权重' : '$halfLifeDays 天前的记录权重衰减到 0.5',
      onTap: () => _showHalfLifeDaysDialog(context, ref, halfLifeDays),
      helpText:
          '时间衰减半衰期（天）。\n\n观看历史对推荐的影响随时间衰减：半衰期越短，越久远的观看记录权重越低，推荐越偏向近期口味。\n\n· 默认 14 天\n· 调小 → 只看近期偏好\n· 调大 → 长期偏好更稳定',
    );
  }

  void _showHalfLifeDaysDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 预设值：0, 3, 7, 14, 30, 60, 90
    final options = <double>[0, 3, 7, 14, 30, 60, 90];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder：选中后立即更新选中态视觉反馈，不立即关闭对话框
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('记忆半衰期'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '越短 = 推荐越关注最近的偏好；越长 = 老的偏好也会影响推荐。\n0 = 不衰减',
                      style: TextStyle(fontSize: _kFontSizeBody),
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
                        if (!dialogContext.mounted) return;
                        setLocalState(() => current = v);
                      },
                      title: Text(days == 0 ? '不衰减 (0 天)' : '$days 天'),
                      dense: true,
                      selected: selected,
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRecommendAntiFatigueEnabledTile(
      BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(recommendAntiFatigueEnabledProvider);
    return settingsSwitchTile(
      icon: Icons.repeat_on_outlined,
      iconColor: Colors.indigo,
      title: '避免重复推荐',
      // 同时 watch 天数 provider，使 subtitle 随天数变化实时更新
      subtitle: enabled
          ? '已开启：${ref.watch(recommendAntiFatigueDaysProvider)} 天内不重推'
          : '已关闭：所有 item 都可能被推荐',
      value: enabled,
      onChanged: (value) {
        ref
            .read(recommendAntiFatigueEnabledProvider.notifier)
            .setEnabled(value);
      },

      helpText:
          '反疲劳机制：避免同一演员/导演的内容在推荐中连续刷屏。\n\n开启后，推荐结果会限制同一创作者的视频出现密度，浏览体验更丰富。\n\n适合关注演员数量较少、内容高度集中的场景。',
    );
  }

  Widget _buildRecommendAntiFatigueDaysTile(
      BuildContext context, WidgetRef ref) {
    final days = ref.watch(recommendAntiFatigueDaysProvider);
    return settingsTapTile(
      icon: Icons.history_toggle_off,
      iconColor: Colors.deepOrange,
      title: '不重推天数',
      subtitle: '$days 天内展示过的 item 不再推荐',
      onTap: () => _showAntiFatigueDaysDialog(context, ref, days),
      helpText:
          '反疲劳窗口（天）：在多少天内对同一创作者的内容去重/限流。\n\n窗口越大，同一创作者的内容被限制的时间越长。\n\n与「反疲劳开关」配合使用，仅在开启时生效。',
    );
  }

  void _showAntiFatigueDaysDialog(
      BuildContext context, WidgetRef ref, int current) {
    // 预设值：1, 3, 7, 14, 30, 60, 90
    final options = <int>[1, 3, 7, 14, 30, 60, 90];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder：选中后立即更新选中态视觉反馈，不立即关闭对话框
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('不重推天数'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '越长 = 越不容易看到重复内容；越短 = 推荐变化越快。',
                      style: TextStyle(fontSize: _kFontSizeBody),
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
                        if (!dialogContext.mounted) return;
                        setLocalState(() => current = v);
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRecommendNextUpSeriesCountTile(
      BuildContext context, WidgetRef ref) {
    final count = ref.watch(recommendNextUpSeriesCountProvider);
    return settingsTapTile(
      icon: Icons.live_tv,
      iconColor: Colors.teal,
      title: '关注·最近剧集数',
      subtitle: '展示最近 $count 部剧的下一集',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·最近剧集数',
        current: count,
        min: 1,
        max: 10,
        label: (v) => '$v 部',
        description: '数量越多，你正在追的剧续播排得越靠前；太少会只剩演员新片。',
        apply: (v) =>
            ref.read(recommendNextUpSeriesCountProvider.notifier).setCount(v),
      ),
      helpText:
          '「关注」视频流中，每个已收藏剧集最多展示的「最近剧集」数量。\n\n用于控制关注页的剧集内容密度。\n\n· 默认 5\n· 调大 → 关注页出现更多连续剧集',
    );
  }

  Widget _buildRecommendFavActorNewCountTile(
      BuildContext context, WidgetRef ref) {
    final count = ref.watch(recommendFavActorNewCountProvider);
    return settingsTapTile(
      icon: Icons.person,
      iconColor: Colors.indigo,
      title: '关注·演员新片数',
      subtitle: '收藏演员新作品展示 $count 条',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·演员新片数',
        current: count,
        min: 5,
        max: 40,
        label: (v) => '$v 条',
        description: '控制收藏演员新作品在关注页里占多少条。',
        apply: (v) =>
            ref.read(recommendFavActorNewCountProvider.notifier).setCount(v),
      ),
      helpText:
          '「关注」视频流中，每位已收藏演员最多展示的新作品数量。\n\n· 默认 20（范围 5–40）\n· 调大 → 每位演员展示更多作品\n\n只影响关注页，不影响其他页面。',
    );
  }

  Widget _buildFollowActorVideoCountTile(BuildContext context, WidgetRef ref) {
    final count = ref.watch(followActorVideoCountProvider);
    return settingsTapTile(
      icon: Icons.person_add_alt,
      iconColor: Colors.indigo,
      title: '关注·每演员视频数',
      subtitle: '每个收藏演员展示 $count 条',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·每演员视频数',
        current: count,
        min: 1,
        max: 10,
        label: (v) => '$v 条',
        description: '关注视频流按演员逐个拉取，每个收藏演员最多显示 N 条视频。',
        apply: (v) =>
            ref.read(followActorVideoCountProvider.notifier).setCount(v),
      ),
      helpText:
          '「关注·每演员视频数」：关注视频流中每位演员最多展示的视频数量。\n\n· 范围 1–10，默认 3\n· 调小 → 关注流更紧凑、刷新更快\n· 调大 → 每位演员展示更多视频，加载更慢\n\n只在「关注」页面生效。',
    );
  }

  Widget _buildFollowOnlyUnwatchedTile(BuildContext context, WidgetRef ref) {
    final onlyUnwatched = ref.watch(followOnlyUnwatchedProvider);
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: settingsHelpButton(
        helpText:
            '开启后，「关注」视频流只显示你尚未观看过的视频。\n\n· 开启 → 已看过的视频不会出现在关注视频流，方便追新\n· 关闭 → 已看过的视频也会显示\n\n「已观看」依据 Emby 服务器记录的播放状态判断。',
        title: '关注·只看未观看',
      ),
      title: const Text('关注·只看未观看'),
      subtitle: Text(
        onlyUnwatched ? '已看过的视频不会出现在关注视频流' : '已看过的视频也会显示',
        style: TextStyle(
          fontSize: _kFontSizeSmall,
          color: scheme.onSurfaceVariant,
        ),
      ),
      value: onlyUnwatched,
      onChanged: (v) =>
          ref.read(followOnlyUnwatchedProvider.notifier).setOnlyUnwatched(v),
    );
  }

  Widget _buildFollowMaxActorsTile(BuildContext context, WidgetRef ref) {
    final maxActors = ref.watch(followMaxActorsProvider);
    return settingsTapTile(
      icon: Icons.groups,
      iconColor: Colors.teal,
      title: '关注·收藏演员上限',
      subtitle: '最多拉取 $maxActors 个收藏演员',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·收藏演员上限',
        current: maxActors,
        min: 10,
        max: 500,
        label: (v) => '$v 个',
        description: '关注页拉取收藏演员的上限。超过此数量的演员不会出现在关注页。',
        apply: (v) =>
            ref.read(followMaxActorsProvider.notifier).setMaxActors(v),
      ),
      helpText:
          '「关注·收藏演员上限」：关注视频流拉取收藏演员的最大数量。\n\n· 范围 10–500，默认 200\n· 调大 → 更多演员的作品会出现在关注页，加载更慢\n· 调小 → 只拉取最近收藏的演员，加载更快\n\n只在「关注」页面生效。',
    );
  }

  void _showCountSliderDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int current,
    required int min,
    required int max,
    required String Function(int v) label,
    required String description,
    required Future<void> Function(int v) apply,
  }) {
    var value = current.toDouble();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setLocalState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(description,
                    style: const TextStyle(fontSize: _kFontSizeBody)),
              ),
              Text(label(value.round()),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Slider(
                value: value,
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: label(value.round()),
                onChanged: (v) => setLocalState(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await apply(value.round());
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendUserRatingEnabledTile(
      BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(recommendUserRatingEnabledProvider);
    return settingsSwitchTile(
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

      helpText:
          '开启后，推荐结果额外按你的个人评分（UserRating）加权。\n\n适合你给影片打过分的场景：高分内容更容易出现在推荐中。\n\n关闭则仅按社区评分/热度推荐。',
    );
  }

  Widget _buildRecommendUserRatingMinTile(BuildContext context, WidgetRef ref) {
    final minRating = ref.watch(recommendUserRatingMinProvider);
    return settingsTapTile(
      icon: Icons.star_half,
      iconColor: Colors.deepPurple,
      title: '最低用户评分',
      subtitle: minRating == 0 ? '不过滤' : '≥ $minRating（0-10）',
      onTap: () => _showUserRatingMinDialog(context, ref, minRating),
      helpText:
          '设置个人评分参与推荐的阈值：只有你打分 ≥ 该值的内容才计入推荐加权。\n\n· 默认 4.0\n· 调高 → 只信任你的高分评价\n· 调低 → 更多打分参与推荐\n\n仅在「个人评分参与推荐」开启时生效。',
    );
  }

  void _showUserRatingMinDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 预设值：0（关闭）/ 3.0 / 4.0 / 5.0 / 6.0 / 7.0 / 8.0
    final options = <double>[0, 3, 4, 5, 6, 7, 8];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder：选中后立即更新选中态视觉反馈，不立即关闭对话框
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('最低用户评分'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '用户评分 < 阈值的 item 不再推荐（收藏项豁免）。0 = 关闭该过滤。',
                      style: TextStyle(fontSize: _kFontSizeBody),
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
                        if (!dialogContext.mounted) return;
                        setLocalState(() => current = v);
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
