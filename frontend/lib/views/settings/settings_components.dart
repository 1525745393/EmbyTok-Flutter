// 设置页通用组件（从 settings_view.dart 拆分，纯搬移无行为变化）
//
// 设置项的通用 Tile 构建：点击型 / 开关型 / 信息型 / 帮助按钮 / 媒体库
// chip 展示。常量值与原 settings_view.dart 保持一致的私有副本。

import 'package:flutter/material.dart';

import '../../models/models.dart' show Library;

const double _kFontSizeBody = 13;
const double _kFontSizeLarge = 15;
const double _kTileIconContainerSize = 36.0;
const double _kTileIconContainerRadius = 8.0;
const double _kTileIconContainerBgAlpha = 0.12;
const double _kTileIconSize = 20.0;
const double _kTileSubtitleAlpha = 0.8;

Widget settingsRuleSectionDivider(ColorScheme scheme) {
  return Divider(
    height: 1,
    indent: 20,
    endIndent: 20,
    color: scheme.outlineVariant.withValues(alpha: 0.4),
  );
}

Widget settingsLibrarySelectionTile({
  required IconData icon,
  Color? iconColor,
  required String title,
  required List<Library> libraries,
  required bool favoritesMode,
  String favoritesLabel = '收藏夹',
  required VoidCallback onTap,

  /// 媒体库 chip 点击回调（快捷移除单个数据源，如 null 则 chips 只读）
  ValueChanged<String>? onChipTap,

  /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
  String? helpText,
}) {
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      if (favoritesMode)
        settingsLibraryChip(
          label: favoritesLabel,
          icon: Icons.star,
          color: scheme.primary,
          background: scheme.primaryContainer,
        ),
      if (!favoritesMode)
        for (final lib in libraries)
          settingsTapChip(
            onTap: onChipTap == null ? null : () => onChipTap(lib.id),
            chip: settingsLibraryChip(
              label: lib.name,
              icon: settingsLibraryTypeIcon(lib.type),
              color: scheme.onSurfaceVariant,
              background: scheme.surfaceContainerHighest,
            ),
          ),
      if (!favoritesMode && libraries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '未选择',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: _kFontSizeBody,
            ),
          ),
        ),
    ];
    return ListTile(
      leading:
          settingsIconContainer(icon: icon, color: iconColor ?? scheme.primary),
      title: Text(
        title,
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: chips,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          settingsHelpButton(helpText: helpText, title: title),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  });
}

IconData settingsLibraryTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'movies':
    case 'movie':
      return Icons.movie_outlined;
    case 'tvshows':
    case 'tvshow':
    case 'series':
      return Icons.live_tv_outlined;
    case 'music':
      return Icons.music_note_outlined;
    default:
      return Icons.folder_outlined;
  }
}

Widget settingsTapChip({
  required VoidCallback? onTap,
  required Widget chip,
}) {
  return onTap == null
      ? chip
      : GestureDetector(
          onTap: onTap,
          child: chip,
        );
}

Widget settingsLibraryChip({
  required String label,
  required IconData icon,
  required Color color,
  required Color background,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget settingsTapTile({
  required IconData icon,
  Color? iconColor,
  required String title,
  String? subtitle,
  required VoidCallback onTap,

  /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
  String? helpText,
}) {
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading:
          settingsIconContainer(icon: icon, color: iconColor ?? scheme.primary),
      title: Text(
        title,
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: scheme.onSurfaceVariant
                    .withValues(alpha: _kTileSubtitleAlpha),
                fontSize: _kFontSizeBody,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          settingsHelpButton(helpText: helpText, title: title),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  });
}

Widget settingsSwitchTile({
  required IconData icon,
  Color? iconColor,
  required String title,
  String? subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,

  /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
  String? helpText,
}) {
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading:
          settingsIconContainer(icon: icon, color: iconColor ?? scheme.primary),
      title: Text(
        title,
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: scheme.onSurfaceVariant
                    .withValues(alpha: _kTileSubtitleAlpha),
                fontSize: _kFontSizeBody,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          settingsHelpButton(helpText: helpText, title: title),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: scheme.primary,
          ),
        ],
      ),
    );
  });
}

Widget settingsInfoTile({
  required IconData icon,
  Color? iconColor,
  required String title,
  String? subtitle,

  /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
  String? helpText,
}) {
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading:
          settingsIconContainer(icon: icon, color: iconColor ?? scheme.primary),
      title: Text(
        title,
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: _kFontSizeBody,
              ),
            )
          : null,
      trailing: settingsHelpButton(helpText: helpText, title: title),
    );
  });
}

Widget settingsHelpButton({
  required String? helpText,
  required String title,
}) {
  if (helpText == null || helpText.isEmpty) {
    return const SizedBox.shrink();
  }
  return Builder(builder: (context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.help_outline, size: 19, color: scheme.onSurfaceVariant),
      tooltip: '帮助',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      onPressed: () => settingsShowHelp(context, title, helpText),
    );
  });
}

void settingsShowHelp(BuildContext context, String title, String helpText) {
  final scheme = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surfaceContainerHigh,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, size: 22, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 20, color: scheme.onSurfaceVariant),
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                helpText,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget settingsIconContainer({required IconData icon, required Color color}) {
  return Container(
    width: _kTileIconContainerSize,
    height: _kTileIconContainerSize,
    decoration: BoxDecoration(
      color: color.withValues(alpha: _kTileIconContainerBgAlpha),
      borderRadius: BorderRadius.circular(_kTileIconContainerRadius),
    ),
    child: Icon(icon, color: color, size: _kTileIconSize),
  );
}
