// 音轨选择器：底部弹出菜单，显示可用音轨列表，对接 Emby MediaStreams

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../models/media_source.dart';

/// 音轨选择器底部弹出菜单
class AudioTrackSelector extends ConsumerWidget {
  const AudioTrackSelector({
    super.key,
    required this.tracks,
    required this.selectedIndex,
    this.onSelected,
    this.onClose,
  });

  /// 可用音轨列表（来自 Emby MediaStreams, type=Audio）
  final List<MediaStream> tracks;

  /// 当前选中的音轨 index（null 表示默认音轨）
  final int? selectedIndex;

  /// 选择回调
  final void Function(int? index)? onSelected;

  /// 关闭回调
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.95),
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
                color: scheme.onSurface.withValues(alpha: 0.12),
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
                    '音轨选择',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      icon: Icon(Icons.close,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
            Divider(color: scheme.outlineVariant, height: 1),
            // 音轨列表
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: tracks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.audiotrack,
                              size: 48,
                              color: scheme.onSurface.withValues(alpha: 0.12)),
                          const SizedBox(height: 12),
                          Text(
                            '当前视频没有多音轨',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // 默认音轨选项
                        _buildTrackOption(
                          context: context,
                          scheme: scheme,
                          title: '默认音轨',
                          subtitle: '使用服务器默认音轨',
                          isSelected: selectedIndex == null,
                          isDefault: true,
                          onTap: () {
                            ref.read(selectedAudioStreamIndexProvider.notifier).state = null;
                            onSelected?.call(null);
                            onClose?.call();
                          },
                        ),
                        const Divider(height: 1),
                        ...tracks.map((track) {
                          final isSelected = selectedIndex == track.index;
                          return _buildTrackOption(
                            context: context,
                            scheme: scheme,
                            title: track.displayTitle ??
                                '音轨 ${track.index + 1}',
                            subtitle: _buildSubtitle(track),
                            isSelected: isSelected,
                            isDefault: track.isDefault && selectedIndex == null,
                            onTap: () {
                              ref.read(selectedAudioStreamIndexProvider.notifier).state = track.index;
                              onSelected?.call(track.index);
                              onClose?.call();
                            },
                          );
                        }),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(MediaStream track) {
    final parts = <String>[];
    if (track.language != null && track.language!.isNotEmpty) {
      parts.add(_languageLabel(track.language!));
    }
    if (track.codec != null && track.codec!.isNotEmpty) {
      parts.add(track.codec!.toUpperCase());
    }
    if (track.isDefault) parts.add('默认');
    return parts.join(' · ');
  }

  String _languageLabel(String code) {
    const map = {
      'chi': '中文', 'zh': '中文', 'zho': '中文',
      'eng': '英文', 'en': '英文',
      'jpn': '日文', 'ja': '日文',
      'kor': '韩文', 'ko': '韩文',
      'fre': '法文', 'fra': '法文', 'fr': '法文',
      'ger': '德文', 'deu': '德文', 'de': '德文',
      'spa': '西班牙文', 'es': '西班牙文',
      'por': '葡萄牙文', 'pt': '葡萄牙文',
      'rus': '俄文', 'ru': '俄文',
      'tha': '泰文', 'th': '泰文',
    };
    return map[code.toLowerCase()] ?? code.toUpperCase();
  }

  Widget _buildTrackOption({
    required BuildContext context,
    required ColorScheme scheme,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDefault,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.12),
                  width: 2,
                ),
                color: isSelected ? scheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: scheme.onPrimary, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.audiotrack,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isDefault && !isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
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
}

/// 显示音轨选择器底部弹窗
Future<void> showAudioTrackSelector(
  BuildContext context,
  List<MediaStream> tracks, {
  int? selectedIndex,
  void Function(int? index)? onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => AudioTrackSelector(
      tracks: tracks,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    ),
  );
}
