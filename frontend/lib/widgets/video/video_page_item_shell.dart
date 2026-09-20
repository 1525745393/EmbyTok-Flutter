// 从 video_page_item.dart 拆分（part 文件，无行为变化）

part of 'video_page_item.dart';

// ==================== 播放器外壳（队列循环/位置记忆） ====================

class _PlaybackShellState extends ConsumerState<PlaybackShell> {
  late PageController _pageController;
  int _currentIndex = 0;
  late List<MediaItem> _items;
  bool _isLoading = true;

  /// 播放位置记忆（离开播放页再返回时恢复上次视频索引）
  ///
  /// 结构：{ source: { 列表首itemId: { "idx": 索引, "last": 上次视频id } } }
  /// 恢复条件：同一数据源 + 同一列表（首 item 一致）→ 恢复到上次滑到的视频；
  /// 进度续播由 VideoPageItem.startFromResumePosition 基于 Emby 服务端位置完成。
  static const String _kPositionMemoryKey = kStorageKeyPlaybackShellPosition;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    _initItems();
    _preloadAround(_currentIndex);
    // 异步读取位置记忆，匹配到同一列表时恢复到上次滑到的视频
    _restoreFromMemory();
    // 进入播放页时立即隐藏系统栏，进入全屏沉浸式
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

