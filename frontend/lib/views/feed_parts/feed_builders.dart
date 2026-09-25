// 从 feed_view.dart 拆分（part 文件，无行为变化）

part of '../feed_view.dart';

// ==================== _FeedBuilders ====================

extension _FeedBuilders on _FeedViewState {
  Widget _buildTopBar(ViewMode viewMode) {
    final scheme = Theme.of(context).colorScheme;
    // 全面屏适配：沉浸式下 SafeArea.top = 0，必须用 SafeInsets 取物理刘海高度。
    // 在刘海高度之上再加 8px 缓冲，保证按钮文字不与刘海下沿重叠。
    final topInset = SafeInsets.topOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(0, topInset + 8, 0, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface.withValues(alpha: 0.92),
            scheme.surface.withValues(alpha: 0.62),
            Colors.transparent,
          ],
        ),
      ),
      // SafeArea 保留：当不是沉浸式（如切到网格模式）时，提供一层兜底。
      // 外层 EdgeInsets 已提供物理刘海，内层 SafeArea 在非沉浸式下若
      // MediaQuery.padding.top > 0 会再加一点，双重保险不产生重复顶留白
      // （因为 topInset = max(padding.top, viewPadding.top)，在非沉浸式下
      // 两者接近相等，不会出现"加了 2 倍"的问题，安全）。
      child: SafeArea(
        bottom: false,
        top: false,
        child: _buildFeedTopBar(scheme, viewMode),
      ),
    );
  }

  Widget _buildFeedTopBar(ColorScheme scheme, ViewMode viewMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 当前媒体库标签
          _buildLibraryChip(scheme),
          _buildTopBarButton(
            icon: Icons.search,
            label: '搜索',
            onTap: () => ref.read(pageNavigationNotifierProvider).goToSearch(),
          ),
          _buildTopBarButton(
            icon: Icons.history,
            label: '历史',
            onTap: () => ref.read(pageNavigationNotifierProvider).goToHistory(),
          ),
          _buildTopBarButton(
            icon: Icons.auto_awesome,
            label: '推荐',
            onTap: () => context.push('/recommend'),
          ),
          _buildTopBarButton(
            icon: Icons.favorite,
            label: '关注',
            onTap: () => context.push('/follow'),
          ),
          _buildTopBarButton(
            icon: Icons.explore_outlined,
            label: '发现',
            onTap: () => context.push('/discover'),
          ),
          _buildTopBarButton(
            icon: Icons.play_circle_outline,
            label: '视频流',
            onTap: () {
              if (viewMode != ViewMode.feed) {
                ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
              }
            },
          ),
          _buildTopBarButton(
            icon: viewMode == ViewMode.feed
                ? Icons.grid_view
                : Icons.phone_android,
            label: viewMode == ViewMode.feed ? '网格' : '视频流',
            onTap: () {
              ref.read(viewModeProvider.notifier).setMode(
                    viewMode == ViewMode.feed ? ViewMode.grid : ViewMode.feed,
                  );
            },
          ),
        ],
      ),
    );
  }

  /// 媒体库标签栏：横向显示所有可见媒体库名称，点击临时筛选
  Widget _buildLibraryChip(ColorScheme scheme) {
    final libraries = ref.watch(visibleLibraryListProvider);
    final topBarFilter = ref.watch(topBarLibraryFilterProvider);
    if (libraries.isEmpty) return const SizedBox.shrink();

    final color = scheme.onSurface.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: libraries.map((lib) {
        // 顶栏筛选优先高亮；无筛选时高亮设置里选中的第一个
        final effectiveFilter = topBarFilter;
        final selected = effectiveFilter != null
            ? lib.id == effectiveFilter
            : false;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: () {
              // 点击顶栏标签：设置临时筛选（不改变设置里的媒体库选择）
              // 再次点击同一标签则取消筛选，恢复设置里的选择
              final current = ref.read(topBarLibraryFilterProvider);
              ref.read(topBarLibraryFilterProvider.notifier).state =
                  current == lib.id ? null : lib.id;
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lib.name,
                style: TextStyle(
                  color: selected ? scheme.primary : color,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurface.withValues(alpha: 0.85);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridPageView(VideoListState videoState) {
    return PosterGridView(scrollController: _gridScrollController);
  }

  Widget _buildVideoPageView(VideoListState videoState) {
    final error = videoState.error;
    final errorMsg = error?.message;
    if (videoState.items.isEmpty && videoState.isLoading) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              '正在加载视频...',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    if (videoState.items.isEmpty && errorMsg != null) {
      return ErrorStateCard(
        title: errorMsg,
        actionLabel: '重试',
        onAction: () {
          ref.read(videoListProvider.notifier).refresh();
        },
      );
    }
    // 追加失败时用 SnackBar 提示，不清除已有数据
    if (videoState.items.isNotEmpty && errorMsg != null) {
      final msg = errorMsg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              action: SnackBarAction(
                label: '重试',
                onPressed: () {
                  ref.read(videoListProvider.notifier).loadMore();
                },
              ),
            ),
          );
          ref.read(videoListProvider.notifier).clearError();
        }
      });
    }
    if (videoState.items.isEmpty) {
      return EmptyStateCard.noVideos();
    }

    final auth = ref.read(authProvider);
    final embyServerUrl = auth.embyServerUrl;
    final token = auth.token;

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        _currentIndex = index;
        _feedPositionReady = true;
        _currentIndexNotifier.value = index;
        // 切视频后临时显示位置计数 3 秒自动隐藏（非纯净模式）
        _showPositionBadgeTemporarily();
        // 关键修复：调用 setState 触发 PageView 重建，更新 isCurrentPage
        // 原问题：仅更新 _currentIndex 未触发重建，导致新页面 isCurrentPage 一直为 false
        // controller 不会被 play，视频画面不显示
        setState(() {});
        // 委托 ViewModel 处理业务逻辑
        final needLoadMore = _viewModel.onPageChanged(
          index,
          videoState.items,
          videoState.hasMore,
          videoState.isLoading,
        );
        if (needLoadMore) {
          ref.read(videoListProvider.notifier).loadMore();
        }
        // 防抖：页面静止后执行预加载和清理
        _pageChangeDebounce?.cancel();
        _pageChangeDebounce = Timer(const Duration(milliseconds: 200), () {
          _viewModel.onPageChangeSettled(index, videoState.items);
        });
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          final scheme = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: scheme.primary),
                const SizedBox(height: 12),
                Text(
                  '加载更多视频...',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }
        final item = videoState.items[index];
        // 从协调器取出预加载的会话
        final rawSession = _playbackCoordinator.takePreloadedSession(item.id);
        final preloadedSession =
            (rawSession != null && rawSession.isInitialized)
                ? rawSession
                : null;
        // 首次构建：当前视频由 VideoPlayerWidget 直接初始化，只预加载下一条
        if (index == 0 &&
            preloadedSession == null &&
            ref.read(videoPoolProvider).size == 0) {
          if (1 < videoState.items.length &&
              embyServerUrl != null &&
              token != null) {
            final nextItem = videoState.items[1];
            final pool = ref.read(videoPoolProvider);
            safeUnawaited(
              pool.preload(
                  item: nextItem, serverUrl: embyServerUrl, token: token),
              context: 'FeedView._buildFeedItem.preloadNext',
            );
          }
        }
        return RepaintBoundary(
          // 设置 ValueKey(item.id)：items 列表变化时让 PageView 按 id 复用 widget，
          // 避免出现「画面还在播旧视频，元信息是新视频」的鬼影过渡态。
          // 对齐 PlaybackShell（video_page_item.dart 第 1205 行）的实现。
          child: VideoPageItem(
            key: ValueKey(item.id),
            item: item,
            isCurrentPage: index == _currentIndex,
            preloadedSession: preloadedSession,
            onVideoEnded: _viewModel.onVideoEnded,
            startFromResumePosition: item.hasProgress,
            source: videoState.feedType == FeedType.resume ? 'resume' : 'feed',
          ),
        );
      },
    );
  }
}
