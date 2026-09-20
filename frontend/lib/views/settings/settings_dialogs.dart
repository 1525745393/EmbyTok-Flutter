// 从 settings_view.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== _SettingsDialogs ====================

extension _SettingsDialogs on SettingsView {
  List<_SettingEntry> _buildSearchIndex(BuildContext context, WidgetRef ref) {
    return <_SettingEntry>[
      // 媒体库
      _SettingEntry(
        title: '视频流使用',
        section: '视频库',
        keywords: '视频流 媒体库 feed library',
        onTap: (ctx) => LibrarySelector.show(ctx, scope: LibraryScope.feed),
      ),
      _SettingEntry(
        title: '排除已观看',
        section: '视频库',
        keywords: '视频流 排除 已观看 played',
        onTap: (ctx) {
          final value = ref.read(feedExcludePlayedProvider);
          ref.read(feedExcludePlayedProvider.notifier).setExclude(!value);
        },
      ),
      _SettingEntry(
        title: '推荐使用',
        section: '视频库',
        keywords: '推荐 媒体库 recommend library',
        onTap: (ctx) =>
            LibrarySelector.show(ctx, scope: LibraryScope.recommend),
      ),
      // 推荐
      _SettingEntry(
        title: '评分阈值',
        section: '推荐',
        keywords: '推荐 评分 阈值 rating',
        onTap: (ctx) => _showRecommendRatingDialog(
            ctx, ref, ref.read(recommendMinRatingProvider)),
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
        onTap: (ctx) => _showRecommendRuntimeDialog(
            ctx, ref, ref.read(recommendMinRuntimeSecProvider)),
      ),
      _SettingEntry(
        title: '推荐类型',
        section: '推荐',
        keywords: '推荐 类型 movie episode video musicvideo series',
        onTap: (ctx) => _showRecommendTypesDialog(
            ctx, ref, ref.read(recommendIncludeTypesProvider)),
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
        onTap: (ctx) => _showHalfLifeDaysDialog(
            ctx, ref, ref.read(recommendHalfLifeDaysProvider)),
      ),
      _SettingEntry(
        title: '避免重复推荐',
        section: '推荐',
        keywords: '推荐 反疲劳 重复 anti fatigue',
        onTap: (ctx) {
          final value = ref.read(recommendAntiFatigueEnabledProvider);
          ref
              .read(recommendAntiFatigueEnabledProvider.notifier)
              .setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '不重推天数',
        section: '推荐',
        keywords: '推荐 反疲劳 天数 days',
        onTap: (ctx) => _showAntiFatigueDaysDialog(
            ctx, ref, ref.read(recommendAntiFatigueDaysProvider)),
      ),
      _SettingEntry(
        title: '用户评分加权',
        section: '推荐',
        keywords: '推荐 用户评分 加权 rating',
        onTap: (ctx) {
          final value = ref.read(recommendUserRatingEnabledProvider);
          ref
              .read(recommendUserRatingEnabledProvider.notifier)
              .setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '最低用户评分',
        section: '推荐',
        keywords: '推荐 最低 用户评分 min rating',
        onTap: (ctx) => _showUserRatingMinDialog(
            ctx, ref, ref.read(recommendUserRatingMinProvider)),
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
        title: '焦点恢复自动续播',
        section: '播放',
        keywords: '播放 焦点 来电 恢复 续播 resume interruption',
        onTap: (ctx) {
          final value = ref.read(autoResumeAfterInterruptionProvider);
          ref.read(autoResumeAfterInterruptionProvider.notifier).set(!value);
        },
      ),
      _SettingEntry(
        title: '全屏禁用手势返回',
        section: '播放',
        keywords: '播放 手势 全屏 返回 边缘 gesture back swipe',
        onTap: (ctx) {
          final value = ref.read(fullscreenGestureBackExcludedProvider);
          ref.read(fullscreenGestureBackExcludedProvider.notifier).set(!value);
        },
      ),
      _SettingEntry(
        title: '默认播放倍速',
        section: '播放',
        keywords: '播放 倍速 rate speed',
        onTap: (ctx) => _showPlaybackRateDialog(
            ctx, ref, ref.read(defaultPlaybackRateProvider)),
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
        onTap: (ctx) => _showSubtitleDialog(
            ctx, ref, ref.read(defaultSubtitleLanguageProvider)),
      ),
      _SettingEntry(
        title: '字幕大小',
        section: '字幕',
        keywords: '字幕 大小 size small medium large',
        onTap: (ctx) =>
            _showSubtitleSizeDialog(ctx, ref, ref.read(subtitleSizeProvider)),
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
        onTap: (ctx) =>
            _showOrientationDialog(ctx, ref, ref.read(orientationModeProvider)),
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
      _SettingEntry(
        title: '导出日志',
        section: '存储',
        keywords: '存储 日志 导出 log export 排查',
        onTap: (ctx) => _exportLogs(ctx),
      ),
      _SettingEntry(
        title: '清除日志',
        section: '存储',
        keywords: '存储 日志 清除 删除 log clear',
        onTap: (ctx) => _showClearLogsDialog(ctx),
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
      _SettingEntry(
        title: '意见反馈',
        section: '关于',
        keywords: '意见反馈 反馈 邮件 建议 bug 报告',
        onTap: (ctx) => _buildFeedbackTile(ctx, ref),
      ),
    ];
  }

  void _showSettingsSearch(BuildContext context, WidgetRef ref) {
    final isMusicMode = ref.read(serviceModeProvider) == AppServiceMode.music;
    // 音乐模式：过滤视频相关设置项（视频库/推荐/播放/字幕/统计/视频方向）
    const videoSections = {'视频库', '推荐', '播放', '字幕', '统计'};
    final entries = _buildSearchIndex(context, ref)
        .where((e) =>
            !isMusicMode ||
            (!videoSections.contains(e.section) && e.title != '视频方向'))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _SettingsSearchSheet(entries: entries),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: _kDialogSelectTheme,
        options: const [
          ('跟随系统', 'system'),
          ('深色', 'dark'),
          ('浅色', 'light'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(themeModeProvider.notifier).setTheme(v);
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('手势控制', style: TextStyle(color: scheme.onSurface)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GestureItem(
              icon: Icons.touch_app,
              title: '单击',
              description: '显示/隐藏控制栏',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.double_arrow,
              title: '双击左右侧',
              description: '快退 / 快进 10 秒',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.favorite,
              title: '双击中间',
              description: '点赞（加入收藏）',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.fast_forward,
              title: '长按',
              description: '2x 倍速播放，松开恢复',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.swipe_up,
              title: '上下滑动（左半屏）',
              description: '调节屏幕亮度',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.volume_up,
              title: '上下滑动（右半屏）',
              description: '调节音量',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.swipe,
              title: '左右滑动',
              description: '拖动进度条定位',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('清除缓存', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '确定要清除全部缓存吗？这将删除临时下载的缩略图和字幕文件。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(cacheSizeProvider.notifier).clear();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('缓存已清除'),
                    backgroundColor: scheme.primary,
                  ),
                );
              } catch (e) {
                AppLogger.error('清除缓存失败', error: e);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('清除失败：$e'),
                    backgroundColor: scheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('清除', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('重置设置', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '将所有偏好设置恢复为默认值，包括：播放、字幕、外观、推荐、媒体库等。\n\n'
          '不影响：登录信息、观看历史、搜索历史、收藏。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await const AppPreferencesService().resetAllSettings();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('设置已重置并立即生效'),
                    backgroundColor: scheme.primary,
                    duration: const Duration(seconds: 4),
                  ),
                );
              } catch (e) {
                AppLogger.error('重置设置失败', error: e);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('重置失败：$e'),
                    backgroundColor: scheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('重置', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }
}
