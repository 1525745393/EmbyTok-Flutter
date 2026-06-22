import 'package:flutter/material.dart';

/// 快捷键帮助面板：按 ? 键显示
class KeyboardHelpPanel extends StatelessWidget {
  const KeyboardHelpPanel({super.key});

  static const _shortcuts = [
    ('W / S / ↑ / ↓', '上一个 / 下一个视频'),
    ('A / D / ← / →', '快退 / 快进 15 秒'),
    ('Space', '暂停 / 播放'),
    ('U', '收藏视频'),
    ('E', '切换视图（视频流 / 海报墙）'),
    ('R', '顺序 / 随机播放'),
    ('G', '选择媒体库'),
    ('F', '全屏切换'),
    ('M', '静音切换'),
    ('?', '显示 / 隐藏快捷键帮助'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.87),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '键盘快捷键',
            style: TextStyle(
              color: scheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ..._shortcuts.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.$1, style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(s.$2, style: TextStyle(color: scheme.onSurface.withOpacity(0.7), fontSize: 14)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
