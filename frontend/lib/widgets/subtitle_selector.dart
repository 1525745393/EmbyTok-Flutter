// 字幕选择器：底部弹出菜单，显示可用字幕列表，支持选择和关闭字幕

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';

/// 字幕选择器回调
typedef SubtitleSelectedCallback = void Function(SubtitleTrack? track);

/// 字幕选择器底部弹出菜单
class SubtitleSelector extends ConsumerWidget {
  /// 可用的字幕轨道列表
  final List<SubtitleTrack> tracks;

  /// 当前选中的字幕轨道 ID
  final String? selectedTrackId;

  /// 字幕选择回调
  final SubtitleSelectedCallback? onSelected;

  /// 关闭回调
  final VoidCallback? onClose;

  const SubtitleSelector({
    super.key,
    required this.tracks,
    this.selectedTrackId,
    this.onSelected,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 读取本地外挂字幕轨道列表
    final localTracks = ref.watch(localSubtitleTracksProvider);
    // 合并服务器字幕和本地字幕
    final allTracks = [...tracks, ...localTracks];
    final hasAnySubtitle = allTracks.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '字幕选择',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: Icon(Icons.close, color: scheme.onSurfaceVariant.withOpacity(0.7)),
                      onPressed: onClose,
                    ),
                ],
              ),
            ),

            Divider(color: scheme.outlineVariant, height: 1),

            // 字幕列表
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // 关闭字幕选项
                  _buildOption(
                    context: context,
                    ref: ref,
                    title: '关闭字幕',
                    subtitle: '不显示字幕',
                    isSelected: selectedTrackId == null,
                    onTap: () {
                      ref.read(subtitleSettingsProvider.notifier).setLanguage('');
                      onSelected?.call(null);
                      onClose?.call();
                    },
                  ),

                  // 导入本地字幕按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(color: scheme.outlineVariant, height: 1),
                  ),
                  _buildImportLocalButton(context, ref, scheme),

                  // 服务器字幕分组
                  if (tracks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Text(
                        '服务器字幕 (${tracks.length})',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...tracks.map((track) => _buildTrackOption(
                      context: context,
                      ref: ref,
                      track: track,
                      isSelected: selectedTrackId == track.id,
                      onTap: () {
                        // 保存偏好语言（语言代码，用于跨视频自动匹配）
                        ref.read(subtitleSettingsProvider.notifier).setLanguage(track.language);
                        onSelected?.call(track);
                        onClose?.call();
                      },
                    )),
                  ],

                  // 本地字幕分组
                  if (localTracks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            '本地字幕 (${localTracks.length})',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...localTracks.map((track) => _buildTrackOption(
                      context: context,
                      ref: ref,
                      track: track,
                      isLocal: true,
                      isSelected: selectedTrackId == track.id,
                      onTap: () {
                        onSelected?.call(track);
                        onClose?.call();
                      },
                      onDelete: () {
                        ref.read(localSubtitleTracksProvider.notifier).remove(track.id);
                        // 如果删除的是当前选中的字幕，关闭字幕
                        if (selectedTrackId == track.id) {
                          ref.read(selectedSubtitleProvider.notifier).state = null;
                        }
                      },
                    )),
                  ],

                  // 无字幕提示
                  if (!hasAnySubtitle)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.subtitles_off,
                            size: 48,
                            color: scheme.onSurface.withOpacity(0.12),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '当前视频没有可用字幕',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '可点击上方按钮导入本地字幕文件',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 构建导入本地字幕按钮
  Widget _buildImportLocalButton(BuildContext context, WidgetRef ref, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
            dialogTitle: '选择本地字幕文件',
          );
          if (result == null || result.files.single.path == null) return;

          final path = result.files.single.path!;
          final name = path.split(Platform.pathSeparator).last;
          final format = name.contains('.')
              ? name.split('.').last.toLowerCase()
              : 'srt';

          final track = SubtitleTrack(
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            language: 'local',
            format: format,
            localFilePath: path,
          );

          // 添加到本地字幕轨道列表
          ref.read(localSubtitleTracksProvider.notifier).add(track);
          // 自动选中刚导入的字幕
          onSelected?.call(track);
          onClose?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add, color: scheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '导入本地字幕',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '支持 SRT / VTT / ASS / SSA 格式',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 选中指示器
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.onSurface.withOpacity(0.12),
                  width: 2,
                ),
                color: isSelected ? scheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: scheme.onPrimary, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            // 文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackOption({
    required BuildContext context,
    required WidgetRef ref,
    required SubtitleTrack track,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLocal = false,
    VoidCallback? onDelete,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 选中指示器
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.onSurface.withOpacity(0.12),
                  width: 2,
                ),
                color: isSelected ? scheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: scheme.onPrimary, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            // 字幕图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withOpacity(0.12)
                    : isLocal
                        ? scheme.tertiary.withOpacity(0.1)
                        : scheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLocal ? Icons.folder_open : Icons.subtitles,
                color: isSelected
                    ? scheme.primary
                    : isLocal
                        ? scheme.tertiary
                        : scheme.onSurfaceVariant.withOpacity(0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // 文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayName,
                    style: TextStyle(
                      color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLocal
                        ? '本地字幕 · ${track.format.toUpperCase()}'
                        : _getLanguageLabel(track.language),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 删除按钮（仅本地字幕）
            if (isLocal && onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error.withOpacity(0.7), size: 20),
                onPressed: onDelete,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            // 默认标记（服务器字幕）
            if (!isLocal && track.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '默认',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getLanguageLabel(String code) {
    // 常见语言代码映射
    const languageMap = {
      'chi': '中文',
      'zh': '中文',
      'zho': '中文',
      'eng': '英文',
      'en': '英文',
      'jpn': '日文',
      'ja': '日文',
      'kor': '韩文',
      'ko': '韩文',
      'fre': '法文',
      'fra': '法文',
      'fr': '法文',
      'ger': '德文',
      'deu': '德文',
      'de': '德文',
      'spa': '西班牙文',
      'es': '西班牙文',
      'por': '葡萄牙文',
      'pt': '葡萄牙文',
      'rus': '俄文',
      'ru': '俄文',
    };
    return languageMap[code.toLowerCase()] ?? code.toUpperCase();
  }
}

/// 显示字幕选择器底部弹窗
Future<void> showSubtitleSelector({
  required BuildContext context,
  required List<SubtitleTrack> tracks,
  String? selectedTrackId,
  SubtitleSelectedCallback? onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SubtitleSelector(
      tracks: tracks,
      selectedTrackId: selectedTrackId,
      onSelected: onSelected,
    ),
  );
}
