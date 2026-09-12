// 歌手元数据手动修正界面（V1.2）
//
// 允许用户手动修改歌手头像和简介，覆盖自动获取的元数据。
// 修正后的数据会标记为手动修正，并优先于自动获取的数据。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/artist_metadata.dart';
import '../../providers/artist_metadata_provider.dart';
import '../../utils/logger.dart';

/// 歌手元数据编辑界面
///
/// 使用方式：
/// ```dart
/// final updated = await showModalBottomSheet<ArtistMetadata>(
///   context: context,
///   isScrollControlled: true,
///   builder: (context) => ArtistMetadataEditor(
///     artistName: '周杰伦',
///     currentMetadata: metadata,
///   ),
/// );
/// ```
class ArtistMetadataEditor extends ConsumerStatefulWidget {
  /// 歌手名称
  final String artistName;

  /// 当前元数据
  final ArtistMetadata currentMetadata;

  const ArtistMetadataEditor({
    super.key,
    required this.artistName,
    required this.currentMetadata,
  });

  @override
  ConsumerState<ArtistMetadataEditor> createState() => _ArtistMetadataEditorState();
}

class _ArtistMetadataEditorState extends ConsumerState<ArtistMetadataEditor> {
  /// 头像 URL 控制器
  late final TextEditingController _imageUrlController;

  /// 简介摘要控制器
  late final TextEditingController _bioSummaryController;

  /// 简介全文控制器
  late final TextEditingController _bioContentController;

  /// 是否正在保存
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _imageUrlController = TextEditingController(
      text: widget.currentMetadata.imageUrl ?? '',
    );
    _bioSummaryController = TextEditingController(
      text: widget.currentMetadata.bioSummary ?? '',
    );
    _bioContentController = TextEditingController(
      text: widget.currentMetadata.bioContent ?? '',
    );
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    _bioSummaryController.dispose();
    _bioContentController.dispose();
    super.dispose();
  }

  /// 保存元数据
  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final service = ref.read(artistMetadataServiceProvider);
      final updated = await service.updateArtistMetadata(
        artistName: widget.artistName,
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        bioSummary: _bioSummaryController.text.trim().isEmpty
            ? null
            : _bioSummaryController.text.trim(),
        bioContent: _bioContentController.text.trim().isEmpty
            ? null
            : _bioContentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      AppLogger.error('保存歌手元数据失败',
          data: {'artist': widget.artistName, 'error': e.toString()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// 重置元数据（清除手动修正）
  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置元数据'),
        content: const Text('确定要清除手动修正，重新从网络获取歌手信息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(artistMetadataServiceProvider);
      final reset = await service.resetArtistMetadata(widget.artistName);

      if (mounted) {
        Navigator.of(context).pop(reset);
      }
    } catch (e) {
      AppLogger.error('重置歌手元数据失败',
          data: {'artist': widget.artistName, 'error': e.toString()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置失败：${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 顶部拖拽条
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '编辑歌手信息',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.artistName,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 手动修正标记
              if (widget.currentMetadata.isManualOverride)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '当前为手动修正数据，保存将覆盖原有信息',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // 表单内容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // 头像预览
                    _buildImagePreview(scheme),
                    const SizedBox(height: 16),
                    // 头像 URL
                    _buildSectionTitle('头像 URL'),
                    TextField(
                      controller: _imageUrlController,
                      decoration: InputDecoration(
                        hintText: '输入图片 URL，留空表示不修改',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    // 简介摘要
                    _buildSectionTitle('简介摘要（列表展示用，约2-3句）'),
                    TextField(
                      controller: _bioSummaryController,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: InputDecoration(
                        hintText: '输入歌手简介摘要，留空表示不修改',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 简介全文
                    _buildSectionTitle('简介全文（详情页展示）'),
                    TextField(
                      controller: _bioContentController,
                      maxLines: 8,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        hintText: '输入歌手简介全文，支持 HTML 标签，留空表示不修改',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // 底部操作按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 重置按钮
                    if (widget.currentMetadata.isManualOverride)
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _reset,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重置'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    if (widget.currentMetadata.isManualOverride)
                      const SizedBox(width: 12),
                    // 保存按钮
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? '保存中...' : '保存'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建分区标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  /// 构建头像预览
  Widget _buildImagePreview(ColorScheme scheme) {
    final imageUrl = _imageUrlController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('头像预览'),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.85),
                  scheme.primary.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => _initialFallback(scheme),
                  )
                : _initialFallback(scheme),
          ),
        ),
      ],
    );
  }

  /// 首字母兜底
  Widget _initialFallback(ColorScheme scheme) {
    final initial = widget.artistName.trim().isEmpty
        ? '?'
        : widget.artistName.trim().substring(0, 1).toUpperCase();
    return Container(
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
