// 视频播放控制按钮组件
// 拆分自 video_page_item.dart 中大量 _buildXxxButton() 方法
// 每个按钮都是独立的 Widget，便于复用和测试

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/image_cache_manager.dart';

// ===== 响应式尺寸工具 =====
double responsiveSize(BuildContext context, double base, [double maxScale = 1.7]) {
  final screenWidth = MediaQuery.of(context).size.width;
  final double scale;
  if (screenWidth <= 480.0) {
    scale = 1.0;
  } else if (screenWidth <= 800.0) {
    scale = 1.0 + ((screenWidth - 480.0) / 320.0) * 0.3;
  } else if (screenWidth <= 1200.0) {
    scale = 1.3 + ((screenWidth - 800.0) / 400.0) * 0.3;
  } else {
    scale = 1.6 + ((screenWidth - 1200.0) / 720.0) * 0.1;
  }
  return base * (scale > maxScale ? maxScale : scale);
}

// ===== 演员头像/视频封面按钮 =====
class PosterAvatar extends ConsumerWidget {
  final MediaItem item;
  final VoidCallback? onTap; // 点击演员跳转到详情

  const PosterAvatar({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final embyServerUrl = authState.embyServerUrl;
    final token = authState.token;
    final scheme = Theme.of(context).colorScheme;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);

    final people = item.people;
    final Person? firstActor =
        people != null && people.isNotEmpty
            ? people.firstWhere((p) => p.type.toLowerCase() == 'actor',
                orElse: () => people.first)
            : null;

    if (firstActor != null && firstActor.id != null && firstActor.id!.isNotEmpty) {
      final actorImageUrl = embyServerUrl != null && token != null
          ? '$embyServerUrl/Items/${firstActor.id}/Images/Primary?MaxWidth=200&api_key=$token'
          : firstActor.imageUrl;
      final headers = item.authHeaders(token);
      final isFavorited =
          ref.watch(favoritesProvider).favoriteIds.contains(firstActor.id!);
      final actorMediaItem = MediaItem(
        id: firstActor.id!,
        title: firstActor.name,
        type: 'Person',
        imageTags: {'Primary': firstActor.imageUrl ?? 'primary'},
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: rs(48),
            height: rs(48),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onTap ??
                        () {
                          context.push('/person/${actorMediaItem.id}',
                              extra: actorMediaItem);
                        },
                    child: Container(
                      width: rs(48),
                      height: rs(48),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.onSurface.withOpacity(0.4),
                          width: 2,
                        ),
                        color: scheme.surface.withOpacity(0.15),
                      ),
                      child: ClipOval(
                        child: actorImageUrl != null && actorImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: actorImageUrl,
                                cacheManager: AppImageCacheManager.thumbnail,
                                fit: BoxFit.cover,
                                httpHeaders: headers.isNotEmpty ? headers : null,
                                memCacheWidth: 96,
                                placeholder: (_, __) => Icon(Icons.person,
                                    color: scheme.onSurface.withOpacity(0.54),
                                    size: rs(24)),
                                errorWidget: (_, __, ___) => Icon(Icons.person,
                                    color: scheme.onSurface.withOpacity(0.54),
                                    size: rs(24)),
                              )
                            : Icon(Icons.person,
                                color: scheme.onSurface.withOpacity(0.54)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(actorMediaItem);
                    },
                    child: Container(
                      width: rs(20),
                      height: rs(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.tertiary,
                        border: Border.all(color: scheme.onSurface, width: 1.5),
                      ),
                      child: Icon(
                        isFavorited ? Icons.check : Icons.add,
                        color: scheme.onTertiary,
                        size: rs(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: rs(4)),
          Text(
            firstActor.name.length > 4 ? '${firstActor.name.substring(0, 4)}..' : firstActor.name,
            style: TextStyle(
              color: scheme.onSurface.withOpacity(0.7),
              fontSize: rs(9, 1.3),
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final posterUrl = item.imageUrl('Primary',
        embyServerUrl: embyServerUrl, apiKey: token, maxWidth: 200);
    final posterHeaders = item.authHeaders(token);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: rs(40),
        height: rs(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.onSurface.withOpacity(0.4), width: 2),
          color: scheme.surface.withOpacity(0.15),
        ),
        child: ClipOval(
          child: posterUrl != null && posterUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: posterUrl,
                  cacheManager: AppImageCacheManager.thumbnail,
                  fit: BoxFit.cover,
                  httpHeaders: posterHeaders.isNotEmpty ? posterHeaders : null,
                  memCacheWidth: 80,
                  placeholder: (_, __) => Icon(Icons.music_video,
                      color: scheme.onSurface.withOpacity(0.54), size: rs(20)),
                  errorWidget: (_, __, ___) => Icon(Icons.music_video,
                      color: scheme.onSurface.withOpacity(0.54), size: rs(20)),
                )
              : Icon(Icons.music_video, color: scheme.onSurface.withOpacity(0.54)),
        ),
      ),
    );
  }
}

// ===== 自动播放开关（∞ 图标）=====
class AutoPlayButton extends ConsumerWidget {
  const AutoPlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final scheme = Theme.of(context).colorScheme;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    return GestureDetector(
      onTap: () {
        ref.read(isAutoPlayProvider.notifier).toggle();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAutoPlay ? '连播模式已关闭' : '连播模式已开启',
                  style: TextStyle(color: scheme.onPrimary)),
              backgroundColor:
                  isAutoPlay ? scheme.primary.withOpacity(0.8) : scheme.onSurface.withOpacity(0.6),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            ),
          );
        }
      },
      child: Container(
        width: rs(40),
        height: rs(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAutoPlay
              ? scheme.primary.withOpacity(0.8)
              : scheme.surface.withOpacity(0.3),
        ),
        child: Icon(Icons.all_inclusive, color: scheme.onSurface, size: rs(24)),
      ),
    );
  }
}

