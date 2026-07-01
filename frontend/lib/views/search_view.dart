// 搜索页：关键词输入 + 搜索建议 + 搜索结果列表 + 搜索历史
// 支持两种模式：
//   useScaffold=true: 独立路由模式（含 Scaffold + AppBar，通过 GoRouter 路由访问）
//   useScaffold=false: 覆盖层模式（仅内容，通过 HomeScaffold Stack 渲染，Provider 管理返回）

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/video_page_item.dart';

class SearchView extends ConsumerStatefulWidget {
  final bool useScaffold;
  const SearchView({super.key, this.useScaffold = true});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView>
    with AutomaticKeepAliveClientMixin<SearchView> {
  late final TextEditingController _controller;
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();
  String? _selectedType;

  // Emby 支持的媒体类型
  static const List<Map<String, String>> _mediaTypes = [
    {'type': '', 'label': '全部'},
    {'type': 'Movie', 'label': '电影'},
    {'type': 'Series', 'label': '剧集'},
    {'type': 'Episode', 'label': '剧集'},
    {'type': 'MusicAlbum', 'label': '音乐专辑'},
    {'type': 'MusicArtist', 'label': '艺术家'},
    {'type': 'Audio', 'label': '音频'},
    {'type': 'BoxSet', 'label': '合集'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      ref.read(searchProvider.notifier).search('');
      ref.read(searchHintsStateProvider.notifier).clear();
      return;
    }
    // 300ms 防抖后执行搜索
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _doSearch(value);
    });
  }

  void _doSearch(String value) {
    ref.read(searchProvider.notifier).search(value);
    ref.read(searchHistoryProvider.notifier).add(value);
    ref.read(searchHintsStateProvider.notifier).clear();
  }

  void _selectHint(SearchHint hint) {
    _controller.text = hint.name;
    _doSearch(hint.name);
  }

  void _clearHistory() {
    showDialog<void>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: '清空搜索历史',
        message: '确定要清空全部搜索历史记录吗？',
        onConfirm: () {
          ref.read(searchHistoryProvider.notifier).clear();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(searchProvider);
    final hintsState = ref.watch(searchHintsStateProvider);
    final history = ref.watch(searchHistoryProvider);

    final content = Column(
      children: [
        if (!widget.useScaffold)
          Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            color: scheme.surface,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                  onPressed: () {
                    ref.read(pageNavigationNotifierProvider).backToFeed();
                  },
                ),
                const SizedBox(width: 4),
                Icon(Icons.search, color: scheme.primary, size: 24),
                const SizedBox(width: 8),
                Text('搜索',
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onQueryChanged,
            onSubmitted: _doSearch,
            style: TextStyle(color: scheme.onSurface, fontSize: 16),
            decoration: InputDecoration(
              hintText: '输入关键词搜索...',
              hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
              prefixIcon: Icon(Icons.search,
                  color: scheme.onSurface.withOpacity(0.6)),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: scheme.onSurface.withOpacity(0.6)),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: scheme.onSurface.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _buildBody(state, hintsState, history),
        ),
      ],
    );

    if (widget.useScaffold) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          title: const Text('搜索'),
        ),
        body: SafeArea(
          child: content,
        ),
      );
    } else {
      return Container(
        color: scheme.surface,
        child: SafeArea(
          child: content,
        ),
      );
    }
  }

  Widget _buildBody(
      SearchState state, SearchHintsState hintsState, List<String> history) {
    // 显示搜索建议（输入时显示）
    if (hintsState.query.isNotEmpty &&
        hintsState.hints.isNotEmpty &&
        state.query.isEmpty) {
      return _buildHints(hintsState);
    }
    // 空查询：显示历史和分类筛选
    if (state.query.isEmpty) {
      return _buildHistoryAndFilters(history);
    }
    // 加载中
    if (state.isLoading && state.results.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return _Centered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 12),
            Text('搜索中...',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.7))),
          ],
        ),
      );
    }
    // 错误
    final error = state.error;
    if (error != null && state.results.isEmpty) {
      return _Centered(
        child: ErrorStateCard(
          title: error,
          actionLabel: '重试',
          onAction: () {
            ref.read(searchProvider.notifier).search(state.query);
          },
        ),
      );
    }
    // 空结果
    if (state.results.isEmpty) {
      return _Centered(
        child: EmptyStateCard.noSearchResults(),
      );
    }
    // 正常结果列表
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.results.length,
      separatorBuilder: (_, __) =>
          Divider(color: scheme.onSurface.withOpacity(0.1), height: 1),
      itemBuilder: (context, index) {
        final item = state.results[index];
        return _SearchResultTile(key: Key(item.id), item: item);
      },
    );
  }

  Widget _buildHints(SearchHintsState hintsState) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: hintsState.hints.length,
      itemBuilder: (context, index) {
        final hint = hintsState.hints[index];
        return ListTile(
          onTap: () => _selectHint(hint),
          leading: const Icon(Icons.search, size: 18),
          title: Text(
            hint.name,
            style: TextStyle(color: scheme.onSurface, fontSize: 15),
          ),
          subtitle: () {
            final seriesName = hint.seriesName;
            if (seriesName != null && seriesName.isNotEmpty) {
              return Text(
                seriesName,
                style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.6), fontSize: 12),
              );
            }
            return null;
          }(),
          trailing: hint.year != null
              ? Text(
                  hint.year.toString(),
                  style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.5), fontSize: 12),
                )
              : null,
        );
      },
    );
  }

  Widget _buildHistoryAndFilters(List<String> history) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 分类筛选
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('媒体类型',
                  style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.7), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _mediaTypes
                  .map((item) {
                    final label = item['label'] ?? '';
                    final type = item['type'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(label),
                        selected: _selectedType == type,
                        onSelected: (selected) {
                          setState(() {
                            _selectedType =
                                selected ? type : null;
                          });
                        },
                        selectedColor: scheme.primary,
                        labelStyle: TextStyle(
                          color: _selectedType == type
                              ? scheme.onPrimary
                              : scheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                        backgroundColor:
                            scheme.onSurface.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          // 搜索历史
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('搜索历史',
                  style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.7), fontSize: 14)),
              if (history.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: Text('清空', style: TextStyle(color: scheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Expanded(
              child: _Centered(
                child: EmptyStateCard.noSearchHistory(),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: history
                  .map((keyword) => _HistoryChip(
                        label: keyword,
                        onTap: () {
                          _controller.text = keyword;
                          _doSearch(keyword);
                        },
                        onRemove: () => ref
                            .read(searchHistoryProvider.notifier)
                            .remove(keyword),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) => Center(child: child);
}

class _SearchResultTile extends ConsumerWidget {
  final MediaItem item;
  const _SearchResultTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
    );
    final headers = item.authHeaders(authState.token);

    return ListTile(
      onTap: () {
        context.push('/play/${item.id}', extra: item);
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                cacheManager: AppImageCacheManager.thumbnail,
                width: 120,
                height: 72,
                fit: BoxFit.cover,
                httpHeaders: headers.isNotEmpty ? headers : null,
                memCacheWidth: 240,
                placeholder: (ctx, __) => _thumbPlaceholder(ctx),
                errorWidget: (ctx, ___, __) => _thumbPlaceholder(ctx),
              )
            : _thumbPlaceholder(context),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.type,
              style: TextStyle(color: scheme.onPrimary, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDuration(item.durationSeconds),
            style: TextStyle(
                color: scheme.onSurface.withOpacity(0.6), fontSize: 12),
          ),
        ]),
      ),
      trailing: Icon(Icons.play_circle_fill, color: scheme.primary, size: 28),
    );
  }

  Widget _thumbPlaceholder(BuildContext context) => Container(
        width: 120,
        height: 72,
        color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
        child: Icon(Icons.movie_outlined,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
      );
}

class _HistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _HistoryChip(
      {required this.label, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.onSurface.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.8), fontSize: 13)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close,
                  size: 14, color: scheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  const _ConfirmDialog(
      {required this.title, required this.message, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surface,
      title: Text(title, style: TextStyle(color: scheme.onSurface)),
      content: Text(message,
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消',
              style: TextStyle(color: scheme.onSurface.withOpacity(0.7))),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: scheme.primary),
          child: Text('确定', style: TextStyle(color: scheme.onPrimary)),
        ),
      ],
    );
  }
}

class _VideoPlayPage extends StatelessWidget {
  final MediaItem item;
  const _VideoPlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Text(item.title,
            style: TextStyle(color: scheme.onSurface, fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
