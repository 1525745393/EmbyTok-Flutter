/// 视频评论半屏弹层（本地评论 + TMDB 评论）
///
/// - 按 itemId 读取/写入本地评论（videoCommentsProvider，SharedPreferences 持久化）
/// - 支持新增、删除；Emby 服务器不提供评论 API，仅本机可见，UI 明示
/// - 若 itemId 为本地刮削视频（local_ 前缀），同时拉取 TMDB 评论展示
/// - 适配刘海屏 / 底部安全区 / 键盘弹出
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_comments_provider.dart';
import '../../providers/local_video_provider.dart';
import '../../services/tmdb_service.dart';

/// 打开视频评论弹层
/// [title]/[year]/[isTv] 用于在线 Emby 视频按标题搜索 TMDB 获取评论
Future<void> showVideoCommentsSheet(
  BuildContext context,
  String itemId, {
  String? title,
  int? year,
  bool isTv = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _VideoCommentsSheet(
      itemId: itemId,
      title: title,
      year: year,
      isTv: isTv,
    ),
  );
}

class _VideoCommentsSheet extends ConsumerStatefulWidget {
  const _VideoCommentsSheet({
    required this.itemId,
    this.title,
    this.year,
    this.isTv = false,
  });

  final String itemId;
  final String? title;
  final int? year;
  final bool isTv;

  @override
  ConsumerState<_VideoCommentsSheet> createState() =>
      _VideoCommentsSheetState();
}

class _VideoCommentsSheetState extends ConsumerState<_VideoCommentsSheet> {
  final TextEditingController _inputController = TextEditingController();
  bool _submitting = false;
  late final Future<List<Map<String, dynamic>>> _tmdbFuture = _fetchTmdbReviews();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await ref
        .read(videoCommentsProvider.notifier)
        .addComment(widget.itemId, text);
    if (mounted) {
      setState(() => _submitting = false);
      _inputController.clear();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTmdbReviews() async {
    // 本地视频：直接用 scraped tmdbId
    final pathHash = widget.itemId.startsWith('local_') ? widget.itemId.substring(6) : null;
    if (pathHash != null) {
      final scraped = ref.read(localVideoProvider).scrapedMap[pathHash];
      if (scraped != null && scraped.tmdbId > 0) {
        return scraped.type == 'tv'
            ? TmdbService.getTvReviews(scraped.tvId ?? scraped.tmdbId)
            : TmdbService.getMovieReviews(scraped.tmdbId);
      }
      return [];
    }
    // 在线 Emby：按标题搜索 TMDB
    if (widget.title == null || widget.title!.isEmpty) return [];
    try {
      if (widget.isTv) {
        var results = await TmdbService.searchTv(widget.title!, year: widget.year);
        // 年份不匹配时回退无年份搜索
        if (results.isEmpty && widget.year != null) {
          results = await TmdbService.searchTv(widget.title!);
        }
        if (results.isEmpty) return [];
        return TmdbService.getTvReviews(results.first['id'] as int);
      } else {
        var results = await TmdbService.searchMovies(widget.title!);
        // 优先选年份匹配的结果
        if (widget.year != null && results.length > 1) {
          final matched = results.where((r) => r['release_date']?.toString().startsWith('${widget.year}') == true).toList();
          if (matched.isNotEmpty) results = matched;
        }
        if (results.isEmpty) return [];
        return TmdbService.getMovieReviews(results.first['id'] as int);
      }
    } catch (_) {
      return [];
    }
  }

  Widget _buildList(ColorScheme scheme, ScrollController scrollController, List<VideoComment> localComments) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tmdbFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tmdbReviews = snap.data ?? [];
        final children = <Widget>[];
        if (tmdbReviews.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('TMDB 评论', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          ));
          children.addAll(tmdbReviews.take(10).map((r) => _TmdbReviewTile(review: r)));
          children.add(const Divider(height: 24));
        }
        if (localComments.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('我的评论', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          ));
          children.addAll(localComments.map((c) => _CommentTile(comment: c)));
        }
        if (children.isEmpty) return _EmptyComments(scheme: scheme);
        return ListView(controller: scrollController, padding: const EdgeInsets.symmetric(vertical: 8), children: children);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final comments = ref.watch(
      videoCommentsProvider.select((s) => s[widget.itemId] ?? const []),
    );
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 标题行
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    '评论',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (comments.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${comments.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 列表
            Expanded(
              child: _buildList(scheme, scrollController, comments),
            ),
            // 输入区（键盘弹出时跟随上移）
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: keyboardInset > 0
                    ? keyboardInset
                    : MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLength: 500,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '说点什么…（仅本机保存）',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submitting ? null : _submit,
                    icon: Icon(
                      Icons.send,
                      size: 20,
                      color: _inputController.text.trim().isEmpty
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '还没有评论，来说两句吧',
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '评论仅保存在本机（Emby 服务器暂不支持评论同步）',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TmdbReviewTile extends StatelessWidget {
  const _TmdbReviewTile({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = review['author'] ?? '';
    final content = (review['content'] ?? '').toString().replaceAll(RegExp(r'\s+'), ' ');
    final rating = review['author_details']?['rating'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Text(author.isNotEmpty ? author[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(author, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                  if (rating != null) ...[
                    const SizedBox(width: 8),
                    Text('★$rating', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(content, style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final VideoComment comment;

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.month}月${t.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer(
      builder: (context, ref, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.person,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(comment.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '删除评论',
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () => ref
                  .read(videoCommentsProvider.notifier)
                  .removeComment(comment.itemId, comment.id),
            ),
          ],
        );
      },
    );
  }
}
