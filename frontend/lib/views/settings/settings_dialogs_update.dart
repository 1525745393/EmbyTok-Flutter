// 从 settings_dialogs_ext.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== 设置对话框（更新/关于） ====================

extension _SettingsDialogs3 on SettingsView {
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
