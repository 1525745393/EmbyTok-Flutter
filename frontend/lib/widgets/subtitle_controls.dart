// 字幕控制面板：切换语言、字号、颜色、位置

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/subtitle_settings_provider.dart';
import '../utils/constants.dart';
import '../utils/colors.dart';

class SubtitleControls extends ConsumerWidget {
  final List<SubtitleTrack> tracks;
  final VoidCallback? onClose;

  const SubtitleControls({
    super.key,
    required this.tracks,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(subtitleSettingsProvider);
    final notifier = ref.read(subtitleSettingsProvider.notifier);

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor),
      ),
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: const TextStyle(color: textPrimary, fontSize: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '字幕设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: historyPink,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: textPrimary),
                    onPressed: onClose,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 语言/轨道
            _section('语言'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '关闭',
                  selected: settings.language.isEmpty,
                  onTap: () => notifier.setLanguage(''),
                ),
                ...tracks.map(
                  (t) => _chip(
                    label: t.name.isNotEmpty ? t.name : t.language,
                    selected: settings.language == t.id,
                    onTap: () => notifier.setLanguage(t.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 字号
            _section('字号'),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(label: '小', selected: settings.size == kSubtitleSizeSmall,
                    onTap: () => notifier.setSize(kSubtitleSizeSmall)),
                const SizedBox(width: 8),
                _chip(label: '中', selected: settings.size == kSubtitleSizeMedium,
                    onTap: () => notifier.setSize(kSubtitleSizeMedium)),
                const SizedBox(width: 8),
                _chip(label: '大', selected: settings.size == kSubtitleSizeLarge,
                    onTap: () => notifier.setSize(kSubtitleSizeLarge)),
              ],
            ),
            const SizedBox(height: 16),

            // 颜色
            _section('颜色'),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(label: '白', selected: settings.color == kSubtitleColorWhite,
                    onTap: () => notifier.setColor(kSubtitleColorWhite)),
                const SizedBox(width: 8),
                _chip(label: '黄', selected: settings.color == kSubtitleColorYellow,
                    onTap: () => notifier.setColor(kSubtitleColorYellow)),
              ],
            ),
            const SizedBox(height: 16),

            // 位置
            _section('位置'),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(label: '底部', selected: settings.position == kSubtitlePosBottom,
                    onTap: () => notifier.setPosition(kSubtitlePosBottom)),
                const SizedBox(width: 8),
                _chip(label: '偏下', selected: settings.position == kSubtitlePosLower,
                    onTap: () => notifier.setPosition(kSubtitlePosLower)),
                const SizedBox(width: 8),
                _chip(label: '居中', selected: settings.position == kSubtitlePosCenter,
                    onTap: () => notifier.setPosition(kSubtitlePosCenter)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Text(
        title,
        style: const TextStyle(color: textSecondary, fontSize: 12),
      );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primaryPink : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? historyPink : progressBackground,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? textPrimary : textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
