// 本地视频列表页：网格/列表切换 + 搜索 + 排序 + 多选删除 + 权限引导
// 对应 PRD《本地模式》§4.3 / §6
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/local_video_item.dart';
import '../../providers/local_video_provider.dart';
import '../../services/local_video_service.dart';
import 'local_player_page.dart';

class LocalVideoView extends ConsumerStatefulWidget {
  const LocalVideoView({super.key});

  @override
  ConsumerState<LocalVideoView> createState() => _LocalVideoViewState();
}

class _LocalVideoViewState extends ConsumerState<LocalVideoView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    final notifier = ref.read(localVideoProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    // 权限引导
    if (!state.permission.hasAccess) {
      return _PermissionGuide(
        permission: state.permission,
        onRequest: () => notifier.requestPermissionAndScan(),
      );
    }

    final items = state.filtered;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 顶部搜索 + 排序 + 视图切换
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '搜索本地视频…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                    onChanged: notifier.setKeyword,
                  ),
                ),
                const SizedBox(width: 8),
                // 排序菜单
                PopupMenuButton<LocalVideoSort>(
                  icon: const Icon(Icons.sort, size: 20),
                  tooltip: '排序',
                  onSelected: notifier.setSort,
                  itemBuilder: (_) => [
                    for (final s in LocalVideoSort.values)
                      PopupMenuItem(value: s, child: Text(_sortLabel(s))),
                  ],
                ),
                // 网格/列表切换
                IconButton(
                  icon: Icon(
                    state.viewMode == LocalVideoViewMode.grid
                        ? Icons.view_list
                        : Icons.grid_view,
                    size: 20,
                  ),
                  onPressed: notifier.toggleViewMode,
                ),
                // 文件夹分组切换（P2）
                IconButton(
                  icon: Icon(
                    state.groupByFolder
                        ? Icons.folder_special
                        : Icons.folder_outlined,
                    size: 20,
                    color: state.groupByFolder ? scheme.primary : null,
                  ),
                  tooltip: state.groupByFolder ? '退出文件夹分组' : '按文件夹分组',
                  onPressed: notifier.toggleGroupByFolder,
                ),
              ],
            ),
          ),
          // 多选模式顶栏
          if (state.selecting)
            Container(
              color: scheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: notifier.exitSelecting,
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  Text('已选 ${state.selected.length} 项',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      // 删除确认对话框（P1：避免误删）
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('删除视频'),
                          content: Text(
                              '确定删除选中的 ${state.selected.length} 个视频吗？此操作不可恢复。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: scheme.error),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !mounted) return;
                      final ok = await notifier.deleteByIds(state.selected);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已删除 $ok 个视频')),
                        );
                      }
                    },
                    child: Text('删除',
                        style: TextStyle(color: scheme.error)),
                  ),
                ],
              ),
            ),
          // 内容区
          Expanded(
            child: state.loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? _EmptyState(
                        onRefresh: notifier.refresh,
                        hasPermission: state.permission.hasAccess,
                      )
                    : Column(
                        children: [
                          // 最近观看横滑区块（P2）
                          if (state.recentItems.isNotEmpty)
                            _buildRecentRow(state.recentItems),
                          Expanded(
                            child: state.groupByFolder
                                ? _buildGrouped(state)
                                : state.viewMode == LocalVideoViewMode.grid
                                    ? _buildGrid(items, state, notifier)
                                    : _buildList(items, state, notifier),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// 最近观看横滑区块（P2）
  Widget _buildRecentRow(List<LocalVideoItem> recent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text('继续观看',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = recent[i];
              return GestureDetector(
                onTap: () => _playVideo(item),
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(item.durationLabel,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 文件夹分组列表（P2）
  Widget _buildGrouped(LocalVideoState state) {
    final grouped = state.grouped;
    return ListView(
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(entry.key,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text('${entry.value.length} 个',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: entry.value.length,
            itemBuilder: (_, i) => _GridCard(
              item: entry.value[i],
              selected: state.selected.contains(entry.value[i].id),
              selecting: state.selecting,
              onTap: () => _playVideo(entry.value[i]),
              onLongPress: () {},
            ),
          ),
        ],
      ],
    );
  }

  String _sortLabel(LocalVideoSort s) {
    switch (s) {
      case LocalVideoSort.modifiedDesc:
        return '最近修改';
      case LocalVideoSort.nameAsc:
        return '名称 A→Z';
      case LocalVideoSort.durationDesc:
        return '时长最长';
      case LocalVideoSort.sizeDesc:
        return '文件最大';
    }
  }

  Widget _buildGrid(
    List<LocalVideoItem> items,
    LocalVideoState state,
    LocalVideoNotifier notifier,
  ) {
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _GridCard(
          item: items[i],
          selected: state.selected.contains(items[i].id),
          selecting: state.selecting,
          onTap: () {
            if (state.selecting) {
              notifier.toggleSelected(items[i].id);
            } else {
              _playVideo(items[i]);
            }
          },
          onLongPress: () => notifier.enterSelecting(),
        ),
      ),
    );
  }

  Widget _buildList(
    List<LocalVideoItem> items,
    LocalVideoState state,
    LocalVideoNotifier notifier,
  ) {
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _ListTileItem(
          item: items[i],
          selected: state.selected.contains(items[i].id),
          selecting: state.selecting,
          onTap: () {
            if (state.selecting) {
              notifier.toggleSelected(items[i].id);
            } else {
              _playVideo(items[i]);
            }
          },
          onLongPress: () => notifier.enterSelecting(),
        ),
      ),
    );
  }

  void _playVideo(LocalVideoItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalPlayerPage(item: item),
      ),
    );
  }
}

