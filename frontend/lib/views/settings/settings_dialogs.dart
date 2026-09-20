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

  Future<void> _exportLogs(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    try {
      final logContent = await AppLogger.exportLogs();

      if (logContent.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('暂无日志可导出'),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        );
        return;
      }

      // 写入临时文件以便系统查看器打开
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/embytok_export.log');
      await tempFile.writeAsString(logContent);

      if (!context.mounted) return;
      _showExportLogsDialog(context, logContent, tempFile.path);
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Text('导出失败', style: TextStyle(color: scheme.onSurface)),
          content: Text(
            '导出日志时出错：$e',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('确定', style: TextStyle(color: scheme.primary)),
            ),
          ],
        ),
      );
    }
  }

  void _showExportLogsDialog(
    BuildContext context,
    String logContent,
    String filePath,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // 取最后 20 行作为预览
    final lines = logContent.split('\n');
    final previewLines =
        lines.length > 20 ? lines.sublist(lines.length - 20) : lines;
    final preview = previewLines.join('\n');
    final hasMore = lines.length > 20;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Row(
          children: [
            Text('导出日志', style: TextStyle(color: scheme.onSurface)),
            const Spacer(),
            Text(
              '共 ${logContent.length} 字符',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeSmall),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '... 省略前 ${lines.length - 20} 行',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: _kFontSizeSmall),
                  ),
                ),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    preview,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: _kFontSizeTiny,
                      color: scheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: logContent));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('日志内容已复制到剪贴板'),
                  backgroundColor: scheme.primary,
                ),
              );
            },
            child: const Text('复制内容'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await OpenFilex.open(filePath, type: 'text/plain');
              if (result.type != ResultType.done && dialogContext.mounted) {
                // 无法打开时降级为复制内容
                await Clipboard.setData(ClipboardData(text: logContent));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('无法打开文件，日志内容已复制到剪贴板'),
                    backgroundColor: scheme.primary,
                  ),
                );
              }
            },
            child: const Text('打开文件'),
          ),
        ],
      ),
    );
  }

  void _showClearLogsDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('清除日志', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '将删除本地保存的所有 WARN/ERROR 日志文件，此操作不可恢复。\n\n'
          '如有问题正在排查，建议先导出日志再清除。',
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
                await AppLogger.clearLogs();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('日志已清除'),
                    backgroundColor: scheme.primary,
                  ),
                );
              } catch (e) {
                AppLogger.error('清除日志失败', error: e);
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

  void _showWatchStatsDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => Consumer(builder: (dialogContext, ref, _) {
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
                  _buildStatRow(scheme, '最近 7 天', '${stats.last7DaysCount} 次'),
                  _buildStatRow(
                    scheme,
                    '近 7 天完播率',
                    '${(stats.last7DaysAvgCompletion * 100).toStringAsFixed(0)}%',
                  ),
                  const SizedBox(height: _kSpacingXXLarge),
                  // 最近 10 条
                  if (stats.records.isNotEmpty) ...[
                    Text(
                      '最近观看',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: _kFontSizeMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: _kSpacingMedium),
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
                                  fontSize: _kFontSizeSmall,
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
                                fontSize: _kFontSizeSmall,
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
                          fontSize: _kFontSizeBody,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text('关闭', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            if (stats.totalCount > 0)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: dialogContext,
                    builder: (confirmContext) => AlertDialog(
                      backgroundColor: scheme.surface,
                      title: Text('清除统计',
                          style: TextStyle(color: scheme.onSurface)),
                      content: Text('确定要清除所有观看统计吗？',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmContext, false),
                          child: Text('取消',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(confirmContext, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.error),
                          child: Text('清除',
                              style: TextStyle(color: scheme.onError)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(watchStatsProvider.notifier).clear();
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    } catch (e) {
                      AppLogger.error('清除统计失败', error: e);
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
                  }
                },
                child: Text('清除统计', style: TextStyle(color: scheme.error)),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildStatRow(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeBody)),
          Text(value,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: _kFontSizeLarge,
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('退出登录', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '确定要退出当前账号吗？',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              // 按服务模式退出对应服务：音乐模式退群晖，视频模式退 Emby
              if (ref.read(serviceModeProvider) == AppServiceMode.music) {
                ref.read(synologyAuthProvider.notifier).logout();
              } else {
                ref.read(authProvider.notifier).logout();
              }
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('退出', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;

    // 1. 等待版本信息加载完成：避免 appVersionProvider 未 resolve 时
    //    用 '0.0.0' 参与比较，导致"已最新却提示有新版本"
    String currentVersion;
    try {
      currentVersion = await ref.read(appVersionProvider.future);
    } catch (_) {
      currentVersion = '0.0.0';
    }
    if (!context.mounted) return;
    // 去掉 buildNumber，只保留 x.y.z
    var currentVer = currentVersion;
    final plusIdx = currentVer.indexOf('+');
    if (plusIdx > 0) currentVer = currentVer.substring(0, plusIdx);

    // 2. 显示加载对话框（PopScope 禁止返回键关闭，避免误关设置页）
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Text('正在检查更新…',
                  style: TextStyle(
                      color: scheme.onSurface, fontSize: _kFontSizeLarge)),
            ],
          ),
        ),
      ),
    );

    // 3. 调用 GitHub API 检查（包裹 try-catch，网络异常时关闭加载框并提示用户）
    final updateService = ref.read(updateCheckServiceProvider);
    try {
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
          onSecondaryAction: () =>
              _launchUrl(updateService.releasePageUrl, context),
        );
      } else if (result.hasUpdate) {
        // 有新版本
        final release = result.latestRelease!;
        // 查找 APK 下载链接
        final apkAssets = release.assets.where((a) => a.isApk).toList();
        final hasApk = apkAssets.isNotEmpty;
        // 网络失败回退缓存时提示来源，避免用户误以为版本没变化
        final cacheHint = result.fromCache ? '\n\n（网络不可用，以上为上次检查结果）' : '';
        _showUpdateResultDialog(
          context,
          icon: Icons.system_update,
          title: '发现新版本',
          message: '当前版本：$currentVer\n最新版本：${release.version}\n\n'
              '${release.body.isNotEmpty ? release.body : release.name}'
              '$cacheHint',
          actionText: hasApk ? '下载安装' : '前往下载',
          onAction: () {
            if (hasApk) {
              _startDownloadApk(context, ref, apkAssets.first, release);
            } else {
              _launchUrl(release.htmlUrl, context);
            }
          },
          secondaryActionText: '稍后再说',
          onSecondaryAction: null,
        );
      } else {
        // 已是最新版本（fromCache 时标题区分，避免误读为实时结论）
        _showUpdateResultDialog(
          context,
          icon: result.fromCache ? Icons.history : Icons.check_circle,
          title: result.fromCache ? '上次检查：已是最新' : '已是最新版本',
          message: '当前版本：$currentVer\n'
              '${result.fromCache ? '（网络不可用，以上为上次检查结果）' : '您使用的是最新版本。'}',
          actionText: '关闭',
          onAction: null,
          secondaryActionText: null,
          onSecondaryAction: null,
        );
      }
    } catch (e) {
      // 异常处理：关闭加载对话框，显示错误提示
      AppLogger.error('检查更新失败', error: e);
      if (context.mounted) Navigator.pop(context);
      if (!context.mounted) return;

      // 根据错误类型显示不同提示
      String errorTitle;
      String errorMessage;
      if (e is UpdateRateLimitException) {
        errorTitle = '请求过于频繁';
        errorMessage = 'GitHub API 请求次数已达上限，请稍后再试。';
      } else {
        errorTitle = '检查失败';
        errorMessage = '检查更新时出错：$e';
      }

      _showUpdateResultDialog(
        context,
        icon: Icons.error_outline,
        title: errorTitle,
        message: errorMessage,
        actionText: '关闭',
        onAction: null,
        secondaryActionText: '前往 GitHub',
        onSecondaryAction: () =>
            _launchUrl(updateService.releasePageUrl, context),
      );
    }
  }

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
    // 跟踪对话框是否仍在显示，防止对话框关闭后还继续处理下载结果
    bool isDialogActive = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // 启动下载：延迟到第一帧后执行，避免在 builder 中直接调用异步操作
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isDialogActive) return;
          updateService.downloadApk(
            apkAsset,
            version: release.version,
            onProgress: (p) {
              if (!isDialogActive) return;
              progressNotifier.value = p;
              statusNotifier.value =
                  '${(p * 100).toStringAsFixed(0)}%  ·  ${formatBytes(apkAsset.size)}';
            },
            cancelToken: cancelToken,
            // Release 正文附带 SHA256 时强制校验，防止镜像源篡改
            expectedSha256: release.sha256Digest,
          ).then((savePath) {
            if (ctx.mounted && isDialogActive) {
              isDialogActive = false;
              Navigator.pop(ctx);
              _showInstallDialog(ctx, savePath, release, scheme);
            }
          }).catchError((Object e) {
            if (e is DioException && CancelToken.isCancel(e)) return;
            if (ctx.mounted && isDialogActive) {
              isDialogActive = false;
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
                      fontSize: _kFontSizeXLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _kSpacingXXXLarge),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) {
                  return LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  );
                },
              ),
              const SizedBox(height: _kSpacingLarge),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) {
                  return Text(
                    status,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: _kFontSizeSmall,
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

  void _showDownloadError(
      BuildContext context, String error, String fallbackUrl) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: _kSpacingXXLarge),
            const Text(
              '下载失败',
              style: TextStyle(
                fontSize: _kFontSizeXXLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kSpacingXLarge),
            Text(
              error,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: _kFontSizeBody,
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
              _launchUrl(fallbackUrl, context);
            },
            child: const Text('浏览器下载'),
          ),
        ],
      ),
    );
  }

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
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: _kSpacingXXLarge),
            const Text(
              '下载完成',
              style: TextStyle(
                fontSize: _kFontSizeXXLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kSpacingMedium),
            Text(
              '版本 ${release.version} 已下载完成，是否立即安装？',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: _kFontSizeBody,
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
              _installApk(context, apkPath);
            },
            child: const Text('立即安装'),
          ),
        ],
      ),
    );
  }

  Future<void> _installApk(BuildContext context, String apkPath) async {
    final scheme = Theme.of(context).colorScheme;
    try {
      final file = File(apkPath);
      if (!await file.exists()) {
        AppLogger.error('安装失败：文件不存在', data: {'path': apkPath});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('安装失败：安装文件不存在'),
            backgroundColor: scheme.error,
          ),
        );
        return;
      }
      final result = await OpenFilex.open(apkPath,
          type: 'application/vnd.android.package-archive');
      AppLogger.debug('APK 安装结果',
          data: {'type': result.type.name, 'message': result.message});
      // 打开失败（非 done）时提示用户
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开安装器：${result.message}'),
            backgroundColor: scheme.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('安装 APK 失败', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('安装失败：$e'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

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
            const SizedBox(height: _kSpacingXXLarge),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: _kFontSizeXXLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kSpacingXLarge),
            Text(
              message,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: _kFontSizeMedium,
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

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('打开链接失败', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接，请检查系统浏览器')),
        );
      }
    }
  }

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
                  color: DonateColors.donateAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism,
                    color: DonateColors.donateAccent, size: 32),
              ),
              const SizedBox(height: _kSpacingXLarge),
              Text(
                '打赏支持',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: _kFontSizeXXLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: _kSpacingSmall),
              Text(
                '如果这个应用对你有帮助，\n可以请作者喝杯咖啡 ☕',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeBody,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _kSpacingXXLarge),
              // 收款码区域：用 errorBuilder 处理图片缺失
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_wechat.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _DonatePlaceholder(
                    icon: Icons.chat_outlined,
                    label: '微信收款码',
                    hint: '尚未提供，敬请期待',
                    color: DonateColors.wechat,
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingXLarge),
              // 支付宝收款码
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_alipay.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _DonatePlaceholder(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '支付宝收款码',
                    hint: '尚未提供，敬请期待',
                    color: DonateColors.alipay,
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingXXLarge),
              // 外部打赏链接（如爱发电等）
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl(
                    'https://github.com/1525745393/EmbyTok-Flutter', context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '前往 GitHub 仓库',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: _kFontSizeBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingMedium),
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
    final copyrightYear =
        currentYear > startYear ? '$startYear-$currentYear' : '$startYear';

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
                child: Icon(Icons.play_circle_filled,
                    color: scheme.onPrimary, size: 44),
              ),
              const SizedBox(height: _kSpacingXLarge),
              // 应用名
              Text(
                'EmbyTok',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: _kFontSizeXXXLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: _kSpacingXSmall),
              // 版本号
              Text(
                '版本 $version',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeBody,
                ),
              ),
              const SizedBox(height: _kSpacingXXXLarge),
              // 应用介绍
              Text(
                'EmbyTok 是一款面向 Emby 媒体服务器与群晖 Audio Station 的媒体客户端，提供类似 TikTok 的上下滑动刷片体验，同时支持音乐库浏览与播放，让你以更现代、便捷的方式享受个人媒体库。',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: _kSpacingXXLarge),
              // 功能亮点
              const _AboutFeatureRow(
                icon: Icons.swipe_vertical,
                text: '上下滑动，沉浸式刷片体验',
              ),
              const SizedBox(height: _kSpacingLarge),
              const _AboutFeatureRow(
                icon: Icons.favorite_border,
                text: '收藏管理，快速访问心仪内容',
              ),
              const SizedBox(height: _kSpacingLarge),
              const _AboutFeatureRow(
                icon: Icons.library_music_outlined,
                text: '支持 Emby 视频与群晖 Audio Station 音乐',
              ),
              const SizedBox(height: _kSpacingXXXLarge),
              const Divider(height: 1),
              const SizedBox(height: _kSpacingXLarge),
              // GitHub 仓库入口：点击跳转到项目仓库
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl(
                    'https://github.com/1525745393/EmbyTok-Flutter', context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
                            fontSize: _kFontSizeBody,
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
              const SizedBox(height: _kSpacingXLarge),
              // 版权
              Text(
                '© $copyrightYear EmbyTok  contributors',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeSmall,
                ),
              ),
              const SizedBox(height: _kSpacingXSmall),
              Text(
                '本软件基于开源协议发布',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: _kFontSizeSmall,
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
}
