// 统一错误状态卡片：图标 + 标题 + 副标题 + 操作按钮
// 用于网络错误、加载失败、服务器连接异常等场景

import 'package:flutter/material.dart';

import '../utils/colors.dart';

/// 错误状态卡片
///
/// 统一展示加载失败、网络错误等异常状态。
/// 支持自定义图标、标题、副标题和重试按钮。
class ErrorStateCard extends StatelessWidget {
  /// 错误图标，默认 [Icons.error_outline]
  final IconData icon;

  /// 主标题（错误简述）
  final String title;

  /// 副标题（错误详情或引导文案）
  final String? subtitle;

  /// 操作按钮文字（如"重试"），为 null 时不显示按钮
  final String? actionLabel;

  /// 操作按钮回调
  final VoidCallback? onAction;

  /// 图标颜色，默认 [errorColor]
  final Color? iconColor;

  const ErrorStateCard({
    super.key,
    this.icon = Icons.error_outline,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  // 网络错误快捷构造
  factory ErrorStateCard.network({VoidCallback? onRetry}) {
    return ErrorStateCard(
      icon: Icons.wifi_off,
      title: '网络不稳定',
      subtitle: '请检查网络连接后点击重试',
      actionLabel: '重试',
      onAction: onRetry,
    );
  }

  // 服务器连接错误快捷构造
  factory ErrorStateCard.server({VoidCallback? onRetry}) {
    return ErrorStateCard(
      icon: Icons.dns,
      title: '无法连接服务器',
      subtitle: '请检查服务器地址是否正确',
      actionLabel: '重试',
      onAction: onRetry,
    );
  }

  // 未登录快捷构造
  factory ErrorStateCard.notLoggedIn({VoidCallback? onLogin}) {
    return ErrorStateCard(
      icon: Icons.lock_outline,
      title: '请先登录',
      subtitle: '登录到 Emby 服务器后即可浏览内容',
      actionLabel: '去登录',
      onAction: onLogin,
      iconColor: amberColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor ?? errorColor,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(actionLabel!),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
