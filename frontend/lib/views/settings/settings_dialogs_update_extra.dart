// 从 settings_dialogs_update.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== 检查更新 ====================

extension _SettingsDialogs4 on SettingsView {
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
}