// ===== 倍速调节按钮 =====
class SpeedControlButton extends StatelessWidget {
  final VideoPlayerController? controller;
  final VoidCallback onTap;

  const SpeedControlButton({
    super.key,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentSpeed = controller?.value.playbackSpeed ?? 1.0;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: rs(40),
        height: rs(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentSpeed > 1.0
              ? scheme.tertiary.withOpacity(0.8)
              : scheme.surface.withOpacity(0.3),
        ),
        child: Icon(Icons.speed, color: scheme.onSurface, size: rs(20)),
      ),
    );
  }
}

// ===== 播放模式按钮（DirectPlay/Transcode/Fallback 循环切换）=====
class PlayModeButton extends ConsumerWidget {
  const PlayModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(playbackLevelProvider);
    final scheme = Theme.of(context).colorScheme;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    final IconData icon;
    final Color bgColor;
    switch (currentLevel) {
      case 0:
        icon = Icons.play_circle_outline;
        bgColor = scheme.surface.withOpacity(0.3);
        break;
      case 1:
        icon = Icons.swap_horiz;
        bgColor = scheme.primary.withOpacity(0.8);
        break;
      case 2:
      default:
        icon = Icons.warning;
        bgColor = scheme.tertiary.withOpacity(0.8);
        break;
    }
    return GestureDetector(
      onTap: () {
        final newLevel = (currentLevel + 1) % 3;
        ref.read(playbackLevelProvider.notifier).setLevel(newLevel);
      },
      child: Container(
        width: rs(40),
        height: rs(40),
        decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
        child: Center(child: Icon(icon, color: scheme.onSurface, size: rs(20))),
      ),
    );
  }
}

// ===== 字幕按钮 =====
class SubtitleButton extends ConsumerWidget {
  final bool hasSubtitles;
  final VoidCallback? onTap;

  const SubtitleButton({
    super.key,
    required this.hasSubtitles,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleSelected = ref.watch(selectedSubtitleProvider);
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = subtitleSelected != null;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    return GestureDetector(
      onTap: hasSubtitles ? onTap : null,
      child: Container(
        width: rs(40),
        height: rs(40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? scheme.primary.withOpacity(0.8)
              : (hasSubtitles
                  ? scheme.surface.withOpacity(0.3)
                  : scheme.surface.withOpacity(0.1)),
        ),
        child: Icon(Icons.subtitles, color: scheme.onSurface, size: rs(20)),
      ),
    );
  }
}

// ===== 唱片式静音按钮（播放时旋转，显示封面图，静音时红色边框）=====
class DiscMuteButton extends ConsumerWidget {
  final Animation<double> discRotation;
  final VideoPlayerController? controller;
  final String posterUrl;
  final Map<String, String>? httpHeaders;

