// 从 item_detail_view.dart 拆分（part 文件，无行为变化）

part of 'item_detail_view.dart';

// ==================== 详情数据加载 / 播放 / 收藏 ====================

extension _ItemDetailLoaders on _ItemDetailViewState {
  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final currentItem = _item;
      MediaItem item;
      if (currentItem != null && currentItem.id == widget.itemId) {
        item = currentItem;
      } else {
        // 通过缓存仓库获取，减少重复 API 请求
        final cachedRepo = ref.read(cachedMediaRepositoryProvider);
        item = await cachedRepo.getItemDetail(
          widget.itemId,
          serverUrl: auth.embyServerUrl!,
          token: auth.token!,
          userId: auth.user?.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
      // 剧集类：加载季列表
      if (item.type == 'Series') {
        await _loadSeasons(item.id);
      }
      // 异步加载相似推荐（不阻塞主流程）
      _loadSimilarItems(item.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSeasons(String seriesId) async {
    try {
      final auth = ref.read(authProvider);
      final cachedRepo = ref.read(cachedMediaRepositoryProvider);
      final seasons = await cachedRepo.getSeasons(
        seriesId,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        // 默认选中第一季（如果有）
        _selectedSeasonId = seasons.isNotEmpty ? seasons.first.id : null;
      });
      final seasonId = _selectedSeasonId;
      if (seasonId != null) {
        await _loadEpisodes(seriesId, seasonId);
      }
    } catch (e) {
      // 季列表加载失败不阻塞详情页展示，但记录日志便于排查
      AppLogger.warn('季列表加载失败', data: {
        'seriesId': seriesId,
        'error': e.toString(),
      });
    }
  }

  Future<void> _loadEpisodes(String seriesId, String seasonId) async {
    setState(() {
      _loadingEpisodes = true;
    });
    try {
      final auth = ref.read(authProvider);
      final cachedRepo = ref.read(cachedMediaRepositoryProvider);
      final resp = await cachedRepo.getEpisodes(
        seriesId,
        seasonId: seasonId,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
      if (!mounted) return;
      setState(() {
        _episodes = resp.items;
        _loadingEpisodes = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _episodes = const <MediaItem>[];
          _loadingEpisodes = false;
        });
      }
    }
  }

  Future<void> _loadSimilarItems(String itemId) async {
    setState(() {
      _loadingSimilar = true;
    });
    try {
      final auth = ref.read(authProvider);
      final cachedRepo = ref.read(cachedMediaRepositoryProvider);
      final items = await cachedRepo.getSimilarItems(
        itemId,
        limit: 12,
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
      if (!mounted) return;
      setState(() {
        _similarItems = items;
        _loadingSimilar = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _similarItems = const <MediaItem>[];
          _loadingSimilar = false;
        });
      }
    }
  }

  void _selectSeason(String seasonId) {
    if (seasonId == _selectedSeasonId) return;
    setState(() {
      _selectedSeasonId = seasonId;
    });
    final item = _item;
    if (item != null) {
      _loadEpisodes(item.id, seasonId);
    }
  }

  void _playItem(MediaItem item) {
    // 设置播放列表后再跳转（剧集使用 _episodes 作为播放列表）
    final items = item.type == 'Episode' ? _episodes : [item];
    ref.read(playbackListProvider.notifier).setPlaybackList(items, item.id);
    context.push('/play/${item.id}', extra: item);
  }

  void _toggleFavorite() {
    final item = _item;
    if (item == null) return;
    ref.read(favoritesProvider.notifier).toggleFavorite(item);
  }
}