  @override
  void dispose() {
    // 离开前保存当前播放位置（不 await，异步写盘）
    _savePosition();
    _pageController.dispose();
    // 离开播放页：返回 FeedView，需要保持沉浸式模式
    // 不恢复 edgeToEdge，因为目标页面（FeedView）也是沉浸式的
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  /// 当前列表的稳定签名：首 item id（同一列表内进入/返回时保持不变）
  String get _listSignature =>
      _items.isNotEmpty ? _items.first.id : widget.item.id;

  /// 从本地记忆恢复上次播放位置（仅当数据源与列表均匹配时）
  ///
  /// 点击目标优先：若本次点击的视频确实在列表中，直接播放点击的视频，
  /// 不被旧记忆覆盖（否则点 A 却播上次的 N）。记忆恢复仅作为兜底，
  /// 用于点击目标不在列表中的异常场景。
  Future<void> _restoreFromMemory() async {
    try {
      if (_items.any((i) => i.id == widget.item.id)) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPositionMemoryKey);
      if (raw == null || raw.isEmpty) return;
      final root = jsonDecode(raw);
      if (root is! Map<String, dynamic>) return;
      final bySource = root[widget.source];
      if (bySource is! Map<String, dynamic>) return;
      final entry = bySource[_listSignature];
      if (entry is! Map<String, dynamic>) return;
      final savedIdx = entry['idx'];
      if (savedIdx is! int || savedIdx <= 0) return;
      if (!mounted) return;
      final target = savedIdx.clamp(0, _items.length - 1);
      // 等 PageController attach 后跳转
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _currentIndex = target;
        _pageController.jumpToPage(target);
        AppLogger.debug('播放位置记忆：恢复到上次视频',
            data: {'source': widget.source, 'index': target});
      });
    } catch (e) {
      AppLogger.error('播放位置记忆恢复失败', error: e);
    }
  }

  /// 保存当前播放位置（数据源 + 列表签名 + 索引 + 当前视频 id）
  ///
  /// 点击进入即写盘（含 index 0）：用户点击了 A，返回网格时「上次看到」
  /// 必须定位到 A（与实际播放一致）。旧实现 index 0 不写，会导致点击
  /// 列表第一个视频后网格仍定位到旧记忆视频，两处不一致。
  ///
  /// 单视频列表（boxset 详情/收藏页等传 extra=item 不带 items 的入口）
  /// 不写盘：无滑动语义，且签名=被看视频自身 id，与网格读取方使用的
  /// 「列表首 item id」签名不匹配，写了也只是孤儿条目随观看量无限增长。
  Future<void> _savePosition() async {
    if (_items.length <= 1) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPositionMemoryKey);
      final root = (raw == null || raw.isEmpty)
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map<String, dynamic>? ?? {});
      final bySource =
          (root[widget.source] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final currentId = (_currentIndex >= 0 && _currentIndex < _items.length)
          ? _items[_currentIndex].id
          : widget.item.id;
      bySource[_listSignature] = {
        'idx': _currentIndex,
        'last': currentId,
      };
      root[widget.source] = bySource;
      await prefs.setString(_kPositionMemoryKey, jsonEncode(root));
    } catch (e) {
      AppLogger.error('播放位置记忆保存失败', error: e);
    }
  }

  void _initItems() {
    // 优先使用传入的列表，否则从 playbackListProvider 获取
    if (widget.items.isNotEmpty) {
      _items = widget.items;
      final initialIndex = _items.indexWhere((i) => i.id == widget.item.id);
      _currentIndex = initialIndex >= 0 ? initialIndex : 0;
      _isLoading = false;
      // 如果初始索引不是 0，滚动到对应位置
      if (initialIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(initialIndex);
          }
        });
      }
    } else {
      // 从 playbackListProvider 获取播放列表
      final playbackState = ref.read(playbackListProvider);
      if (playbackState.items.isNotEmpty) {
        _items = playbackState.items;
        final initialIndex = _items.indexWhere((i) => i.id == widget.item.id);
        _currentIndex = initialIndex >= 0 ? initialIndex : 0;
        _isLoading = false;
        if (initialIndex > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(initialIndex);
            }
          });
        }
      } else {
        // 如果列表为空，只播放当前视频
        _items = [widget.item];
        _currentIndex = 0;
        _isLoading = false;
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // 滑动后实时保存位置，离开时即使不触发 dispose 也有最新记录
    _savePosition();
    _preloadAround(index);
  }

  // 接入全局预加载池：预加载相邻视频并清理较远的会话，
  // 避免独立播放页长列表滑动时控制器数量无限增长（与 feed 行为一致）
  void _preloadAround(int index) {
    final auth = ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (serverUrl == null || token == null) return;
    final pool = ref.read(videoPoolProvider);
    Future<void> maybePreload(int i) async {
      if (i < 0 || i >= _items.length) return;
      final it = _items[i];
      if (!pool.hasSession(it.id)) {
        await pool.preload(item: it, serverUrl: serverUrl, token: token);
      }
    }

    // 预加载前后各 1 个视频
    safeUnawaited(maybePreload(index - 1),
        context: 'PlaybackShell.maybePreload.prev');
    safeUnawaited(maybePreload(index + 1),
        context: 'PlaybackShell.maybePreload.next');

    // 保留当前页 + 前后各 1 页的会话
    final keep = <String>[];
    if (index - 1 >= 0) keep.add(_items[index - 1].id);
    keep.add(_items[index].id);
    if (index + 1 < _items.length) keep.add(_items[index + 1].id);
    pool.evictExcept(keep);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // PageView 支持滑动切换视频
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final item = _items[index];
              // 复用全局预加载池中的会话（如存在且仍有效），否则回退动态创建
              final rawSession = ref.read(videoPoolProvider).take(item.id);
              final preloadedSession =
                  (rawSession != null && rawSession.isInitialized)
                      ? rawSession
                      : null;
              return VideoPageItem(
                key: ValueKey(item.id),
                item: item,
                isCurrentPage: index == _currentIndex,
                preloadedSession: preloadedSession,
                source: widget.source,
                onVideoEnded: index < _items.length - 1
                    ? () {
                        // 自动播放下一个
                        _pageController.nextPage(
                          duration: _kAnimationFast,
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                startFromResumePosition: item.hasProgress,
              );
            },
          ),
          // 返回按钮
          Positioned(
            // 顶部按钮需避开刘海（沉浸式下 padding 归零，用 SafeInsets 取物理高度）
            top: SafeInsets.topOf(context) + 8,
            left: 8,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: scheme.onSurface),
              onPressed: widget.onBack,
            ),
          ),
          // 当前位置指示器
          if (_items.length > 1)
            Positioned(
              // 同样需避开顶部刘海
              top: SafeInsets.topOf(context) + 8,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _kSpacingLarge, vertical: _kSpacingSmall),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_items.length}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: _kFontSizeBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
