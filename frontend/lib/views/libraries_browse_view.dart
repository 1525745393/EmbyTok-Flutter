// 媒体库浏览页面：
// 1. 媒体库卡片网格（2列）
// 2. 点击卡片后在当前页面内进入该库影片列表（不跳转 feed 视频流）
// 3. 有返回按钮回到媒体库列表
// 4. 点击影片设置临时筛选并跳转 feed 播放

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/library_provider.dart';
import '../providers/providers.dart';
import '../widgets/video/video_grid_card.dart';

class LibrariesBrowseView extends ConsumerStatefulWidget {
  const LibrariesBrowseView({super.key});

  @override
  ConsumerState<LibrariesBrowseView> createState() =>
      _LibrariesBrowseViewState();
}

class _LibrariesBrowseViewState extends ConsumerState<LibrariesBrowseView> {
  Library? _selectedLibrary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: _selectedLibrary == null
          ? _buildLibraryGrid(context)
          : _buildLibraryContent(context, _selectedLibrary!),
    );
  }

  // ==================== 媒体库卡片网格 ====================

  Widget _buildLibraryGrid(BuildContext context) {
    final visibleLibraries = ref.watch(visibleLibraryListProvider);
    final librariesAsync = ref.watch(libraryListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '资源库',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: librariesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (_) {
              if (visibleLibraries.isEmpty) {
                return const Center(child: Text('暂无媒体库'));
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: visibleLibraries.length,
                itemBuilder: (context, index) {
                  final lib = visibleLibraries[index];
                  return _LibraryCard(
                    library: lib,
                    onTap: () => setState(() => _selectedLibrary = lib),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== 单个媒体库内容浏览 ====================

  Widget _buildLibraryContent(BuildContext context, Library library) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedLibrary = null),
              ),
              Expanded(
                child: Text(
                  library.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _LibraryItemsList(library: library)),
      ],
    );
  }
}

/// 单个媒体库的影片网格列表
class _LibraryItemsList extends ConsumerStatefulWidget {
  const _LibraryItemsList({required this.library});
  final Library library;

  @override
  ConsumerState<_LibraryItemsList> createState() => _LibraryItemsListState();
}

class _LibraryItemsListState extends ConsumerState<_LibraryItemsList> {
  List<MediaItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int _startIndex = 0;
  static const int _limit = 50;
  bool _hasMore = true;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadItems(loadMore: true);
    }
  }

  Future<void> _loadItems({bool loadMore = false}) async {
    if (_isLoading && loadMore) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.embyServerUrl == null || auth.token == null) {
      setState(() {
        _error = '未登录';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _error = null;
        _startIndex = 0;
        _hasMore = true;
      }
    });

    try {
      final service = ref.read(embytokServiceProvider);
      final newItems = await service.getChildren(
        widget.library.id,
        limit: _limit,
        offset: _startIndex,
        serverUrl: auth.embyServerUrl,
        token: auth.token,
      );

      setState(() {
        if (loadMore) {
          _items.addAll(newItems);
        } else {
          _items = newItems;
        }
        _startIndex += newItems.length;
        _hasMore = newItems.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _loadItems(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('此媒体库暂无内容'));
    }

    return RefreshIndicator(
      onRefresh: () => _loadItems(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = _items[index];
          return VideoGridCard(
            item: item,
            onTap: () {
              // 点击影片：先进入影片详情页（显示标题、简介、演职人员等）
              context.push('/item/${item.id}', extra: item);
            },
          );
        },
      ),
    );
  }
}

/// 媒体库卡片
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library, required this.onTap});
  final Library library;
  final VoidCallback onTap;

  IconData get _icon {
    final type = library.type;
    if (type.contains('movie')) return Icons.movie_outlined;
    if (type.contains('tv')) return Icons.tv_outlined;
    if (type.contains('music')) return Icons.library_music_outlined;
    return Icons.video_library_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, size: 40, color: scheme.primary),
              const Spacer(),
              Text(
                library.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (library.itemCount != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${library.itemCount} 项',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
