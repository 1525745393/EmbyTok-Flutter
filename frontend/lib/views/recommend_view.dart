// 推荐页面：独立路由 /recommend
//
// 背景（PR #57）：
// 推荐从 FeedType 中移除，改为独立路由 + 独立数据源。
// - 数据源：recommendProvider（StateNotifier）
// - 不与 video_list_provider / feed / grid 共享任何状态
// - 视频流中点"推荐"图标 → context.push('/recommend')
// - 推荐页点视频 → 进入视频流播放（context.go('/?initialId=...')）
//
// 特点：
// - 3 列网格布局（参考 PosterGridView）
// - 推荐内容是"个性化推荐 + 多库评分推荐"混合，一次性加载不分页
// - 包含独立 Scaffold + AppBar + 返回按钮

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/image_cache_manager.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/error_state_card.dart';
import '../widgets/library_selector.dart';
import '../widgets/skeleton_loading.dart';
part 'recommend_actions.dart';
part 'recommend_widgets.dart';

/// 推荐页面
class RecommendView extends ConsumerStatefulWidget {
  const RecommendView({super.key});

  @override
  ConsumerState<RecommendView> createState() => _RecommendViewState();
}

class _RecommendViewState extends ConsumerState<RecommendView> {
  // PR #79：滚动监听 - 滚到底部自动 loadMore
  late final ScrollController _scrollController;
  // P0-2：常驻搜索框（本地过滤，不触发网络）
  late final TextEditingController _searchController;
  String _searchQuery = '';
  // 搜索防抖：避免每次按键都触发整页重建
  Timer? _searchDebounce;
  // P2-2：网格列数（2/3），持久化到 SharedPreferences，对齐演员页
  int _gridColumns = 3;
  // 待恢复的滚动位置：initState 从磁盘读取，等首批数据加载完成后再恢复
  // （首帧是骨架屏，_scrollController 尚未附着，立即恢复会失效）
  double? _pendingScrollOffset;
  // 滚动位置只恢复一次，避免后续分页加载/刷新把列表强制拉回旧位置
  bool _scrollRestored = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // P0-2：搜索框文本变化 → 本地过滤（纯客户端，不请求服务器）
    // 添加防抖：延迟 300ms 更新搜索结果，避免每次按键都触发整页重建
    _searchController = TextEditingController();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _searchQuery = _searchController.text);
        }
      });
    });
    // P2-2：恢复用户上次选择的网格列数（2/3）
    // 滚动位置只读取、不在这里恢复：首帧是骨架屏（SkeletonGrid 不绑定
    // _scrollController），此时 hasClients=false，恢复会失效；
    // 改为等首批数据加载完成后在 ref.listen 中恢复（见 _tryRestoreScroll）
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt(kStorageKeyRecommendGridColumns);
      if (saved != null && (saved == 2 || saved == 3) && mounted) {
        setState(() => _gridColumns = saved);
      }
      if (mounted) {
        final savedOffset = prefs.getDouble(kStorageKeyRecommendScrollOffset);
        if (savedOffset != null && savedOffset > 0) {
          _pendingScrollOffset = savedOffset;
          // 同会话返回时数据仍在内存、GridView 已渲染，可立即尝试恢复；
          // 若仍是骨架屏（hasClients=false），会等数据加载监听再试
          _tryRestoreScroll();
        }
      }
    });
    // 首页顶栏「关注」入口：/recommend?tag=nextUp 自动选中追剧源
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 防御性读取：测试环境（无 GoRouter 路由栈）或非路由上下文
      // 下 GoRouterState.of 会抛异常，此时忽略 tag 参数
      String? tag;
      try {
        tag = GoRouterState.of(context).uri.queryParameters['tag'];
      } catch (_) {
        tag = null;
      }
      if (tag != null && tag.isNotEmpty) {
        ref.read(recommendProvider.notifier).selectTag(tag);
      }
    });

    // PR #66：首次未配置推荐媒体库 → 强制弹 LibrarySelector 让用户选一次
    // 监听 libraryListProvider 加载完成（不打断首帧）
    // 修复：用 ensureLoaded() 等待 _load() 异步 I/O 完成，
    // 而非 addPostFrameCallback（后者不等异步 I/O，会读到初始值 false）
    ref.listenManual<AsyncValue<List<Library>>>(libraryListProvider,
        (prev, next) {
      next.whenData((_) {
        ref
            .read(recommendLibraryConfiguredProvider.notifier)
            .ensureLoaded()
            .then((_) {
          if (!mounted) return;
          final configured = ref.read(recommendLibraryConfiguredProvider);
          if (configured) return;
          // 媒体库列表已加载但用户没配置过 → 弹 LibrarySelector
          LibrarySelector.show(context, scope: LibraryScope.recommend);
        });
      });
    });

    // 监听推荐页错误状态变化，error 非空时弹 SnackBar 提示
    // 使用 ref.listenManual 在 initState 中注册（Riverpod 推荐模式），
    // 而非在 build 中调用 _maybeShowError，避免每次 rebuild 重复注册 postFrameCallback。
    // ref.listenManual 订阅在 widget dispose 时自动关闭，无需手动 close。
    ref.listenManual<RecommendState>(recommendProvider, (prev, next) {
      // 首批数据从无到有时，尝试恢复上次的滚动位置
      final wasEmpty = prev?.taggedItems.isEmpty ?? true;
      if (!_scrollRestored && wasEmpty && next.taggedItems.isNotEmpty) {
        _tryRestoreScroll();
      }
      final error = next.error;
      if (error == null || error.isEmpty) return;
      // 等到下一帧再弹 SnackBar，避免 build 期间触发 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(recommendProvider.notifier).clearError();
      });
    });
  }

  @override
  void dispose() {
    // 保存滚动位置（offset 在同步阶段捕获，避免 controller dispose 后读取）
    if (_scrollController.hasClients) {
      _saveScrollOffset(_scrollController.offset);
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // 持久化滚动位置（fire-and-forget，写入失败静默忽略）
  Future<void> _saveScrollOffset(double offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(kStorageKeyRecommendScrollOffset, offset);
    } catch (_) {
      // 保存失败不影响退出流程
    }
  }

  // 恢复上次滚动位置。在两种时机调用：
  // 1) SharedPreferences 读到磁盘位置后（覆盖同会话返回、数据仍在内存）
  // 2) 首批数据异步加载完成（ref.listen 检测到 taggedItems 从空→非空）
  // 仅当目标位置不超过当前内容范围时恢复，避免被 clamp 到错误位置。
  void _tryRestoreScroll() {
    if (_scrollRestored) return;
    final target = _pendingScrollOffset;
    // 磁盘位置尚未读到：本次跳过且不标记完成，等 prefs 回调再次触发
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollRestored) return;
      // GridView 尚未渲染（仍是骨架屏）：跳过，等数据加载监听再次触发
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      // 内容不足以到达目标位置（如重启后只加载了第一页）：放弃恢复，
      // 停留在顶部，避免 animateTo 被 clamp 到当前列表底部造成错位
      if (target > maxExtent + 1) {
        _scrollRestored = true;
        _pendingScrollOffset = null;
        return;
      }
      _scrollRestored = true;
      _pendingScrollOffset = null;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // PR #79：分页 - 距底 200px 时触发 loadMore
  // 避免用户看到空白再加载，提升体验
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 距底 < 200px 时触发
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final state = ref.read(recommendProvider);
      if (state.hasMore && !state.isLoadingMore && !state.isLoading) {
        ref.read(recommendProvider.notifier).loadMore();
      }
      // 预加载下一页海报图片
      _preloadNextPageImages(state);
    }
  }

  // 预加载当前页末尾的海报图片，提升滚动流畅度
  void _preloadNextPageImages(RecommendState state) {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    final serverUrl = auth.embyServerUrl;
    final token = auth.token;
    if (serverUrl == null || token == null) return;

    // 预加载当前页末尾 10 个图片（下一页内容还未加载到 items 中）
    final items = state.taggedItems;
    final preloadStart = items.length > 10 ? items.length - 10 : 0;

    for (var i = preloadStart; i < items.length; i++) {
      final item = items[i].item;
      final imageUrl = item.primaryUrl(
        embyServerUrl: serverUrl,
        apiKey: token,
        maxWidth: 500,
      );
      if (imageUrl != null) {
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) => _buildPage(context);

  // P1-1：错误态卡片 —— 根据错误类型展示不同 CTA，避免用户看完文案无下一步可走

  // P1-1：空态卡片 —— 未配置媒体库时引导选择，否则引导刷新

  // PR #80：横向标签分类栏
  // - 显示 6 个标签：全部 / 追剧 / 续看 / 为你推荐 / 相似 / 高分
  // - 选中时高亮（scheme.primary 背景）
  // - 横向可滚动（不溢出）
  // - 点击切换 → state.selectedTag 变化 → view 自动 rebuild

  // PR #79：冷启动 Banner
  // - 提示用户"先观看几个视频，推荐会更准"
  // - 显示在推荐页顶部，仅 isColdStart=true 时出现

  // 跳转到独立播放页（/play/:itemId）
  //
  // PR #63 修复：之前 context.go('/?initialId=item.id') 跳到首页视频流，
  // 但推荐页是独立数据源（Emby Suggestions + 多库评分推荐），推荐 video
  // 不在 video_list.items 中 → FeedView._waitForInitialItemToLoad 找不到
  // → loadMore 100 次（约 5 秒）超时 → 用户看到的不是推荐 video
  //
  // 现在改用 /play/:itemId 独立播放页（[PlaybackShell]），用推荐页的 items
  // 作为滑动列表，用户在播放页可以左右滑动看其他推荐 video。
  //
  // PR #83：传 source 标签（nextUp/resume/...）用于完播率统计门控
}
/// PR #80：标签分类 - 单个标签的信息（label + sourceKey + count）
