import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

/// 媒体库选择器：底部弹窗，支持搜索和过滤
class LibrarySelector extends ConsumerStatefulWidget {
  const LibrarySelector({super.key});

  /// 显示媒体库选择器底部弹窗
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const LibrarySelector(),
    );
  }

  @override
  ConsumerState<LibrarySelector> createState() => _LibrarySelectorState();
}

class _LibrarySelectorState extends ConsumerState<LibrarySelector> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final librariesAsync = ref.watch(libraryListProvider);
    final selectedId = ref.watch(selectedLibraryIdProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
          ),
          // 标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.video_library, color: Color(0xFFE91E63), size: 20),
                SizedBox(width: 8),
                Text('选择媒体库', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索媒体库...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          // 媒体库列表
          librariesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFFE91E63)),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(32),
              child: Text('加载失败', style: TextStyle(color: Colors.white54)),
            ),
            data: (libraries) {
              final filtered = _searchQuery.isEmpty
                  ? libraries
                  : libraries.where((lib) => lib.name.toLowerCase().contains(_searchQuery)).toList();
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('无匹配结果', style: TextStyle(color: Colors.white54)),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final lib = filtered[index];
                    final isSelected = lib.id == selectedId;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? const Color(0xFFE91E63) : Colors.white38,
                      ),
                      title: Text(lib.name, style: TextStyle(
                        color: isSelected ? const Color(0xFFE91E63) : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      )),
                      onTap: () {
                        ref.read(selectedLibraryIdProvider.notifier).state = lib.id;
                        ref.read(videoListProvider.notifier).refresh(libraryId: lib.id);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
