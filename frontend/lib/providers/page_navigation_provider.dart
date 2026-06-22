// 页面导航 Provider：管理底部导航栏的当前页面索引
// 用于在 FeedView 顶部操作栏和 HomeScaffold 之间共享页面切换状态

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 页面索引常量
class PageIndices {
  static const int feed = 0;
  static const int favorites = 1;
  static const int settings = 2;
  static const int search = 3;
  static const int history = 4;
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
}

// 页面导航 Notifier
class PageNavigationNotifier extends StateNotifier<PageNavigationState> {
  PageNavigationNotifier() : super(const PageNavigationState());

  // 切换到底部导航栏的页面
  void goToPage(int index) {
    state = PageNavigationState(currentIndex: index, isOverlayPage: false);
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
