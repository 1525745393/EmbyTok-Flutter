// 搜索页：关键词输入 + 搜索结果列表 + 搜索历史

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/video_page_item.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView>
    with AutomaticKeepAliveClientMixin<SearchView> {
  late final TextEditingController _controller;
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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
      return;
    }
    _debounce = Timer(const Duration(milliseconds: kDebounceMs), () {
      _doSearch(value);
    });
  }

  void _doSearch(String value) {
    ref.read(searchProvider.notifier).search(value);
    ref.read(searchHistoryProvider.notifier).add(value);
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
    final state = ref.watch(searchProvider);
    final history = ref.watch(searchHistoryProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: const Text('搜索'),
      ),
      body: SafeArea(
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              style: const TextStyle(color: textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: '输入关键词搜索...',
                hintStyle: const TextStyle(color: textTertiary),
                prefixIcon: const Icon(Icons.search, color: textTertiary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: textTertiary),
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0x1AFFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(state, history),
          ),
        ],
      ),
    ));
  }

  Widget _buildBody(SearchState state, List<String> history) {
    // 空查询：显示历史
    if (state.query.isEmpty) {
      return _buildHistory(history);
    }
    // 加载中
    if (state.isLoading && state.results.isEmpty) {
      return const _Centered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: primaryPink),
            SizedBox(height: 12),
            Text('搜索中...', style: TextStyle(color: textSecondary)),
          ],
        ),
      );
    }
    // 错误
    if (state.error != null && state.results.isEmpty) {
      return _Centered(
        child: ErrorStateCard(
          title: state.error!,
          actionLabel: '重试',
          onAction: () {
            ref.read(searchProvider.notifier).search(state.query);
          },
        ),
      );
    }
    // 空结果
    if (state.results.isEmpty) {
      return const _Centered(
        child: EmptyStateCard.noSearchResults(),
      );
    }
    // 正常结果列表
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const Divider(color: dividerColor, height: 1),
      itemBuilder: (context, index) {
        final item = state.results[index];
        return _SearchResultTile(item: item);
      },
    );
  }

  Widget _buildHistory(List<String> history) {
    if (history.isEmpty) {
      return const _Centered(
        child: EmptyStateCard.noSearchHistory(),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('搜索历史', style: TextStyle(color: textSecondary, fontSize: 14)),
              TextButton(
                onPressed: _clearHistory,
                child: Text('清空', style: TextStyle(color: historyPink)),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  onRemove: () =>
                      ref.read(searchHistoryProvider.notifier).remove(keyword),
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
  Widget build(BuildContext context) =>
      Center(child: child);
}

class _SearchResultTile extends ConsumerWidget {
  final MediaItem item;
  const _SearchResultTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取认证状态以构造带认证的图片 URL
    final authState = ref.watch(authProvider);
    final thumbnailUrl = item.thumbnailUrlWithAuth(
      authState.embyServerUrl,
      authState.token,
    );
    final headers = item.authHeaders(authState.token);

    return ListTile(
      onTap: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => _VideoPlayPage(item: item)),
        );
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                width: 120,
                height: 72,
                fit: BoxFit.cover,
                httpHeaders: headers.isNotEmpty ? headers : null,
                memCacheWidth: 240,
                placeholder: (_, __) => _thumbPlaceholder(),
                errorWidget: (_, __, ___) => _thumbPlaceholder(),
              )
            : _thumbPlaceholder(),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: primaryPink,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.type,
              style: const TextStyle(color: textPrimary, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDuration(item.durationSeconds),
            style: const TextStyle(color: textTertiary, fontSize: 12),
          ),
        ],
      ),
      ),
      trailing: const Icon(Icons.play_circle_fill, color: historyPink, size: 28),
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 120,
        height: 72,
        color: Colors.grey[800],
        child: const Icon(Icons.movie_outlined, color: textPlaceholder),
      );
}

class _HistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _HistoryChip({required this.label, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: progressBackground),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 14, color: textTertiary),
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
  const _ConfirmDialog({required this.title, required this.message, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(title, style: const TextStyle(color: textPrimary)),
      content: Text(message, style: const TextStyle(color: textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: textSecondary)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: primaryPink),
          child: const Text('确定', style: TextStyle(color: textPrimary)),
        ),
      ],
    );
  }
}

// 简化版播放页：跳转结果点击后播放（全屏视频页
class _VideoPlayPage extends StatelessWidget {
  final MediaItem item;
  const _VideoPlayPage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        title: Text(item.title, style: const TextStyle(color: textPrimary, fontSize: 16)),
      ),
      body: VideoPageItem(item: item),
    );
  }
}
