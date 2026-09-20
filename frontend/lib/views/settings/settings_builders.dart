// 从 settings_view.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== _SettingsBuilders ====================

extension _SettingsBuilders on SettingsView {
  Widget _buildAutoPlayTile(BuildContext context, WidgetRef ref) {
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    return settingsSwitchTile(
      icon: Icons.play_circle_outline,
      iconColor: Colors.green,
      title: _kTitleAutoPlay,
      subtitle: _kSubtitleAutoPlay,
      value: isAutoPlay,
      onChanged: (value) {
        ref.read(isAutoPlayProvider.notifier).setEnabled(value);
      },
      helpText:
          '开启后，视频播放完成会自动播放下一个推荐视频。\n\n· 开启 → 连续播放，适合刷视频场景\n· 关闭 → 播完停止，返回视频信息页\n\n在视频流的「自动连播」体验与手动浏览之间切换。',
    );
  }

  Widget _buildAutoResumeAfterInterruptionTile(
      BuildContext context, WidgetRef ref) {
    final autoResume = ref.watch(autoResumeAfterInterruptionProvider);
    return settingsSwitchTile(
      icon: Icons.phone_in_talk_outlined,
      iconColor: Colors.green,
      title: '焦点恢复自动续播',
      subtitle: '来电结束后自动恢复播放',
      value: autoResume,
      onChanged: (value) {
        ref.read(autoResumeAfterInterruptionProvider.notifier).set(value);
      },
      helpText:
          '开启后，播放因来电、通知、切后台等中断时，回到 App 会自动恢复到中断位置继续播放。\n\n关闭则中断后回到视频开头。\n\n与「播放位置记忆」配合使用，中断恢复更流畅。',
    );
  }

  Widget _buildFullscreenGestureBackTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(fullscreenGestureBackExcludedProvider);
    return settingsSwitchTile(
      icon: Icons.swipe_outlined,
      iconColor: Colors.indigo,
      title: '全屏禁用手势返回',
      subtitle: '全屏时禁用系统边缘返回手势，避免拖进度误退全屏',
      value: exclude,
      onChanged: (value) {
        ref.read(fullscreenGestureBackExcludedProvider.notifier).set(value);
      },
      helpText:
          '全屏播放时，允许通过手势（如右滑/下滑）返回上一页。\n\n· 开启 → 手势返回更顺手\n· 关闭 → 只能用系统返回键退出全屏\n\n避免误触退出全屏时建议关闭。',
    );
  }

  Widget _buildPlaybackRateTile(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(defaultPlaybackRateProvider);
    return settingsTapTile(
      icon: Icons.speed_outlined,
      iconColor: Colors.orange,
      title: _kTitlePlaybackRate,
      subtitle: '${rate.toStringAsFixed(1)}x',
      onTap: () => _showPlaybackRateDialog(context, ref, rate),
      helpText: '设置视频默认播放倍速。\n\n支持 0.5x–2.0x。播放器播放时会使用该倍速，播放中也可临时调整。',
    );
  }

  Widget _buildGestureControlTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.touch_app_outlined,
      iconColor: Colors.purple,
      title: _kTitleGestureControl,
      subtitle: _kSubtitleGestureControl,
      onTap: () => _showGestureControlDialog(context),
      helpText:
          '设置视频播放页的手势控制方式。\n\n支持：单击暂停/播放、双击快进快退、左右滑动调节进度、上下滑动调节亮度/音量等。\n\n可在此开关或调整各项手势灵敏度。',
    );
  }

  Widget _buildSubtitleLanguageTile(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(defaultSubtitleLanguageProvider);
    return settingsTapTile(
      icon: Icons.closed_caption_outlined,
      iconColor: Colors.teal,
      title: '默认字幕语言',
      subtitle: lang.isEmpty ? '关闭' : _getLanguageName(lang),
      onTap: () => _showSubtitleDialog(context, ref, lang),
      helpText:
          '选择默认字幕语言。\n\n当视频含多语言字幕时，优先加载该语言字幕。\n\n· 跟随系统 → 使用设备语言\n· 指定语言 → 始终加载指定字幕\n\n如果服务器没有该语言字幕则回退到默认字幕。',
    );
  }

  Widget _buildSubtitleSizeTile(BuildContext context, WidgetRef ref) {
    final size = ref.watch(subtitleSizeProvider);
    return settingsTapTile(
      icon: Icons.format_size_outlined,
      iconColor: Colors.teal,
      title: '字幕大小',
      subtitle: _subtitleSizeLabel(size),
      onTap: () => _showSubtitleSizeDialog(context, ref, size),
      helpText: '调节字幕显示大小。\n\n· 偏小 → 画面更干净\n· 偏大 → 字幕更清晰\n\n实时预览，无需重启。',
    );
  }

  Widget _buildThemeTile(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return settingsTapTile(
      icon: Icons.dark_mode_outlined,
      iconColor: Colors.indigo,
      title: _kTitleTheme,
      subtitle: _themeLabel(themeMode),
      onTap: () => _showThemeDialog(context, ref, themeMode),
      helpText:
          '选择 App 主题：跟随系统 / 浅色 / 深色。\n\n· 跟随系统 → 随设备深色模式自动切换\n· 深色 → 夜间观看更舒适\n\n设置后立即生效。',
    );
  }

  Widget _buildOrientationTile(BuildContext context, WidgetRef ref) {
    final orientationMode = ref.watch(orientationModeProvider);
    return settingsTapTile(
      icon: Icons.screen_rotation_outlined,
      iconColor: Colors.indigo,
      title: '视频方向',
      subtitle: orientationMode.zhLabel,
      onTap: () => _showOrientationDialog(context, ref, orientationMode),
      helpText:
          '设置视频播放时的屏幕方向。\n\n· 跟随系统 → 横竖屏自由旋转\n· 横屏 → 播放强制横屏（适合大屏观影）\n· 竖屏 → 保持竖屏浏览',
    );
  }

  Widget _buildCacheTile(BuildContext context, WidgetRef ref) {
    final cacheSize = ref.watch(cacheSizeProvider);
    return settingsTapTile(
      icon: Icons.cleaning_services_outlined,
      iconColor: Colors.grey,
      title: '清除缓存',
      subtitle: formatBytes(cacheSize),
      onTap: () => _showClearCacheDialog(context, ref),
      helpText:
          '管理图片/视频封面缓存。\n\n· 查看当前缓存占用\n· 一键清理缓存释放存储空间\n\n封面缓存用于加速列表加载；清理后需重新下载，但不会丢失任何数据。',
    );
  }

  Widget _buildArtistMetadataCacheTile(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: ref.read(artistMetadataServiceProvider).getCacheSize(),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        return settingsTapTile(
          icon: Icons.person_outline,
          iconColor: Colors.purple,
          title: '歌手元数据缓存',
          subtitle: '简介/头像缓存 ${formatBytes(size)}，点击清除',
          onTap: () => _showClearArtistMetadataDialog(context, ref),
          helpText:
              '管理艺术家/歌手元数据缓存（头像、简介等）。\n\n· 查看缓存条目数\n· 清理缓存后，歌手详情将从数据源重新拉取\n\n适用于音乐服务模式。',
        );
      },
    );
  }

  Widget _buildBatchScanTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.auto_fix_high,
      iconColor: Colors.teal,
      title: _kTitleBatchScan,
      subtitle: '扫描音乐库中所有歌手，批量获取缺失的头像和简介',
      onTap: () => _startBatchScan(context, ref),
      helpText:
          '批量扫描设置：控制启动/刷新时是否全量扫描服务器内容。\n\n· 开启 → 启动后自动拉取最新媒体库（耗流量、加载慢）\n· 关闭 → 只加载本地缓存（加载快、内容可能滞后）\n\n建议在内容更新频繁时开启，日常使用可关闭。',
    );
  }

  Future<void> _startBatchScan(BuildContext context, WidgetRef ref) async {
    // 检查是否已登录群晖
    final authState = ref.read(synologyAuthProvider);
    if (!authState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text(_kHintLoginFirst),
          duration: Duration(seconds: _kSnackBarDurationShort),
        ),
      );
      return;
    }

    // 获取音乐库中所有歌手
    try {
      final api = ref.read(synologyAuthProvider.notifier).api;
      // 分页遍历所有歌曲，只收集歌手名，不保留整首歌对象，避免大库 OOM
      final artistSet = <String>{};
      int offset = 0;
      const int limit = 200;
      while (true) {
        final batch = await api.getSongs(offset: offset, limit: limit);
        if (batch.isEmpty) break;
        for (final s in batch) {
          final name = s.artistDisplay;
          if (name.isNotEmpty) artistSet.add(name);
        }
        if (batch.length < limit) break;
        offset += limit;
      }
      final artistNames = artistSet.toList();

      if (!context.mounted) return; // 修复：异步后检查 context.mounted
      if (artistNames.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text(_kHintNoArtists),
            duration: Duration(seconds: _kSnackBarDurationShort),
          ),
        );
        return;
      }

      // 显示批量扫描对话框
      if (context.mounted) {
        final result = await showDialog<BatchScanResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ArtistBatchScanDialog(
            artistNames: artistNames,
          ),
        );

        if (result != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描完成：${result.summary}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return; // 修复：异步后检查 context.mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取歌手列表失败：${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showClearArtistMetadataDialog(
      BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除歌手元数据缓存'),
        content: const Text('确定要清除所有歌手简介和头像缓存吗？清除后下次访问歌手时将重新从网络获取。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(artistMetadataServiceProvider).clearAllCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('歌手元数据缓存已清除'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildResetSettingsTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.restore,
      iconColor: Colors.deepOrange,
      title: '重置设置',
      subtitle: '恢复所有偏好为默认值（不影响登录/历史/收藏）',
      onTap: () => _showResetSettingsDialog(context, ref),
      helpText:
          '将所有设置恢复为默认值。\n\n不影响：登录的服务器、观看历史、收藏数据。\n\n仅重置本页可见的偏好项，操作不可撤销，建议先确认当前配置。',
    );
  }

  Widget _buildExportLogsTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.file_download_outlined,
      iconColor: Colors.blueGrey,
      title: '导出日志',
      subtitle: '导出最近 500 条 WARN/ERROR 日志用于排查',
      onTap: () => _exportLogs(context),
      helpText:
          '将最近 500 条 WARN/ERROR 日志导出为文本文件，并复制文件路径到剪贴板。\n\n用于排查崩溃、加载失败等异常，提交反馈时可附带该日志。',
    );
  }

  Widget _buildClearLogsTile(BuildContext context, WidgetRef ref) {
    return settingsTapTile(
      icon: Icons.delete_outline,
      iconColor: Colors.red,
      title: '清除日志',
      subtitle: '删除本地保存的日志文件',
      onTap: () => _showClearLogsDialog(context),
      helpText: '删除本地保存的日志文件（内存缓冲区 + 磁盘文件）。\n\n清除后无法恢复；排查问题时建议先导出再清除。',
    );
  }

  Widget _buildWatchStatsTile(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(watchStatsProvider);
    final avg = (stats.avgCompletion * 100).toStringAsFixed(0);
    return settingsTapTile(
      icon: Icons.analytics_outlined,
      iconColor: Colors.deepPurple,
      title: '观看统计',
      subtitle: stats.totalCount == 0
          ? '暂无数据'
          : '总 ${stats.totalCount} 次 · 平均完播率 $avg%',
      onTap: () => _showWatchStatsDialog(context, ref),
      helpText: '查看本机观看统计：总播放次数、平均完播率。\n\n点击可查看详情并支持清空统计。\n\n数据仅保存在本机，不会上传。',
    );
  }
}
