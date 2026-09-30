// 媒体库 Tab 容器：在线 Emby / 本地视频 双入口切换
// 对应 PRD《本地模式》§4.1：顶部 SegmentedButton，不新增独立路由
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'libraries_browse_view.dart';
import 'local/local_video_view.dart';

/// 媒体库 Tab 模式（在线 Emby / 本地视频）
final librariesModeProvider =
    StateProvider<LibrariesTabMode>((_) => LibrariesTabMode.online);

enum LibrariesTabMode { online, local }

class LibrariesTabView extends ConsumerWidget {
  const LibrariesTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(librariesModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 顶部胶囊切换：在线媒体库 / 本地视频
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 4,
          ),
          child: SegmentedButton<LibrariesTabMode>(
            segments: const [
              ButtonSegment(
                value: LibrariesTabMode.online,
                icon: Icon(Icons.cloud_outlined, size: 18),
                label: Text('在线媒体库'),
              ),
              ButtonSegment(
                value: LibrariesTabMode.local,
                icon: Icon(Icons.sd_storage_outlined, size: 18),
                label: Text('本地视频'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) {
              ref.read(librariesModeProvider.notifier).state = s.first;
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return scheme.primaryContainer;
                }
                return Colors.transparent;
              }),
            ),
          ),
        ),
        // 内容区
        Expanded(
          child: mode == LibrariesTabMode.online
              ? const LibrariesBrowseView()
              : const LocalVideoView(),
        ),
      ],
    );
  }
}
