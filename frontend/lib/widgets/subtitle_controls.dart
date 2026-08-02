// 字幕控制面板：语言、字号、颜色、位置、描边、阴影、背景透明度、时间偏移

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/subtitle_settings_provider.dart';
import '../utils/constants.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(subtitleSettingsProvider);
    final notifier = ref.read(subtitleSettingsProvider.notifier);

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: TextStyle(color: scheme.onSurface, fontSize: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '字幕设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurface),
                    onPressed: onClose,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 语言/轨道
            _section('语言', scheme),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '关闭',
                  selected: settings.language.isEmpty,
                  onTap: () => notifier.setLanguage(''),
                  scheme: scheme,
                ),
                ...tracks.map(
                  (t) => _chip(
                    label: t.name.isNotEmpty ? t.name : t.language,
                    selected: settings.language == t.id,
                    onTap: () => notifier.setLanguage(t.id),
                    scheme: scheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 字号
            _section('字号', scheme),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(
                    label: '小',
                    selected: settings.size == kSubtitleSizeSmall,
                    onTap: () => notifier.setSize(kSubtitleSizeSmall),
                    scheme: scheme),
                const SizedBox(width: 8),
                _chip(
                    label: '中',
                    selected: settings.size == kSubtitleSizeMedium,
                    onTap: () => notifier.setSize(kSubtitleSizeMedium),
                    scheme: scheme),
                const SizedBox(width: 8),
                _chip(
                    label: '大',
                    selected: settings.size == kSubtitleSizeLarge,
                    onTap: () => notifier.setSize(kSubtitleSizeLarge),
                    scheme: scheme),
              ],
            ),
            const SizedBox(height: 16),

            // 颜色
            _section('颜色', scheme),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(
                    label: '白',
                    selected: settings.color == kSubtitleColorWhite,
                    onTap: () => notifier.setColor(kSubtitleColorWhite),
                    scheme: scheme),
                const SizedBox(width: 8),
                _chip(
                    label: '黄',
                    selected: settings.color == kSubtitleColorYellow,
                    onTap: () => notifier.setColor(kSubtitleColorYellow),
                    scheme: scheme),
              ],
            ),
            const SizedBox(height: 16),

            // 位置
            _section('位置', scheme),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(
                    label: '底部',
                    selected: settings.position == kSubtitlePosBottom,
                    onTap: () => notifier.setPosition(kSubtitlePosBottom),
                    scheme: scheme),
                const SizedBox(width: 8),
                _chip(
                    label: '偏下',
                    selected: settings.position == kSubtitlePosLower,
                    onTap: () => notifier.setPosition(kSubtitlePosLower),
                    scheme: scheme),
                const SizedBox(width: 8),
                _chip(
                    label: '居中',
                    selected: settings.position == kSubtitlePosCenter,
                    onTap: () => notifier.setPosition(kSubtitlePosCenter),
                    scheme: scheme),
              ],
            ),
            const SizedBox(height: 16),

            // 描边宽度
            _sectionWithValue(
                '描边宽度', '${settings.strokeWidth.toStringAsFixed(1)}px', scheme),
            const SizedBox(height: 8),
            Slider(
              value: settings.strokeWidth,
              min: kSubtitleStrokeWidthMin,
              max: kSubtitleStrokeWidthMax,
              divisions: 10,
              activeColor: scheme.primary,
              inactiveColor: scheme.outlineVariant,
              onChanged: (v) => notifier.setStrokeWidth(v),
            ),
            const SizedBox(height: 12),

            // 阴影开关
            _section('阴影', scheme),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(
                  label: '开启',
                  selected: settings.shadowEnabled,
                  onTap: () => notifier.setShadowEnabled(true),
                  scheme: scheme,
                ),
                const SizedBox(width: 8),
                _chip(
                  label: '关闭',
                  selected: !settings.shadowEnabled,
                  onTap: () => notifier.setShadowEnabled(false),
                  scheme: scheme,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 背景透明度
            _sectionWithValue('背景透明度', '${settings.bgOpacity}%', scheme),
            const SizedBox(height: 8),
            Slider(
              value: settings.bgOpacity.toDouble(),
              min: kSubtitleBgOpacityMin.toDouble(),
              max: kSubtitleBgOpacityMax.toDouble(),
              divisions: 20,
              activeColor: scheme.primary,
              inactiveColor: scheme.outlineVariant,
              onChanged: (v) => notifier.setBgOpacity(v.toInt()),
            ),
            const SizedBox(height: 12),

            // 时间轴微调
            _sectionWithValue(
                '时间微调', _formatTimeOffset(settings.timeOffset), scheme),
            const SizedBox(height: 8),
            Slider(
              value: settings.timeOffset.toDouble(),
              min: kSubtitleTimeOffsetMin.toDouble(),
              max: kSubtitleTimeOffsetMax.toDouble(),
              divisions: 20,
              activeColor: scheme.primary,
              inactiveColor: scheme.outlineVariant,
              onChanged: (v) => notifier.setTimeOffset(v.toInt()),
            ),
            const SizedBox(height: 4),
            Text(
              '负数提前显示，正数延迟显示',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, ColorScheme scheme) => Text(
        title,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
      );

  Widget _sectionWithValue(String title, String value, ColorScheme scheme) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: scheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  String _formatTimeOffset(int offsetMs) {
    if (offsetMs == 0) return '0.0s';
    final sign = offsetMs > 0 ? '+' : '-';
    final seconds = offsetMs.abs() / 1000.0;
    return '$sign${seconds.toStringAsFixed(1)}s';
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme scheme,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurface,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
