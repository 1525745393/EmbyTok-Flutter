// TV 模式根组件：用于大屏电视/遥控器操作的界面（Task 1 占位）
// 在 Task 10（TV 模式）中将扩展为完整电视界面：
//  - 横向滚动的「继续观看」行
//  - 各媒体库的分类内容行
//  - 遥控器方向键 + OK 键选择
//  - 视频流/网格视图切换

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feed_view.dart';

class TVRootView extends ConsumerWidget {
  const TVRootView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 目前占位：直接复用 FeedView，后续将用 TV 专用界面替换
    // TV 模式下 FeedView 行为与标准模式一致，Task 10 再增强。
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.tv, color: scheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'EmbyTok（TV 模式）',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '后续将替换为电视专用首页',
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
                  ),
                ],
              ),
            ),
            const Expanded(child: FeedView()),
          ],
        ),
      ),
    );
  }
}