  const DiscMuteButton({
    super.key,
    required this.discRotation,
    this.controller,
    required this.posterUrl,
    this.httpHeaders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMuted = ref.watch(isMutedProvider);
    final scheme = Theme.of(context).colorScheme;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    return GestureDetector(
      onTap: () {
        ref.read(isMutedProvider.notifier).toggle();
        controller?.setVolume(isMuted ? 1.0 : 0.0);
      },
      child: RotationTransition(
        turns: discRotation,
        child: Container(
          width: rs(40),
          height: rs(40),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface.withOpacity(0.3),
            border: Border.all(
              color: isMuted ? scheme.primary : scheme.onSurface.withOpacity(0.4),
              width: 2,
            ),
            image: posterUrl.isNotEmpty
                ? DecorationImage(
                    image: ResizeImage(
                      CachedNetworkImageProvider(
                        posterUrl,
                        headers: httpHeaders,
                      ),
                      width: 160,
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: posterUrl.isEmpty
              ? Center(
                  child: Icon(
                    isMuted ? Icons.volume_off : Icons.music_note,
                    color: isMuted ? scheme.primary : scheme.onSurface,
                    size: rs(20),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ===== 中央播放按钮（暂停时显示半透明播放图标）=====
class CenterPlayButton extends StatelessWidget {
  final VoidCallback onPlay;

  const CenterPlayButton({
    super.key,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    return Positioned.fill(
      child: Center(
        child: GestureDetector(
          onTap: onPlay,
          child: Container(
            width: rs(60),
            height: rs(60),
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow, color: scheme.onSurface, size: rs(40)),
          ),
        ),
      ),
    );
  }
}

// ===== 倍速状态徽章（与 EmbyTok 原版一致）=====
class SpeedBadge extends StatelessWidget {
  final double speed;

  const SpeedBadge({super.key, required this.speed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    return Positioned(
      top: rs(40),
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: rs(12), vertical: rs(6)),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.87),
            borderRadius: BorderRadius.circular(rs(16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flash_on, color: scheme.tertiary, size: rs(14)),
              SizedBox(width: rs(4)),
              Text('${speed.toStringAsFixed(1)}x',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: rs(12, 1.3),
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 顶部操作区：全屏切换按钮 =====
class TopActions extends StatelessWidget {
  final VoidCallback onToggleFullscreen;

  const TopActions({super.key, required this.onToggleFullscreen});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final rs = (double base, [double max = 1.7]) => responsiveSize(context, base, max);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: topPadding + 8,
      right: 16,
      child: GestureDetector(
        onTap: onToggleFullscreen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(rs(8)),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(rs(16)),
            boxShadow: [BoxShadow(color: scheme.onSurface.withOpacity(0.15), blurRadius: 8)],
          ),
          child: Icon(Icons.fullscreen, color: scheme.onSurface, size: rs(40)),
        ),
      ),
    );
  }
}

// ===== NextUp 下一集提示条 =====
class NextUpBanner extends StatelessWidget {
  final MediaItem nextItem;
  final int countdown;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  const NextUpBanner({
    super.key,
    required this.nextItem,
    required this.countdown,
    required this.onPlay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final scheme = Theme.of(context).colorScheme;

    final seasonEp = (nextItem.parentIndexNumber != null && nextItem.indexNumber != null)
        ? 'S${nextItem.parentIndexNumber}E${nextItem.indexNumber}'
        : null;
    final nextTitle = seasonEp != null ? '$seasonEp ${nextItem.title}' : nextItem.title;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomPadding + 80 + 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.skip_next, color: scheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('即将播放下一集',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(nextTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${countdown}s',
                    style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('立即播放',
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant, size: 20),
                onPressed: onCancel,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
