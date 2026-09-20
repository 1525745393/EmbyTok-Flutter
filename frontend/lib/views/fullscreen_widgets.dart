// 从 fullscreen_video_page.dart 拆分（part 文件，无行为变化）

part of 'fullscreen_video_page.dart';

// ==================== 私有组件 ====================

class _SeekPreviewBar extends StatelessWidget {
  const _SeekPreviewBar({
    required this.current,
    required this.total,
    required this.offset,
  });
  final Duration current;
  final Duration total;
  final Duration offset;

  String _format(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds > 0
        ? current.inMilliseconds / total.inMilliseconds
        : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isForward = offset >= Duration.zero;
    final offsetText =
        '${isForward ? '+' : '-'}${(offset.inSeconds.abs() ~/ 1)}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                isForward ? Icons.fast_forward : Icons.fast_rewind,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                offsetText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_format(current)} / ${_format(total)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: _kFontSizeSmall,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: _kSpacingMedium),
          LinearProgressIndicator(
            value: clampedProgress,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _FlyingHeart extends StatefulWidget {
  const _FlyingHeart();

  @override
  State<_FlyingHeart> createState() => _FlyingHeartState();
}

class _FlyingHeartState extends State<_FlyingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kFullscreenFlyingHeartAnimMs),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scale = Tween<double>(
      begin: kFlyingHeartScaleBegin,
      end: kFlyingHeartScaleEnd,
    ).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Icon(
              Icons.favorite,
              color: Theme.of(context).colorScheme.primary,
              size: 96,
            ),
          ),
        );
      },
    );
  }
}

class _SettingsListItem extends StatelessWidget {
  const _SettingsListItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

enum _SettingsTab { speed, ratio }

enum _AspectRatioMode { auto, contain, cover, fill, sixteenNine, fourThree }

enum _OrientationPref { landscape, portrait, sensor }

/// 进度条拖动防抖处理器
///
/// 封装 Slider 拖动期间的状态管理，确保单次拖动只在 [endDrag] 时
/// 触发一次 seekTo，避免 [updateDrag] 每帧 seek 造成卡顿与资源浪费。
///
/// 抽出为顶层公开类便于单元测试（参考 feed_autopause_test.dart 中
/// applyFeedVisibilityChange 的可测试性设计），无需构造 FullscreenVideoPage widget。
