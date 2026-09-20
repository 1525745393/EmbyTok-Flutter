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
