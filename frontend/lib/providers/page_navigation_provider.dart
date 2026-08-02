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
  /// 覆盖层页面（搜索/历史）虽然主体 IndexedStack 仍展示 Feed（currentIndex=feed），
  /// 但用户实际关注的是覆盖层内容，Feed 视频不应继续在后台播放。
  /// 因此 isOverlayPage=true 时 isFeedVisible=false，会触发视频暂停。
  /// 真正的"Feed 不可见"也包括切到 Favorites/Actors/Settings 等其他 Tab。
  ///
  /// HomeScaffold 用此判定是否需要暂停 Feed 中的视频播放。
  bool get isFeedVisible => currentIndex == PageIndices.feed;
}

// 页面导航 Notifier
class PageNavigationNotifier extends StateNotifier<PageNavigationState> {
  PageNavigationNotifier() : super(const PageNavigationState()) {
    _load();
  }

  // 异步加载上次保存的 Tab 索引。
  //
  // 设计说明：_load 是异步的，应用启动时 state 初始为 Feed (index=0)，
  // _load 完成后（通常 <50ms）更新为保存的索引。
  // 此期间用户可能短暂看到 Feed 后跳转到恢复的 Tab，这是已知行为。
  // 覆盖层页面（search/history）不在此恢复，因为它们是临时操作不应持久化。
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(kStorageKeyLastPageIndex);
      if (index != null &&
          index >= PageIndices.feed &&
          index <= PageIndices.settings) {
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
  //
  // 注意：不调用 _saveIndex，因为覆盖层是临时操作，不应在下次启动时恢复。
  // 用户下次启动应回到上次的主 Tab（Feed/Favorites/Actors/Settings）。
  void goToSearch() {
    state = const PageNavigationState(
      currentIndex: PageIndices.search,
      isOverlayPage: true,
    );
  }

  // 切换到历史页面（覆盖层）
  //
  // 注意：同 goToSearch，不持久化覆盖层索引。
  void goToHistory() {
    state = const PageNavigationState(
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
final pageNavigationNotifierProvider = Provider<PageNavigationNotifier>(
    (ref) => ref.watch(pageNavigationProvider.notifier));
