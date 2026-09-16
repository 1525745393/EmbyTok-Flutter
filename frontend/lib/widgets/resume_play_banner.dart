// 「上次看到」续播横幅（关注页/发现页共用）
//
// 显示在网格顶部：上次观看到的视频标题 + 一键继续。
// 点击后进入播放页，由 PlaybackShell 按同一数据源+列表恢复到上次位置。

import 'package:flutter/material.dart';

class ResumePlayBanner extends StatelessWidget {
  const ResumePlayBanner({
    super.key,
    required this.title,
    required this.onTap,
  });

  /// 上次观看的视频标题
  final String title;

  /// 点击续播
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '上次看到《$title》',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '点击继续',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
