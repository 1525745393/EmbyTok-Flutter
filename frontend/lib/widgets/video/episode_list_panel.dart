// 全屏播放器剧集列表面板
//
// 功能：
// 1. 显示当前季的剧集列表
// 2. 支持切换季（横向滚动标签）
// 3. 点击剧集跳转到播放
// 4. 高亮当前播放的剧集

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/logger.dart';
import '../../utils/safe_insets.dart';

/// 剧集列表面板（从底部滑出）
class EpisodeListPanel extends ConsumerStatefulWidget {
  const EpisodeListPanel({
    super.key,
    required this.currentItem,
    required this.onPlayEpisode,
  });

  /// 当前播放的剧集
  final MediaItem currentItem;

  /// 选择剧集后的回调：返回选中剧集和当前季完整剧集列表
  final void Function(MediaItem episode, List<MediaItem> seasonEpisodes)
      onPlayEpisode;

  @override
  ConsumerState<EpisodeListPanel> createState() => _EpisodeListPanelState();
}

class _EpisodeListPanelState extends ConsumerState<EpisodeListPanel> {
  List<MediaItem> _seasons = [];
  List<MediaItem> _episodes = [];
  String? _selectedSeasonId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final item = widget.currentItem;
    // 只有剧集类型才加载季列表
    if (item.seriesId == null) {
      // 非剧集：直接用当前播放列表
      setState(() {
        _episodes = ref.read(playbackListProvider).items;
      });
      return;
    }
    await _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      if (serverUrl == null || token == null) {
        throw Exception('未登录');
      }
      final repo = ref.read(mediaRepositoryProvider);
      final seasons = await repo.getSeasons(
        widget.currentItem.seriesId!,
        serverUrl: serverUrl,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        // 默认选中当前季
        final currentSeasonNo = widget.currentItem.parentIndexNumber;
        _selectedSeasonId = seasons
            .where((s) => s.indexNumber == currentSeasonNo)
            .firstOrNull
            ?.id;
        _selectedSeasonId ??= seasons.firstOrNull?.id;
      });
      if (_selectedSeasonId != null) {
        await _loadEpisodes(_selectedSeasonId!);
      } else {
        // 没有季列表，直接用播放列表
        setState(() {
          _episodes = ref.read(playbackListProvider).items;
          _loading = false;
        });
      }
    } catch (e) {
      AppLogger.warn('加载季列表失败', data: {'error': e.toString()});
      if (!mounted) return;
      setState(() {
        _error = '加载季列表失败';
        _episodes = ref.read(playbackListProvider).items;
        _loading = false;
      });
    }
  }

  Future<void> _loadEpisodes(String seasonId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final serverUrl = auth.embyServerUrl;
      final token = auth.token;
      if (serverUrl == null || token == null) {
        throw Exception('未登录');
      }
      final repo = ref.read(mediaRepositoryProvider);
      final resp = await repo.getEpisodes(
        widget.currentItem.seriesId!,
        seasonId: seasonId,
        limit: 100,
        serverUrl: serverUrl,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _episodes = resp.items;
        _loading = false;
      });
    } catch (e) {
      AppLogger.warn('加载剧集列表失败', data: {'error': e.toString()});
      if (!mounted) return;
      setState(() {
        _error = '加载剧集失败';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = SafeInsets.bottomOf(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentItem.seriesName ??
                                widget.currentItem.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.currentItem.parentIndexNumber != null)
                            Text(
                              _seasons.isNotEmpty && _selectedSeasonId != null
                                  ? '${_seasons.where((s) => s.id == _selectedSeasonId).firstOrNull?.title ?? "第${widget.currentItem.parentIndexNumber}季"}'
                                  : '第 ${widget.currentItem.parentIndexNumber} 季 · '
                                      '第 ${widget.currentItem.indexNumber ?? '?'} 集',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 季选择器
              if (_seasons.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _seasons.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final season = _seasons[index];
                      final selected = season.id == _selectedSeasonId;
                      return ChoiceChip(
                        label: Text(
                          season.title.isNotEmpty
                              ? season.title
                              : '第${season.indexNumber ?? index + 1}季',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) {
                          if (_selectedSeasonId != season.id) {
                            setState(() => _selectedSeasonId = season.id);
                            _loadEpisodes(season.id);
                          }
                        },
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Colors.white12,
                      );
                    },
                  ),
                ),
              const Divider(color: Colors.white24, height: 1),
              // 剧集列表
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      )
                    : _error != null && _episodes.isEmpty
                        ? Center(
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.white54)),
                          )
                        : _episodes.isEmpty
                            ? const Center(
                                child: Text('暂无剧集',
                                    style: TextStyle(color: Colors.white54)),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.only(bottom: safeBottom),
                                itemCount: _episodes.length,
                                itemBuilder: (context, index) {
                                  final ep = _episodes[index];
                                  final isCurrent =
                                      ep.id == widget.currentItem.id;
                                  return _EpisodeTile(
                                    episode: ep,
                                    isCurrent: isCurrent,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      widget.onPlayEpisode(ep, _episodes);
                                    },
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.isCurrent,
    required this.onTap,
  });

  final MediaItem episode;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final epNum = episode.indexNumber ?? 0;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$epNum',
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white70,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      title: Text(
        episode.title,
        style: TextStyle(
          color: isCurrent ? Colors.white : Colors.white70,
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: episode.overview != null && episode.overview!.isNotEmpty
          ? Text(
              episode.overview!,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: isCurrent
          ? const Icon(Icons.play_arrow, color: Colors.white, size: 20)
          : null,
    );
  }
}

/// 显示剧集列表面板
void showEpisodeListPanel(
  BuildContext context,
  MediaItem currentItem, {
  required void Function(MediaItem episode, List<MediaItem> seasonEpisodes)
      onPlayEpisode,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => EpisodeListPanel(
      currentItem: currentItem,
      onPlayEpisode: onPlayEpisode,
    ),
  );
}
