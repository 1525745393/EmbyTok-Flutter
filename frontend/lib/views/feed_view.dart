// 视频流页面：竖向全屏滑动 + 顶部媒体库切换 + 分页加载

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/video_page_item.dart';

// 视频流页面：ConsumerStatefulWidget 用于分页加载 & 状态保持
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key});

  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with AutomaticKeepAliveClientMixin<FeedView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 选择媒体库：先更新 selectedLibraryId，再刷新视频列表
  Future<void> _selectLibrary(Library lib) async {
    ref.read(selectedLibraryIdProvider.notifier).state = lib.id;
    await ref.read(videoListProvider.notifier).refresh(libraryId: lib.id);
  }

  @override
  Widget build(BuildContext context) {
    // 调用 super.build 以便 AutomaticKeepAliveClientMixin 生效
    super.build(context);

    // 媒体库列表（异步）
    final librariesAsync = ref.watch(libraryListProvider);

    // 视频列表状态
    final videoState = ref.watch(videoListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主体：竖向 PageView 视频流
          _buildVideoPageView(videoState),
          // 顶部：媒体库切换器
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _buildLibraryChips(librariesAsync),
          ),
        ],
      ),
    );
  }

  // 构建视频流 PageView
  Widget _buildVideoPageView(VideoListState videoState) {
    // 加载中（首次加载）
    if (videoState.items.isEmpty && videoState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    // 错误状态
    if (videoState.items.isEmpty && videoState.error != null) {
      return _buildErrorState(videoState.error!);
    }

    // 空状态
    if (videoState.items.isEmpty) {
      return const Center(
        child: Text(
          '暂无视频，请选择其他媒体库',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    // 正常：竖向 PageView
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: videoState.items.length + (videoState.hasMore ? 1 : 0),
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
        // 滚动到倒数第 2 项时触发分页加载
        if (videoState.hasMore &&
            index >= videoState.items.length - 2 &&
            !videoState.isLoading) {
          ref.read(videoListProvider.notifier).loadMore();
        }
      },
      itemBuilder: (context, index) {
        // 末尾加载指示器
        if (index >= videoState.items.length) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE91E63)),
          );
        }
        final item = videoState.items[index];
        return VideoPageItem(
          item: item,
          onNextVideo: () {
            // 切换到下一个视频（如果有）
            if (index < videoState.items.length - 1) {
              _pageController.animateToPage(
                index + 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        );
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
            Text(
              error,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.black45,
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: librariesAsync.when(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE91E63)
                            : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE91E63)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        lib.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
