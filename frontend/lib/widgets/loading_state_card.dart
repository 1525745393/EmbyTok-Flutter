// 统一加载状态卡片：加载指示器 + 标题 + 副标题
// 用于数据加载中、页面初始化、异步操作等待等场景
//
// P1-4 通用状态组件提取：统一全项目的加载状态展示，
// 替代各处直接使用 CircularProgressIndicator 的重复代码。

import 'package:flutter/material.dart';

/// 加载状态卡片
///
/// 统一展示数据加载中的等待状态。
/// 支持自定义加载指示器、标题、副标题和颜色。
///
/// 用法示例：
/// ```dart
/// // 基础用法
/// LoadingStateCard(title: '加载中...')
///
/// // 带副标题
/// LoadingStateCard(
///   title: '正在加载',
///   subtitle: '正在从服务器获取数据，请稍候',
/// )
///
/// // 自定义颜色
/// LoadingStateCard(
///   title: '加载中',
///   indicatorColor: Colors.blue,
/// )
/// ```
class LoadingStateCard extends StatelessWidget {
  /// 主标题（如"加载中..."）
  final String? title;

  /// 副标题（如"正在获取数据，请稍候"）
  final String? subtitle;

  /// 加载指示器颜色，默认使用主题 primary 色
  final Color? indicatorColor;

  /// 加载指示器尺寸，默认 48
  final double indicatorSize;

  /// 加载指示器线宽，默认 4
  final double strokeWidth;

  const LoadingStateCard({
    super.key,
    this.title,
    this.subtitle,
    this.indicatorColor,
    this.indicatorSize = 48,
    this.strokeWidth = 4,
  });

  // 通用加载中快捷构造
  factory LoadingStateCard.generic() {
    return const LoadingStateCard(
      title: '加载中...',
    );
  }

  // 数据加载快捷构造
  factory LoadingStateCard.loadingData() {
    return const LoadingStateCard(
      title: '正在加载',
      subtitle: '正在从服务器获取数据，请稍候',
    );
  }

  // 登录中快捷构造
  factory LoadingStateCard.signingIn() {
    return const LoadingStateCard(
      title: '正在登录',
      subtitle: '正在验证账号信息，请稍候',
    );
  }

  // 同步中快捷构造
  factory LoadingStateCard.syncing() {
    return const LoadingStateCard(
      title: '正在同步',
      subtitle: '正在同步服务器数据，请稍候',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleText = title;
    final subtitleText = subtitle;
    return Container(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: CircularProgressIndicator(
                color: indicatorColor ?? scheme.primary,
                strokeWidth: strokeWidth,
              ),
            ),
            if (titleText != null && titleText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                titleText,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subtitleText != null && subtitleText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitleText,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
