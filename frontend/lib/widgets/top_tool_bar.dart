// 顶部工具栏：菜单按钮 + 模式标签 + 视图切换/全屏/静音按钮

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType, OrientationMode;

// 侧边菜单控制器回调
typedef MenuButtonCallback = void Function();

// 全屏模式切换回调
typedef FullscreenCallback = void Function(bool isFullscreen);

// 顶部工具栏组件
class TopToolBar extends ConsumerWidget {
  final MenuButtonCallback? onMenuPressed;
  final FullscreenCallback? onFullscreenPressed;

  const TopToolBar({
    super.key,
    this.onMenuPressed,
    this.onFullscreenPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听视图模式
    final viewMode = ref.watch(viewModeProvider);
    // 监听当前模式（最新/随机/收藏）
    final feedType = ref.watch(feedTypeProvider);
    // 监听静音状态
    final isMuted = ref.watch(isMutedProvider);
    // 监听方向过滤模式
    final orientationMode = ref.watch(orientationModeProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.black87,
        border: Border(
          bottom: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 左侧：菜单按钮
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: onMenuPressed ?? () => _openDrawer(context),
              tooltip: '菜单',
            ),
            // 中间：当前模式标签
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE91E63).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    feedType.zhLabel, // 使用 FeedType 的中文标签
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            // 右侧按钮组
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 方向过滤按钮
                PopupMenuButton<OrientationMode>(
                  icon: Icon(
                    _getOrientationIcon(orientationMode),
                    color: orientationMode != OrientationMode.both
                        ? const Color(0xFFE91E63)
                        : Colors.white,
                  ),
                  tooltip: '方向过滤',
                  color: Colors.grey[900],
                  onSelected: (mode) => _setOrientationMode(ref, mode),
                  itemBuilder: (context) => [
                    _buildOrientationMenuItem(
                      OrientationMode.vertical,
                      '只看竖屏',
                      Icons.stay_current_portrait,
                      orientationMode,
                    ),
                    _buildOrientationMenuItem(
                      OrientationMode.horizontal,
                      '只看横屏',
                      Icons.stay_current_landscape,
                      orientationMode,
                    ),
                    _buildOrientationMenuItem(
                      OrientationMode.both,
                      '全部',
                      Icons.all_inclusive,
                      orientationMode,
                    ),
                  ],
                ),
                // 视图切换按钮：feed 模式显示网格图标，grid 模式显示手机图标
                IconButton(
                  icon: Icon(
                    viewMode == ViewMode.feed
                        ? Icons.grid_view  // 视频流模式 -> 切换到网格
                        : Icons.phone_android, // 网格模式 -> 切换到视频流
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleViewMode(ref, viewMode),
                  tooltip: viewMode == ViewMode.feed ? '切换到网格视图' : '切换到视频流',
                ),
                // 全屏按钮
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  onPressed: () => onFullscreenPressed?.call(true),
                  tooltip: '全屏',
                ),
                // 静音按钮
                IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleMuted(ref, isMuted),
                  tooltip: isMuted ? '取消静音' : '静音',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 打开侧边菜单
  void _openDrawer(BuildContext context) {
    Scaffold.of(context).openDrawer();
  }

  // 切换视图模式
  void _toggleViewMode(WidgetRef ref, ViewMode current) {
    final newMode = current == ViewMode.feed ? ViewMode.grid : ViewMode.feed;
    ref.read(viewModeProvider.notifier).setMode(newMode);
  }

  // 切换静音状态
  void _toggleMuted(WidgetRef ref, bool current) {
    ref.read(isMutedProvider.notifier).setMuted(!current);
  }

  // 获取方向过滤图标
  IconData _getOrientationIcon(OrientationMode mode) {
    return switch (mode) {
      OrientationMode.vertical => Icons.stay_current_portrait,
      OrientationMode.horizontal => Icons.stay_current_landscape,
      OrientationMode.both => Icons.filter_list,
    };
  }

  // 构建方向过滤菜单项
  PopupMenuItem<OrientationMode> _buildOrientationMenuItem(
    OrientationMode mode,
    String label,
    IconData icon,
    OrientationMode currentMode,
  ) {
    final isSelected = mode == currentMode;
    return PopupMenuItem<OrientationMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFE91E63) : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFE91E63) : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, color: Color(0xFFE91E63), size: 18),
          ],
        ],
      ),
    );
  }

  // 设置方向过滤模式
  void _setOrientationMode(WidgetRef ref, OrientationMode mode) {
    ref.read(orientationModeProvider.notifier).setMode(mode);
  }
}
