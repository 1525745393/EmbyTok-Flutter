// 视频流单页：全屏视频 + 右侧操作按钮 + 左下角标题信息
// 采用 GestureOverlay 处理手势交互（单击/双击/长按/水平拖动）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/formatters.dart';
import 'gesture_overlay.dart';
import 'subtitle_renderer.dart';
import 'subtitle_selector.dart';
import 'video_player_widget.dart';

// 单个视频页：TikTok 卡片样式
class VideoPageItem extends ConsumerStatefulWidget {
  final MediaItem item;
  final int? initialPosition; // 初始播放位置（秒）
  final VoidCallback? onNextVideo; // 切换到下一个视频的回调

  const VideoPageItem({
    super.key,
    required this.item,
    this.initialPosition,
    this.onNextVideo,
  });

  @override
  ConsumerState<VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends ConsumerState<VideoPageItem>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  Timer? _hideInfoTimer;
  bool _showInfoPanel = true;
  bool _isOverviewExpanded = false;
  late AnimationController _rotationController;
  
  // 字幕相关状态
  List<SubtitleTrack> _subtitleTracks = [];
  List<SubtitleCue> _currentCues = [];
  bool _isLoadingSubtitles = false;
  String? _loadedSubtitleUrl;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _startHideInfoTimer();
    _loadSubtitleTracks();
  }

  @override
  void dispose() {
    _hideInfoTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }
  
  // 加载字幕轨道列表
  Future<void> _loadSubtitleTracks() async {
    final authState = ref.read(authProvider);
    if (authState.embyServerUrl == null || authState.token == null) return;
    
    setState(() {
      _isLoadingSubtitles = true;
    });
    
    try {
      final tracks = await ref.read(embytokServiceProvider).getSubtitleTracks(
        itemId: widget.item.id,
        serverUrl: authState.embyServerUrl,
        token: authState.token,
      );
      
      if (mounted) {
        setState(() {
          _subtitleTracks = tracks;
          _isLoadingSubtitles = false;
        });
        
        // 如果有默认字幕，自动加载
        final defaultTrack = tracks.firstWhere(
          (t) => t.isDefault,
          orElse: () => tracks.isNotEmpty ? tracks.first : SubtitleTrack(
            id: '',
            name: '',
            language: '',
            format: '',
          ),
        );
        
        if (defaultTrack.id.isNotEmpty && defaultTrack.url != null) {
          _loadSubtitleContent(defaultTrack);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSubtitles = false;
        });
      }
    }
  }
  
  // 加载字幕内容
  Future<void> _loadSubtitleContent(SubtitleTrack track) async {
    if (track.url == null || track.url!.isEmpty) return;
    
    // 避免重复加载
    if (_loadedSubtitleUrl == track.url) return;
    
    try {
      // 这里简化处理，实际应该通过 HTTP 请求获取字幕内容
      // 由于 Flutter 的限制，这里需要使用 http 包或其他方式获取
      // 暂时留空，等待实际实现
      
      // final response = await http.get(Uri.parse(track.url!));
      // final content = response.body;
      // final cues = parseSrt(content);
      
      // setState(() {
      //   _currentCues = cues;
      //   _loadedSubtitleUrl = track.url;
      // });
    } catch (e) {
      debugPrint('加载字幕失败: $e');
    }
  }

  // 启动 3 秒后自动隐藏信息面板的定时器
  void _startHideInfoTimer() {
    _hideInfoTimer?.cancel();
    _hideInfoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController?.value.isPlaying == true) {
        setState(() {
          _showInfoPanel = false;
        });
      }
    });
  }

  // 点击屏幕时重新显示信息面板
  void _onScreenTap() {
    setState(() {
      _showInfoPanel = true;
    });
    _startHideInfoTimer();
  }

  // 切换简介展开/收起
  void _toggleOverview() {
    setState(() {
      _isOverviewExpanded = !_isOverviewExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final favorited =
        ref.watch(favoritesProvider).favoriteIds.contains(widget.item.id);
    final isMuted = ref.watch(isMutedProvider);
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底层：视频播放器 + 手势覆盖层
        GestureOverlay(
          controller: _videoController,
          item: widget.item,
          onTap: _onScreenTap,
          child: VideoPlayerWidget(
            item: widget.item,
            embyServerUrl: authState.embyServerUrl,
            token: authState.token,
            initialPosition: widget.initialPosition,
            // 自动播放关闭时启用循环播放
            loop: !isAutoPlay,
            onProgressUpdate: (position, duration) {
              // 记录观看进度
              ref.read(watchHistoryProvider.notifier).recordProgress(
                    widget.item.id,
                    position,
                    duration,
                    itemTitle: widget.item.title,
                    thumbnailUrl: widget.item.thumbnailUrl,
                  );
            },
            onControllerReady: (c) {
              setState(() {
                _videoController = c;
              });
              ref.read(isPlayingProvider.notifier).state = true;
              ref.read(currentPlayingItemProvider.notifier).state =
                  widget.item;
              // 播放时启动旋转动画
              _rotationController.repeat();
              // 监听播放状态变化
              c.addListener(() {
                if (c.value.isPlaying) {
                  _rotationController.repeat();
                } else {
                  _rotationController.stop();
                }
              });
            },
            // 视频播放完毕回调
            onVideoEnded: () {
              // 自动播放开启时，切换到下一个视频
              if (isAutoPlay && widget.onNextVideo != null) {
                widget.onNextVideo!();
              }
            },
          ),
        ),

        // 字幕显示层
        if (_videoController != null && _currentCues.isNotEmpty)
          Positioned(
            left: 0,
            right: 96,
            bottom: 120,
            child: SubtitleRenderer(
              position: _videoController!.value.position,
              cues: _currentCues,
              enabled: true,
            ),
          ),

        // 底部渐变 + 标题/简介/类型标签（带淡入淡出动画）
        AnimatedOpacity(
          opacity: _showInfoPanel ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _buildBottomInfoPanel(),
        ),

        // 右侧渐变 + 操作按钮（带淡入淡出动画）
        AnimatedOpacity(
          opacity: _showInfoPanel ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _buildRightActions(
            favorited: favorited,
            isMuted: isMuted,
            isAutoPlay: isAutoPlay,
            isPlaying: isPlaying,
            embyServerUrl: authState.embyServerUrl,
            token: authState.token,
          ),
        ),
      ],
    );
  }

  // 底部信息面板：渐变背景 + 标题/年份/时长/类型/简介
  Widget _buildBottomInfoPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 100, 96, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xE6000000), // 90% 黑色
              Color(0x80000000), // 50% 黑色
              Colors.transparent,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              widget.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // 年份、时长、媒体类型标签
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.item.productionYear != null)
                  _buildInfoChip(
                    '${widget.item.productionYear}',
                    icon: Icons.calendar_today,
                  ),
                if (widget.item.runtimeTicks != null)
                  _buildInfoChip(
                    formatRuntimeTicks(widget.item.runtimeTicks),
                    icon: Icons.schedule,
                  ),
                _buildMediaTypeChip(widget.item.type),
              ],
            ),
            const SizedBox(height: 10),

            // 简介（默认 2 行，点击展开）
            if (widget.item.overview != null &&
                widget.item.overview!.isNotEmpty)
              GestureDetector(
                onTap: _toggleOverview,
                child: AnimatedCrossFade(
                  firstChild: Text(
                    widget.item.overview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  secondChild: Text(
                    widget.item.overview!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  crossFadeState: _isOverviewExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建信息标签（年份、时长等）
  Widget _buildInfoChip(String text, {IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white54, size: 12),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 构建媒体类型标签
  Widget _buildMediaTypeChip(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE91E63),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _getMediaTypeLabel(type),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 获取媒体类型的显示文本
  String _getMediaTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return '电影';
      case 'episode':
        return '剧集';
      case 'series':
        return '系列';
      case 'musicvideo':
        return 'MV';
      default:
        return type;
    }
  }

  // 右侧操作按钮列：自动播放 / 收藏 / 字幕 / 信息 / 静音（从下到上排列）
  Widget _buildRightActions({
    required bool favorited,
    required bool isMuted,
    required bool isAutoPlay,
    required bool isPlaying,
    String? embyServerUrl,
    String? token,
  }) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 40, 8, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Colors.black54,
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 自动播放按钮
            _buildAutoPlayButton(isAutoPlay),
            const SizedBox(height: 20),
            // 收藏按钮（带动画）
            _buildFavoriteButton(favorited),
            const SizedBox(height: 20),
            // 字幕按钮
            _buildSubtitleButton(),
            const SizedBox(height: 20),
            // 信息按钮
            _buildInfoButton(),
            const SizedBox(height: 20),
            // 静音按钮（带旋转动画和缩略图）
            _buildMuteButton(
              isMuted: isMuted,
              isPlaying: isPlaying,
              embyServerUrl: embyServerUrl,
              token: token,
            ),
          ],
        ),
      ),
    );
  }

  // 自动播放模式切换按钮
  Widget _buildAutoPlayButton(bool isAutoPlay) {
    return GestureDetector(
      onTap: () {
        ref.read(isAutoPlayProvider.notifier).toggle();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isAutoPlay
              ? const Color(0xCC4CAF50) // 绿色背景（开启）
              : const Color(0x4D000000), // 半透明黑色（关闭）
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.all_inclusive,
          color: isAutoPlay ? Colors.white : Colors.white54,
          size: 24,
        ),
      ),
    );
  }

  // 收藏按钮（带心形填充动画）
  Widget _buildFavoriteButton(bool favorited) {
    return GestureDetector(
      onTap: () {
        ref.read(favoritesProvider.notifier).toggleFavorite(widget.item);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Icon(
          favorited ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(favorited),
          color: favorited ? const Color(0xFFE91E63) : Colors.white,
          size: 32,
        ),
      ),
    );
  }

  // 字幕按钮
  Widget _buildSubtitleButton() {
    final settings = ref.watch(subtitleSettingsProvider);
    final hasSubtitles = _subtitleTracks.isNotEmpty;
    final subtitleEnabled = settings.enabled;
    
    return GestureDetector(
      onTap: () {
        _showSubtitleSelector();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: subtitleEnabled
              ? const Color(0xCC4CAF50) // 绿色背景（开启）
              : const Color(0x4D000000), // 半透明黑色（关闭）
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.subtitles,
              color: hasSubtitles
                  ? (subtitleEnabled ? Colors.white : Colors.white54)
                  : Colors.white24,
              size: 24,
            ),
            // 加载指示器
            if (_isLoadingSubtitles)
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // 显示字幕选择器
  void _showSubtitleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubtitleSelector(
        tracks: _subtitleTracks,
        selectedTrackId: ref.read(subtitleSettingsProvider).language,
        onSelected: (track) {
          if (track != null) {
            _loadSubtitleContent(track);
          } else {
            setState(() {
              _currentCues = [];
            });
          }
        },
      ),
    );
  }

  // 信息展开按钮
  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showInfoPanel = true;
          _isOverviewExpanded = !_isOverviewExpanded;
        });
        _startHideInfoTimer();
      },
      child: const Icon(
        Icons.info_outline,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // 静音按钮（圆形边框 + 旋转动画 + 缩略图）
  Widget _buildMuteButton({
    required bool isMuted,
    required bool isPlaying,
    String? embyServerUrl,
    String? token,
  }) {
    // 获取缩略图 URL
    final thumbnailUrl = widget.item.thumbnailUrl ??
        widget.item.primaryUrl(
          embyServerUrl: embyServerUrl,
          apiKey: token,
          maxWidth: 200,
        );

    return GestureDetector(
      onTap: () {
        final newMuted = !isMuted;
        ref.read(isMutedProvider.notifier).state = newMuted;
        // 设置视频静音状态
        if (_videoController != null) {
          _videoController!.setVolume(newMuted ? 0.0 : 1.0);
        }
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isMuted
                ? const Color(0xCCE91E63) // 红色边框（静音）
                : const Color(0xCC424242), // 灰色边框（正常）
            width: 3,
          ),
        ),
        child: ClipOval(
          child: RotationTransition(
            turns: _rotationController,
            child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    color: Colors.white.withOpacity(0.7),
                    colorBlendMode: BlendMode.modulate,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: Icon(
                        isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[800],
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
