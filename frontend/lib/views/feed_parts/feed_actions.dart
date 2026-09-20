// 从 feed_view.dart 拆分（part 文件，无行为变化）

part of '../feed_view.dart';

// ==================== _FeedActions ====================

extension _FeedActions on _FeedViewState {
  void _jumpToPageWhenReady(int targetIndex, {int retryCount = 0}) {
    if (!mounted) return;
    if (retryCount > 30) return;

    if (_pageController.hasClients) {
      _currentIndex = targetIndex;
      _currentIndexNotifier.value = targetIndex;
      _pageController.jumpToPage(targetIndex);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToPageWhenReady(targetIndex, retryCount: retryCount + 1);
    });
  }

  Future<bool> _jumpToPageWhenReadyAsync(int targetIndex) async {
    for (int i = 0; i < 30; i++) {
      if (!mounted) return false;
      if (_pageController.hasClients) {
        _currentIndex = targetIndex;
        _currentIndexNotifier.value = targetIndex;
        _pageController.jumpToPage(targetIndex);
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  bool _jumpToPageByIndex(int targetIndex) {
    if (!mounted || !_pageController.hasClients) return false;
    _currentIndex = targetIndex;
    _currentIndexNotifier.value = targetIndex;
    _pageController.jumpToPage(targetIndex);
    return true;
  }

  void _animateToPage(int targetIndex) {
    if (!mounted || !_pageController.hasClients) return;
    if (targetIndex < 0) return;
    final items = ref.read(videoListProvider).items;
    if (targetIndex >= items.length) return;
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<bool> _restoreFeedVideoIndex() async {
    // F4：非视频流模式不恢复。ViewModeNotifier._load 从 SharedPreferences
    // 异步读取，启动早期 state 为默认 feed——grid 用户重启后若在此误判，
    // 会在 offstage PageView 上恢复跳转，导致后台激活播放器。先等加载完成。
    final vm = ref.read(viewModeProvider.notifier);
    for (int i = 0; i < 20 && !vm.loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return false;
    }
    if (ref.read(viewModeProvider) != ViewMode.feed) return false;

    // F2：深层链接直接进入指定视频，不恢复历史位置
    final initialId = widget.initialItemId;
    if (initialId != null && initialId.isNotEmpty) return false;

    // 等待视频列表加载完成后再恢复位置
    // 最多等待 10 秒，避免无限等待；加载失败/空列表时提前退出，
    // 避免每次启动空耗 10 秒再放弃
    int attempts = 0;
    while (attempts < 20) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;

      final videoState = ref.read(videoListProvider);
      if (videoState.error != null) return false;
      if (videoState.items.isNotEmpty && !videoState.isLoading) {
        break;
      }
      attempts++;
    }

    if (!mounted) return false;

    final pos = await _viewModel.restoreFeedVideoPosition();
    if (!mounted) return false;

    final videoState = ref.read(videoListProvider);
    if (videoState.items.isEmpty) return false;

    // F3：优先按保存的视频 id 精确定位。
    // - 保存了 itemId 但当前列表找不到（换库/列表重排/内容变化）→ 不恢复，
    //   避免按旧 index 跳到错误视频；
    // - 仅老数据（无 itemId）时按 index 近似恢复。
    int targetIndex = -1;
    final savedItemId = pos.itemId;
    if (savedItemId != null && savedItemId.isNotEmpty) {
      final byId = videoState.items.indexWhere((i) => i.id == savedItemId);
      if (byId >= 0) {
        targetIndex = byId;
      } else {
        // 保存了 id 但当前列表找不到：不按 index 回退（避免跳错视频）
        return false;
      }
    } else if (pos.index > 0) {
      targetIndex = pos.index.clamp(0, videoState.items.length - 1);
    }
    if (targetIndex <= 0) return false;

    if (targetIndex != _currentIndex) {
      // F5：等 PageController attach 后跳转（带重试），并返回真实跳转结果；
      // 跳转失败视为未恢复，由调用方回退到「播放列表第一个视频」，
      // 避免「返回 true 但页面停在 index 0 且不播第一个」的黑屏态。
      final jumped = await _jumpToPageWhenReadyAsync(targetIndex);
      if (jumped) _feedPositionReady = true;
      return jumped;
    }
    _feedPositionReady = true;
    return true;
  }

  void _onScrollingChanged() {
    try {
      final isScrolling = _pageController.position.isScrollingNotifier.value;
      ref.read(isPageScrollingProvider.notifier).state = isScrolling;
    } catch (_) {
      // dispose 后访问 position 可能抛错，忽略
    }
  }

  void _hideSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  void _restoreSystemBars() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _saveFeedPositionOnBackground() {
    if (!mounted) return;
    final viewMode = ref.read(viewModeProvider);
    if (viewMode == ViewMode.grid) {
      if (_gridScrollController.hasClients) {
        safeUnawaited(_saveGridOffsetNow(),
            context: 'FeedView._saveGridOffsetNow');
      }
      return;
    }
    // P2：恢复完成/主动翻页前不写盘，避免覆盖已持久化的上次位置
    if (!_feedPositionReady) return;
    if (viewMode != ViewMode.feed) return;
    final videoState = ref.read(videoListProvider);
    if (videoState.items.isEmpty) return;
    final idx = _currentIndex;
    if (idx < 0 || idx >= videoState.items.length) return;
    safeUnawaited(
      _viewModel.saveFeedVideoIndexNow(idx, videoState.items),
      context: 'FeedView._saveFeedPositionOnBackground',
    );
  }

  Future<void> _restoreGridPosition() async {
    // 等待网格 attach + 首屏数据渲染
    int attempts = 0;
    while (attempts < 40) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      if (_gridScrollController.hasClients &&
          _gridScrollController.position.maxScrollExtent > 0) {
        break;
      }
      attempts++;
    }
    if (!mounted || !_gridScrollController.hasClients) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final target = await FeedViewModel.readGridScrollOffset(prefs);
    if (!mounted) return;
    if (target == null) return;

    // 目标超出已加载范围：逐级加载更多直到可滚动高度覆盖目标
    var guard = 0;
    while (mounted && _gridScrollController.hasClients) {
      final maxExtent = _gridScrollController.position.maxScrollExtent;
      if (maxExtent >= target) break;
      final videoState = ref.read(videoListProvider);
      if (!videoState.hasMore || videoState.isLoading) break;
      await ref.read(videoListProvider.notifier).loadMore();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      guard++;
      if (guard > 30) break; // 最多加载 30 轮，防异常死循环
    }
    if (!mounted || !_gridScrollController.hasClients) return;

    await _viewModel.restoreGridScrollOffset(
      getMaxScrollExtent: () => _gridScrollController.position.maxScrollExtent,
      onRestored: (offset) {
        if (mounted && _gridScrollController.hasClients) {
          _gridScrollController.jumpTo(offset);
          // 恢复滚动后同步一次 anchor，保证 grid → feed 切换定位一致
          _updateGridAnchorVideo();
        }
      },
    );
  }

  Future<void> _saveGridOffsetNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await FeedViewModel.saveGridScrollOffsetNow(
          prefs, _gridScrollController.offset);
    } catch (_) {
      // 操作失败不影响主流程
    }
  }

  void _onGridScrollChanged() {
    _viewModel.saveGridScrollOffset(() => _gridScrollController.offset);
    _maybeLoadMoreForGrid();
    _updateGridAnchorVideo();
  }

  void _updateGridAnchorVideo() {
    final controller = _gridScrollController;
    final videoState = ref.read(videoListProvider);
    final items = videoState.gridItems;
    if (!controller.hasClients || items.isEmpty) return;
    final position = controller.position;

    // 与 PosterGridView._scrollToGridIndex 保持同一套布局参数
    final viewportWidth = MediaQuery.of(context).size.width;
    const padding = 8.0;
    const crossAxisSpacing = 8.0;
    const mainAxisSpacing = 8.0;
    const crossAxisCount = 3;
    const childAspectRatio = 0.65;
    final availableWidth =
        viewportWidth - padding * 2 - (crossAxisCount - 1) * crossAxisSpacing;
    final itemWidth = availableWidth / crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;
    final rowHeight = itemHeight + mainAxisSpacing;

    // 视口中心 → 行 → 中间列索引
    final centerOffset = position.pixels + position.viewportDimension / 2;
    final row = (centerOffset / rowHeight).floor().clamp(0, 1 << 30);
    final index = (row * crossAxisCount + 1).clamp(0, items.length - 1);
    _viewModel.gridAnchorVideoId = items[index].id;
  }

  void _jumpToGridAnchorInFeed() {
    final anchorId = _viewModel.gridAnchorVideoId;
    if (anchorId == null || anchorId.isEmpty) return;
    var videoState = ref.read(videoListProvider);
    if (videoState.items.isEmpty) return;
    var idx = videoState.items.indexWhere((i) => i.id == anchorId);
    if (idx < 0 && !identical(videoState.items, videoState.gridItems)) {
      // 分页/搜索后 gridItems 独立：同步 items 为 gridItems 再定位
      ref.read(videoListProvider.notifier).setItemsFromGrid();
      videoState = ref.read(videoListProvider);
      idx = videoState.items.indexWhere((i) => i.id == anchorId);
    }
    if (idx < 0 || idx == _currentIndex) return;
    // 等 PageController attach 后跳页（带重试）；跳页触发 onPageChanged
    // → syncCurrentPlaying → playbackState 更新 → 网格高亮/视频流播放对齐
    _jumpToPageWhenReady(idx);
  }

  void _maybeLoadMoreForGrid() {
    final controller = _gridScrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final remaining = maxExtent - position.pixels;
    if (remaining > position.viewportDimension * 3) return;

    final videoState = ref.read(videoListProvider);
    if (!videoState.hasMore || videoState.isLoading) return;

    // 防抖：连续滚动只触发一次
    _gridLoadMoreDebounce?.cancel();
    _gridLoadMoreDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(videoListProvider.notifier).loadMore();
    });
  }

  bool _handleKeyEvent(KeyEvent event) => _viewModel.handleKeyEvent(event);

  void _showSnackBar(String message,
      {String? actionLabel, void Function()? onAction}) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: actionLabel != null
            ? const Duration(seconds: 6)
            : const Duration(seconds: 1),
        backgroundColor:
            actionLabel != null ? null : scheme.surface.withValues(alpha: 0.9),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  Future<void> _openFullscreenPage() async {
    final success = await FullscreenNavigator.open(
      ref: ref,
      context: context,
      onExit: () {
        if (mounted) {
          ref.read(toolbarVisibilityProvider.notifier).show();
        }
      },
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('视频正在准备中，请稍后'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
