// 页面导航 Provider：管理底部导航栏的当前页面索引
// 用于在 FeedView 顶部操作栏和 HomeScaffold 之间共享页面切换状态

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

// 页面索引常量
class PageIndices {
  static const int feed = 0;
  static const int favorites = 1;
  static const int actors = 2;
  static const int settings = 3;
  static const int search = 4;
  static const int history = 5;
}

// 页面导航状态
class PageNavigationState {
  final int currentIndex;
  final bool isOverlayPage; // 标记是否是覆盖层页面（搜索/历史）

  const PageNavigationState({
    this.currentIndex = PageIndices.feed,
    this.isOverlayPage = false,
  });

  PageNavigationState copyWith({
    int? currentIndex,
    bool? isOverlayPage,
  }) {
    return PageNavigationState(
      currentIndex: currentIndex ?? this.currentIndex,
      isOverlayPage: isOverlayPage ?? this.isOverlayPage,
    );
  }

  /// 当前导航状态下 Feed Tab 是否对用户"实际可见"
  ///
  /// 覆盖层页面（搜索/历史）显示在 Feed 之上，主体 IndexedStack 仍展示
  /// Feed（currentIndex=feed），所以 isOverlayPage=true 时 Feed 仍视为可见。
  /// 真正的"Feed 不可见"是切到 Favorites/Actors/Settings 等其他 Tab。
  ///
  /// HomeScaffold 用此判定是否需要暂停 Feed 中的视频播放。
  bool get isFeedVisible => currentIndex == PageIndices.feed;
}

// 页面导航 Notifier
class PageNavigationNotifier extends StateNotifier<PageNavigationState> {
  PageNavigationNotifier() : super(const PageNavigationState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(kStorageKeyLastPageIndex);
      if (index != null && index >= PageIndices.feed && index <= PageIndices.settings) {
        state = PageNavigationState(currentIndex: index, isOverlayPage: false);
      }
    } catch (_) {}
  }

  Future<void> _saveIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyLastPageIndex, index);
    } catch (_) {}
  }

  // 切换到底部导航栏的页面
  void goToPage(int index) {
    state = PageNavigationState(currentIndex: index, isOverlayPage: false);
    if (index >= PageIndices.feed && index <= PageIndices.settings) {
      _saveIndex(index);
    }
  }

  // 切换到搜索页面（覆盖层）
  void goToSearch() {
    state = PageNavigationState(
      currentIndex: PageIndices.search,
      isOverlayPage: true,
    );
  }

  // 切换到历史页面（覆盖层）
  void goToHistory() {
    state = PageNavigationState(
      currentIndex: PageIndices.history,
      isOverlayPage: true,
    );
  }

  // 返回到 Feed 页面
  void backToFeed() {
    state = const PageNavigationState(
      currentIndex: PageIndices.feed,
      isOverlayPage: false,
    );
    _saveIndex(PageIndices.feed);
  }
}

// 页面导航 Provider
final pageNavigationProvider =
    StateNotifierProvider<PageNavigationNotifier, PageNavigationState>(
  (ref) => PageNavigationNotifier(),
);

// 只暴露 Notifier 的 Provider（用于修改状态）
final pageNavigationNotifierProvider =
    Provider<PageNavigationNotifier>((ref) => ref.watch(pageNavigationProvider.notifier));