/// 权限引导页
class _PermissionGuide extends StatelessWidget {
  final PermissionState permission;
  final VoidCallback onRequest;
  const _PermissionGuide({required this.permission, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final denied = permission == PermissionState.denied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              denied ? '需要存储权限才能读取本地视频' : '首次使用请授权访问媒体库',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? '已被拒绝，请在系统设置中开启「媒体/存储」权限后重试'
                  : '授权后将扫描手机中的视频文件',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: denied
                  ? LocalVideoService.openSetting
                  : onRequest,
              child: Text(denied ? '去设置开启' : '授权并扫描'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool hasPermission;
  const _EmptyState({required this.onRefresh, required this.hasPermission});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Center(child: Text('没有找到本地视频')),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新扫描'),
          ),
        ),
      ],
    );
  }
}

/// 网格卡片：缩略图 + 时长角标 + 分辨率角标
class _GridCard extends StatefulWidget {
  final LocalVideoItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _GridCard({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    if (widget.item.assetId == null) return;
    try {
      final asset = AssetEntity(
        id: widget.item.assetId!,
        typeInt: 1, // video
        width: widget.item.width,
        height: widget.item.height,
        duration: widget.item.duration.inSeconds,
      );
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(200),
      );
      if (mounted && data != null) setState(() => _thumb = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _thumb != null
                ? Image.memory(_thumb!, fit: BoxFit.cover)
                : Container(
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.movie, size: 32),
                  ),
          ),
          // 时长角标右下
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.item.durationLabel,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          // 分辨率角标左下
          if (widget.item.width > 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.item.resolutionLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ),
            ),
          // 多选勾选
          if (widget.selecting)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                widget.selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: widget.selected ? scheme.primary : Colors.white,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }
}

class _ListTileItem extends StatelessWidget {
  final LocalVideoItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ListTileItem({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 64,
          height: 40,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.movie, size: 20),
          ),
        ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.durationLabel} · ${item.sizeLabel}'
        '${item.relativePath != null ? ' · ${item.relativePath}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: selecting
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            )
          : const Icon(Icons.chevron_right),
    );
  }
}
