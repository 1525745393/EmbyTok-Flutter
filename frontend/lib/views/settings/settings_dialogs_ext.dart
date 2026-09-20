// 从 settings 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== 设置对话框（下半） ====================

extension _SettingsDialogs2 on SettingsView {
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
}
