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
  bool _hasInitializedLibrary = false;

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

  // 选择媒体库：刷新视频列表
  Future<void> _selectLibrary(Library lib) async {
    ref.read(selectedLibraryIdProvider.notifier).state = lib.id;
    await ref.read(videoListProvider.notifier).refresh(
          libraryId: lib.id,
          libraryType: lib.collectionType, // 传递类型给排序策略
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 媒体库列表（异步加载）
    final librariesAsync = ref.watch(libraryListProvider);

    // 加载成功后：自动选择第一个媒体库（仅在首次加载时执行一次）
    librariesAsync.when(
      loading: () {},
      error: (_, __) {},
      data: (libraries) {
        if (libraries.isNotEmpty && !_hasInitializedLibrary) {
          _hasInitializedLibrary = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _selectLibrary(libraries.first);
            }
          });
        }
      },
    );

    // 视频列表状态
    final videoState = ref.watch(videoListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主体：竖向 PageView 视频流
          _buildVideoPageView(videoState),
          // 顶部：媒体库切换器（覆盖在视频流之上）
          Positioned(
            left: 0,
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
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '暂无视频，请选择其他媒体库',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
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
        return VideoPageItem(item: item);
      },
    );
  }

  // 将原始错误信息转换为用户友好的中文提示
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('token') ||
        lower.contains('unauthorized') ||
        lower.contains('expired') ||
        lower.contains('invalid')) {
      return '登录信息已过期，请重新登录';
    }
    if (lower.contains('unreachable') || lower.contains('无法连接')) {
      return '无法连接到服务器，请检查网络';
    }
    if (lower.contains('timeout') || lower.contains('超时')) {
      return '请求超时，请重试';
    }
    if (lower.contains('尚未登录')) {
      return '尚未登录';
    }
    return raw;
  }

  // 视频流的错误提示 UI
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
              _friendlyError(error),
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
            Colors.black54,
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: librariesAsync.when(
          // 加载中：显示加载指示器（不再隐藏）
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE91E63),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '加载媒体库中…',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // 错误：显示错误提示 + 重试按钮（不再隐藏）
          error: (error, stackTrace) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _friendlyError(error.toString()),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      // 刷新媒体库列表
                      ref.invalidate(libraryListProvider);
                    },
                    child: const Text(
                      '重试',
                      style: TextStyle(
                          color: Color(0xFFE91E63),
                          fontSize: 13,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            );
          },
          // 加载成功
          data: (libraries) {
            // 空列表
            if (libraries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '未找到媒体库',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              );
            }
            // 正常：显示横向切换栏
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
