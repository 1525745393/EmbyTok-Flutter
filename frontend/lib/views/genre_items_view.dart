// 类型影片列表页：按 Emby Genres API 精确筛选同类型影片
// 与 Emby 服务器点击类型标签显示的结果一致

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/video/video_grid_card.dart';

class GenreItemsView extends ConsumerStatefulWidget {
  const GenreItemsView({super.key, required this.genreName});
  final String genreName;

  @override
  ConsumerState<GenreItemsView> createState() => _GenreItemsViewState();
}

class _GenreItemsViewState extends ConsumerState<GenreItemsView> {
  static const int _pageSize = 30;
  final List<MediaItem> _items = [];
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(cachedMediaRepositoryProvider);
      final result = await repo.getItemsByGenre(
        widget.genreName,
        limit: _pageSize,
        offset: _offset,
        serverUrl: auth.embyServerUrl ?? '',
        token: auth.token ?? '',
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _offset += result.items.length;
        _hasMore = result.items.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genreName),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _items.clear();
            _offset = 0;
            _hasMore = true;
          });
          await _loadMore();
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMore,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无影片'));
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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
            context.push('/play/${item.id}', extra: {
              'item': item,
              'items': _items,
              'source': 'genre',
            });
          },
        );
      },
    );
  }
}
