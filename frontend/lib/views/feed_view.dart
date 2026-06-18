// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载 + 键盘快捷键 + 视图切换
// 新增：跨设备续播（通过 Emby DisplayPreferences 接口与其它设备/EmbyX 共享续播书签）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/embbytok_service.dart';
import '../utils/app_preferences.dart' show ViewMode, FeedType;
import '../utils/keyboard_shortcuts.dart';
import '../utils/logger.dart';
import '../widgets/library_selector.dart';
import '../widgets/poster_grid_view.dart';
import '../widgets/video_page_item.dart';

class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  bool _showHelp = false; // 快捷键帮助面板显示状态

  // 云同步（跨设备续播）相关
  final EmbytokService _cloudService = EmbytokService();
  MediaItem? _lastReportedItem;
  bool _cloudSyncChecked = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    // 注册全局键盘监听
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // 监听当前播放条目变化：切换到新视频时保存旧条目的续播信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listen<MediaItem?>(currentPlayingItemProvider, (prev, next) {
        _saveCloudSyncIfNeeded(next);
      });
    });
    // 跨设备续播：进入页面时检查其它设备是否存在续播信息
    _checkCloudSyncOnStartup();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _pageController.dispose();
    super.dispose();
  }

  // ========== 跨设备续播云同步 ==========

  // 启动时尝试拉取 DisplayPreferences 中的 "EmbyTok-Resume" 信息
  Future<void> _checkCloudSyncOnStartup() async {
    try {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated ||
          auth.embyServerUrl == null ||
          auth.token == null) {
        return;
      }
      final data = await _cloudService.checkCloudSync(
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      );
      if (data == null || data.isEmpty) return;
      final lastId = data['lastId'] as String?;
      final deviceName = (data['deviceName'] as String?) ?? '其他设备';
      _cloudSyncChecked = true;
      if (lastId == null || lastId.isEmpty) return;
      // 是否与当前条目相同
      final current = ref.read(currentPlayingItemProvider);
      if (current != null && current.id == lastId) return;
      // 在 UI 上展示：SnackBar 提示
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('从$deviceName 续播：继续播放此视频？'),
          action: SnackBarAction(
            label: '跳转',
            onPressed: () {
              _seekToItem(lastId);
            },
          ),
        ),
      );
    } catch (e) {
      AppLogger.debug('云同步检查失败', data: {'error': e.toString()});
    }
  }

  // 切换条目时：保存旧条目到云端，作为续播书签
  void _saveCloudSyncIfNeeded(MediaItem? newItem) {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated ||
        auth.embyServerUrl == null ||
        auth.token == null) return;
    final oldItem = _lastReportedItem;
    _lastReportedItem = newItem;
    if (oldItem == null) return;
    if (newItem != null && oldItem.id == newItem.id) return;
    // 异步 save，避免阻塞 UI
    unawaited(
      _cloudService.saveCloudSync(
        itemId: oldItem.id,
        libraryId: _currentLibraryId(),
        libraryType: '',
        serverUrl: auth.embyServerUrl!,
        token: auth.token!,
      ),
    );
  }

  // 工具：当前媒体库 ID（未选则为空字符串）
  String _currentLibraryId() {
    try {
      final libs = ref.read(libraryListProvider);
      if (!libs.hasValue || libs.value!.isEmpty) return '';
      // 拿第一个 libraryId（简化版；若有多个可以通过 selectedLibraryIdProvider 获取）
      final selected = ref.watch(selectedLibraryIdProvider);
      return selected?.id ?? libs.value!.first.id;
    } catch (_) {
      return '';
    }
  }

  // 根据 itemId 跳到对应视频（简单版：在 items 线性查找）
  void _seekToItem(String itemId) {
    final items = ref.read(videoListProvider).items;
    if (items.isEmpty) return;
    final idx = items.indexWhere((item) => item.id == itemId);
    if (idx < 0) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 键盘快捷键处理
  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    // 视图模式切换（E）
    final viewMode = ref.read(viewModeProvider);
    if (viewMode != ViewMode.feed) {
      // 网格模式下仅处理 E 键切换回视频流
      if (key == LogicalKeyboardKey.keyE) {
        ref.read(viewModeProvider.notifier).setMode(ViewMode.feed);
        return true;
      }
      return false;
    }

    switch (key) {
      case LogicalKeyboardKey.keyW:
      case LogicalKeyboardKey.arrowUp:
        _goToPreviousVideo();
        return true;
      case LogicalKeyboardKey.keyS:
      case LogicalKeyboardKey.arrowDown:
        _goToNextVideo();
        return true;
      case LogicalKeyboardKey.space:
        _togglePlayPause();
        return true;
      case LogicalKeyboardKey.keyA:
      case LogicalKeyboardKey.arrowLeft:
        // 快退 15 秒（占位：实际 seek 由 VideoPlayerWidget 通过 controller 执行）
        return true;
      case LogicalKeyboardKey.keyD:
      case LogicalKeyboardKey.arrowRight:
        // 快进 15 秒（占位：实际 seek 由 VideoPlayerWidget 通过 controller 执行）
        return true;
      case LogicalKeyboardKey.keyU:
        _toggleFavorite();
        return true;
      case LogicalKeyboardKey.keyE:
        ref.read(viewModeProvider.notifier).setMode(ViewMode.grid);
        return true;
      case LogicalKeyboardKey.keyR:
        _toggleFeedType();
        return true;
      case LogicalKeyboardKey.keyG:
        LibrarySelector.show(context);
        return true;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return true;
      case LogicalKeyboardKey.keyM:
        _toggleMute();
        return true;
      case LogicalKeyboardKey.slash:
        // 按 / 显示帮助面板
        setState(() => _showHelp = !_showHelp);
        return true;
      default:
        return false;
    }
  }

  // 切换到上一个视频
  void _goToPreviousVideo() {
    if (_pageController.hasClients && _pageController.page! > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 切换到下一个视频
  void _goToNextVideo() {
    final videoState = ref.read(videoListProvider);
    if (_pageController.hasClients &&
        _pageController.page! < videoState.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 暂停/播放切换
  void _togglePlayPause() {
    final isPlaying = ref.read(isPlayingProvider);
    ref.read(isPlayingProvider.notifier).state = !isPlaying;
  }

  // 收藏切换
  void _toggleFavorite() {
    final item = ref.read(currentPlayingItemProvider);
    if (item != null) {
      ref.read(favoritesProvider.notifier).toggleFavorite(item);
    }
  }

  // 切换浏览模式（最新/随机/收藏）
  void _toggleFeedType() {
    final current = ref.read(feedTypeProvider);
    final next = switch (current) {
      FeedType.latest => FeedType.random,
      FeedType.random => FeedType.favorites,
      FeedType.favorites => FeedType.latest,
    };
    ref.read(feedTypeProvider.notifier).setType(next);
    _showModeToast(next);
  }

  // 全屏切换
  void _toggleFullscreen() {
    if (MediaQuery.of(context).size.aspectRatio < 1) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  // 静音切换
  void _toggleMute() {
    final isMuted = ref.read(isMutedProvider);
    ref.read(isMutedProvider.notifier).setMuted(!isMuted);
  }

  // 显示浏览模式提示
  void _showModeToast(FeedType type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('切换到：${type.zhLabel}'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.black87,
      ),
    );
  }

  // 选择媒体库
  Future<void> _selectLibrary(Library lib) async {
    ref.read(selectedLibraryIdProvider.notifier).setLibrary(lib.id);
    await ref.read(videoListProvider.notifier).refresh(libraryId: lib.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final librariesAsync = ref.watch(libraryListProvider);
    final videoState = ref.watch(videoListProvider);
    final viewMode = ref.watch(viewModeProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主体内容：根据视图模式切换
          if (viewMode == ViewMode.feed)
            _buildVideoPageView(videoState)
          else
            const PosterGridView(),

          // 顶部：媒体库切换器 + 视图切换按钮
          Positioned(
            left: 0, right: 0, top: 0,
            child: _buildTopBar(librariesAsync, viewMode),
          ),

          // 快捷键帮助面板
          if (_showHelp)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showHelp = false),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: const KeyboardHelpPanel(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 顶部栏：媒体库切换 + 视图切换按钮
  Widget _buildTopBar(AsyncValue<List<Library>> librariesAsync, ViewMode viewMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.black45, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 媒体库切换器（横向滚动）
            Expanded(child: _buildLibraryChips(librariesAsync)),
            // 视图切换按钮
            IconButton(
              icon: Icon(
                viewMode == ViewMode.feed ? Icons.grid_view : Icons.phone_android,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: () {
                ref.read(viewModeProvider.notifier).setMode(
                  viewMode == ViewMode.feed ? ViewMode.grid : ViewMode.feed,
                );
              },
            ),
            // 媒体库选择器按钮（快捷键 G）
            IconButton(
              icon: const Icon(Icons.library_books, color: Colors.white70, size: 22),
              onPressed: () => LibrarySelector.show(context),
            ),
          ],
        ),
      ),
    );
  }

  // 构建视频流 PageView
  Widget _buildVideoPageView(VideoListState videoState) {
    if (videoState.items.isEmpty && videoState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
    }
    if (videoState.items.isEmpty && videoState.error != null) {
      return _buildErrorState(videoState.error!);
    }
    if (videoState.items.isEmpty) {
      return const Center(
        child: Text('暂无视频，请选择其他媒体库',
          style: TextStyle(color: Colors.white70, fontSize: 16)),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        if (videoState.hasMore && index >= videoState.items.length - 2 && !videoState.isLoading) {
          ref.read(videoListProvider.notifier).loadMore();
        }
      },
      itemBuilder: (context, index) {
        if (index >= videoState.items.length) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
        }
        final item = videoState.items[index];
        return VideoPageItem(item: item);
      },
    );
  }

  // 错误提示 UI
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final libId = ref.read(selectedLibraryIdProvider);
                ref.read(videoListProvider.notifier).refresh(libraryId: libId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  // 顶部媒体库横向切换器
  Widget _buildLibraryChips(AsyncValue<List<Library>> librariesAsync) {
    return librariesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (libraries) {
        if (libraries.isEmpty) return const SizedBox.shrink();
        final selectedId = ref.watch(selectedLibraryIdProvider);
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: libraries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final lib = libraries[index];
              final isSelected = lib.id == selectedId;
              return GestureDetector(
                onTap: () => _selectLibrary(lib),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE91E63) : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFFE91E63) : Colors.white24),
                  ),
                  child: Text(lib.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
