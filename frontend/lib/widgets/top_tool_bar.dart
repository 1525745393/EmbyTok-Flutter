// 顶部工具栏：菜单按钮 + 模式标签 + 视图切换/全屏/静音按钮

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/app_preferences.dart' show ViewMode, OrientationMode, FeedType;

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
    // 获取主题色彩方案
    final scheme = Theme.of(context).colorScheme;
    // 监听视图模式
    final viewMode = ref.watch(viewModeProvider);
    // 监听当前选中的媒体库
    final selectedLibrary = ref.watch(selectedLibraryProvider);
    // 监听可见媒体库列表
    final visibleLibraries = ref.watch(visibleLibraryListProvider);
    // 监听静音状态
    final isMuted = ref.watch(isMutedProvider);
    // 监听方向过滤模式
    final orientationMode = ref.watch(orientationModeProvider);
    // 监听当前浏览模式
    final feedType = ref.watch(feedTypeProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 左侧：菜单按钮 + 推荐按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.menu, color: scheme.onSurface),
                  onPressed: onMenuPressed ?? () => _openDrawer(context),
                  tooltip: '菜单',
                ),
                // 推荐按钮：切换到推荐浏览模式
                IconButton(
                  icon: Icon(
                    Icons.auto_awesome,
                    color: feedType == FeedType.recommend
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                  onPressed: () => _toggleRecommendMode(ref, feedType),
                  tooltip: '推荐',
                ),
              ],
            ),
            // 中间：当前媒体库名称（点击切换）
            Expanded(
              child: Center(
                child: PopupMenuButton<String>(
                  color: scheme.surface.withOpacity(0.95),
                  onSelected: (libraryId) =>
                      _selectLibrary(ref, libraryId),
                  itemBuilder: (context) {
                    if (visibleLibraries.isEmpty) {
                      return [
                        PopupMenuItem<String>(
                          enabled: false,
                          value: '',
                          child: Text(
                            '暂无可用媒体库',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ];
                    }
                    return visibleLibraries
                        .map((lib) => PopupMenuItem<String>(
                              value: lib.id,
                              child: Row(
                                children: [
                                  Icon(
                                    selectedLibrary?.id == lib.id
                                        ? Icons.check_circle
                                        : Icons.folder_outlined,
                                    color: selectedLibrary?.id == lib.id
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      lib.name,
                                      style: TextStyle(
                                        color: selectedLibrary?.id == lib.id
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                        fontWeight: selectedLibrary?.id == lib.id
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 16,
                          color: scheme.onSurface.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedLibrary?.name ?? '加载中...',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                      ],
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
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                  tooltip: '方向过滤',
                  color: scheme.surface.withOpacity(0.95),
                  onSelected: (mode) => _setOrientationMode(ref, mode),
                  itemBuilder: (context) => [
                    _buildOrientationMenuItem(
                      OrientationMode.vertical,
                      '只看竖屏',
                      Icons.stay_current_portrait,
                      orientationMode,
                      scheme,
                    ),
                    _buildOrientationMenuItem(
                      OrientationMode.horizontal,
                      '只看横屏',
                      Icons.stay_current_landscape,
                      orientationMode,
                      scheme,
                    ),
                    _buildOrientationMenuItem(
                      OrientationMode.both,
                      '全部',
                      Icons.all_inclusive,
                      orientationMode,
                      scheme,
                    ),
                  ],
                ),
                // 视图切换按钮：feed 模式显示网格图标，grid 模式显示手机图标
                IconButton(
                  icon: Icon(
                    viewMode == ViewMode.feed
                        ? Icons.grid_view // 视频流模式 -> 切换到网格
                        : Icons
                            .phone_android, // 网格模式 -> 切换到视频流
                    color: scheme.onSurface,
                  ),
                  onPressed: () => _toggleViewMode(ref, viewMode),
                  tooltip: viewMode == ViewMode.feed
                      ? '切换到网格视图'
                      : '切换到视频流',
                ),
                // 全屏按钮
                IconButton(
                  icon: Icon(Icons.fullscreen, color: scheme.onSurface),
                  onPressed: () => onFullscreenPressed?.call(true),
                  tooltip: '全屏',
                ),
                // 静音按钮
                IconButton(
                  icon: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: scheme.onSurface,
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
    ColorScheme scheme,
  ) {
    final isSelected = mode == currentMode;
    return PopupMenuItem<OrientationMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, color: scheme.primary, size: 18),
          ],
        ],
      ),
    );
  }

  // 设置方向过滤模式
  void _setOrientationMode(WidgetRef ref, OrientationMode mode) {
    ref.read(orientationModeProvider.notifier).setMode(mode);
  }

  // 切换当前媒体库（单选快捷操作，选中一个库时清空其他）
  void _selectLibrary(WidgetRef ref, String libraryId) {
    if (libraryId.isEmpty) return;
    ref.read(selectedLibraryIdsProvider.notifier).setLibrary(libraryId);
  }

  // 切换推荐模式：如果当前是推荐模式则切回最新，否则切到推荐
  void _toggleRecommendMode(WidgetRef ref, FeedType current) {
    final newType = current == FeedType.recommend
        ? FeedType.latest
        : FeedType.recommend;
    ref.read(feedTypeProvider.notifier).setType(newType);
  }
}
