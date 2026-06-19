// 统一空状态卡片：图标 + 标题 + 副标题
// 用于空列表、无收藏、无历史、无搜索结果等场景

import 'package:flutter/material.dart';

import '../utils/colors.dart';

/// 空状态卡片
///
/// 统一展示无内容的友好提示。
/// 支持自定义图标、标题、副标题。
class EmptyStateCard extends StatelessWidget {
  /// 空状态图标
  final IconData icon;

  /// 主标题
  final String title;

  /// 副标题（引导文案）
  final String? subtitle;

  /// 图标颜色，默认 [textPlaceholder]
  final Color? iconColor;

  const EmptyStateCard({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  // 无收藏快捷构造
  factory EmptyStateCard.noFavorites() {
    return const EmptyStateCard(
      icon: Icons.favorite_border,
      title: '还没有收藏',
      subtitle: '双击视频即可收藏',
    );
  }

  // 无观看历史快捷构造
  factory EmptyStateCard.noHistory() {
    return const EmptyStateCard(
      icon: Icons.movie_outlined,
      title: '暂无观看历史',
      subtitle: '开始观看后将自动记录',
    );
  }

  // 无搜索结果快捷构造
  factory EmptyStateCard.noSearchResults() {
    return const EmptyStateCard(
      icon: Icons.search_off,
      title: '没有找到相关内容',
      subtitle: '试试其他关键词',
    );
  }

  // 无视频内容快捷构造
  factory EmptyStateCard.noVideos() {
    return const EmptyStateCard(
      icon: Icons.video_library_outlined,
      title: '暂无视频',
      subtitle: '请选择其他媒体库',
    );
  }

  // 无搜索历史快捷构造
  factory EmptyStateCard.noSearchHistory() {
    return const EmptyStateCard(
      icon: Icons.history,
      title: '还没有搜索历史',
      subtitle: '搜索后将自动记录',
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
              color: iconColor ?? textPlaceholder,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: textSecondary,
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
                  color: textTertiary,
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
