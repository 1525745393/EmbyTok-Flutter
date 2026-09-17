/// 视频评论半屏弹层（本地评论 v1）
///
/// - 按 itemId 读取/写入本地评论（videoCommentsProvider，SharedPreferences 持久化）
/// - 支持新增、删除；Emby 服务器不提供评论 API，仅本机可见，UI 明示
/// - 适配刘海屏 / 底部安全区 / 键盘弹出
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/video_comments_provider.dart';

/// 打开视频评论弹层
Future<void> showVideoCommentsSheet(BuildContext context, String itemId) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _VideoCommentsSheet(itemId: itemId),
  );
}

class _VideoCommentsSheet extends ConsumerStatefulWidget {
  const _VideoCommentsSheet({required this.itemId});

  final String itemId;

  @override
  ConsumerState<_VideoCommentsSheet> createState() =>
      _VideoCommentsSheetState();
}

class _VideoCommentsSheetState extends ConsumerState<_VideoCommentsSheet> {
  final TextEditingController _inputController = TextEditingController();
  bool _submitting = false;

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
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              child: comments.isEmpty
                  ? _EmptyComments(scheme: scheme)
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _CommentTile(comment: comments[index]),
                    ),
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
