// 标准模式根组件：承载视频流/网格视图，以及所有用户偏好状态
//（Task 1 新增）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_preferences.dart';
import 'feed_view.dart';

// 标准模式根组件：在 Task 2 中会被扩展为承载 feedType / viewMode 等
// 当前实现：显示顶部工具栏（占位）+ FeedView
class StandardRootView extends ConsumerStatefulWidget {
  const StandardRootView({super.key});

  @override
  ConsumerState<StandardRootView> createState() => _StandardRootViewState();
}

class _StandardRootViewState extends ConsumerState<StandardRootView> {
  // Task 2 中将被扩展为完整的应用级状态（feedType/viewMode/isMuted 等）
  // 目前这里只用来确保启动时进行一次偏好加载，以便后续 Provider 可以读取。
  @override
  void initState() {
    super.initState();
    // 预热一次偏好，确保首次需要时可以快速读取
    _ensurePreferencesLoaded();
  }

  Future<void> _ensurePreferencesLoaded() async {
    try {
      await const AppPreferencesService().load();
    } catch (_) {
      // 忽略，不会阻塞 UI
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当前直接显示 FeedView（Task 3 会增加顶部工具栏和视图切换支持）
    return const FeedView();
  }
}
