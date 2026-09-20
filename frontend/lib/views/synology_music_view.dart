// 群晖 Audio Station 音乐浏览页面（独立路由 /music）
//
// 功能：
// - 分类浏览：歌曲 / 专辑 / 歌手 / 歌单（按需加载）
// - 顶部搜索：SYNO.AudioStation.Search（歌曲 + 专辑 + 歌手）
// - 点击歌曲即播，底部 mini player 常驻控制
// - 专辑 / 歌单 / 歌手点击展开歌曲列表（底部弹层）
//
// 交互参考主流音乐 App：列表 + 底部播放条 + 分类 Tab。

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/audio_models.dart';
import '../providers/providers.dart';
import '../providers/recent_playbacks_provider.dart';
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';
import 'music/equalizer_bars.dart';
import 'music/music_cover_widgets.dart';
import 'music/mini_player_bar.dart';
import 'music/add_to_playlist_sheet.dart';
import 'music/home_widgets.dart';
import 'music/horizontal_lists.dart';
part 'synology_music/constants.dart';
part 'synology_music/home_tab.dart';
part 'synology_music/list_builders.dart';
part 'synology_music/sheets.dart';

class SynologyMusicView extends ConsumerStatefulWidget {
  /// [showBackButton]：独立路由（/music）进入时显示返回按钮；
  /// 作为音乐服务模式首页（/）时不显示返回。
  /// [initialTab]：初始显示的 Tab，默认首页。
  /// [showTabBar]：是否显示顶部分类 TabBar，MainView 首页 Tab 设为 false。
  /// [showMiniPlayer]：是否显示底部迷你播放条，MainView 统一显示时设为 false。
  const SynologyMusicView({
    super.key,
    this.showBackButton = true,
    this.initialTab = SynologyMusicTab.home,
    this.showTabBar = true,
    this.showMiniPlayer = true,
  });

  final bool showBackButton;
  final SynologyMusicTab initialTab;
  final bool showTabBar;
  final bool showMiniPlayer;

  @override
  ConsumerState<SynologyMusicView> createState() => _SynologyMusicViewState();
}

class _SynologyMusicViewState extends ConsumerState<SynologyMusicView>
    with SingleTickerProviderStateMixin {
  /// 全局初始化标志：MainView 中有两个 SynologyMusicView 实例（首页+音乐库），
  /// 仅第一个实例执行全局初始化（loadTab/loadHomeData/restorePlayback），
  /// 避免双倍网络请求和恢复逻辑竞态。两个实例共享同一 Provider，数据互通。
  static bool _globalInitDone = false;

  late final TabController _tabController;
  final ScrollController _artistScrollController = ScrollController();
  final _searchController = TextEditingController();
  final _homeScrollController = ScrollController();
  final _genreKey = GlobalKey(); // 音乐流派模块 GlobalKey，用于精确滚动
  Timer? _searchDebounce;

  /// 精选专辑缓存：首次计算后缓存，避免每次 build 重新 shuffle 导致内容跳变
  /// 下拉刷新时清除，重新抽样
  List<AudioAlbum>? _cachedFeaturedAlbums;
  int? _cachedAlbumsLength; // 记录缓存时的专辑数量，用于检测数据变化

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _tabController.addListener(_onTabChanged);
    // 全局初始化仅执行一次（MainView 中两个实例共享 Provider，数据互通）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_globalInitDone) return;
      _globalInitDone = true;
      final notifier = ref.read(synologyMusicProvider.notifier);
      // 并发加载，首页尽快展示内容
      notifier.loadTab(SynologyMusicTab.songs);
      notifier.loadTab(SynologyMusicTab.albums);
      notifier.loadTab(SynologyMusicTab.artists);
      notifier.loadTab(SynologyMusicTab.playlists);
      notifier.loadHomeData();
      // 恢复上次播放状态（PRD：退出 App 后续听，不自动播放）
      ref.read(synologyPlaybackProvider.notifier).restorePlayback();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _artistScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final tab = SynologyMusicTab.values[_tabController.index];
    final notifier = ref.read(synologyMusicProvider.notifier);
    if (tab == SynologyMusicTab.home) {
      // 首页需要所有分类数据 + 首页专用数据，并发预加载
      notifier.loadTab(SynologyMusicTab.songs);
      notifier.loadTab(SynologyMusicTab.albums);
      notifier.loadTab(SynologyMusicTab.artists);
      notifier.loadTab(SynologyMusicTab.playlists);
      notifier.loadHomeData();
    } else {
      notifier.loadTab(tab);
    }
  }

  /// 搜索输入（300ms 防抖，与项目搜索页一致）
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(synologyMusicProvider.notifier).search(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(synologyAuthProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: !auth.isLoggedIn
          ? _buildNotLoggedIn(scheme)
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  // 渐变头部：顶栏 + 搜索框 + 分类 Tab（QQ音乐/酷狗风格）
                  _buildGradientHeader(scheme),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        final tab =
                            SynologyMusicTab.values[_tabController.index];
                        final notifier =
                            ref.read(synologyMusicProvider.notifier);
                        await notifier.loadTab(tab, force: true);
                        // 首页下拉时同时刷新首页专用数据（最近添加/热门艺术家/流派）
                        if (tab == SynologyMusicTab.home) {
                          await notifier.loadHomeData(force: true);
                          // 下拉刷新时清除精选专辑缓存，重新随机抽样
                          _cachedFeaturedAlbums = null;
                        }
                      },
                      child: _buildTabContent(scheme),
                    ),
                  ),
                  // 底部迷你播放条（MainView 统一显示时隐藏）
                  if (widget.showMiniPlayer) const MiniPlayerBar(),
                ],
              ),
            ),
    );
  }

  // ============================
  // 渐变头部（品牌色 + 搜索 + Tab）
  // ============================

  Widget _buildGradientHeader(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF16324F), Color(0xFF1E6FB8)]
          : const [Color(0xFF2C8EF4), Color(0xFF63B3F8)],
    );
    // 渐变上文字统一白色（深色模式同样适用）
    const onGradient = Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 顶栏：返回 + 标题 + 退出
          // 沉浸式渐变头部：背景铺满状态栏，内容下移避让状态栏（刘海屏）
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  // 返回按钮：独立路由可 pop；首页（/）时进入设置页
                  if (widget.showBackButton)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: onGradient),
                      tooltip: '返回',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/settings');
                        }
                      },
                    )
                  else
                    const SizedBox(width: _kSearchBarWidth),
                  const Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.library_music,
                            color: onGradient, size: 22),
                        SizedBox(width: _kSpacingMedium),
                        const Text(
                          '群晖音乐',
                          style: const TextStyle(
                            color: onGradient,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: onGradient),
                    tooltip: '退出群晖账号',
                    onPressed: () => _confirmLogout(scheme),
                  ),
                ],
              ),
            ),
          ),
          _buildSearchBar(scheme, onGradient),
          if (widget.showTabBar) _buildTabBar(scheme, onGradient),
        ],
      ),
    );
  }

  // ============================
  // 未登录态
  // ============================

  Widget _buildNotLoggedIn(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_outlined,
              size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: _kSpacingXXXLarge),
          Text(
            '尚未连接群晖 Audio Station',
            style:
                TextStyle(fontSize: _kFontSizeLarge, color: scheme.onSurface),
          ),
          const SizedBox(height: _kSpacingLarge),
          Text(
            '登录后可浏览和播放 NAS 上的音乐',
            style: TextStyle(
                fontSize: _kFontSizeBody, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: _kSpacingXXXXLarge),
          ElevatedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  // ============================
  // 搜索 / Tab
  // ============================

  Widget _buildSearchBar(ColorScheme scheme, Color onGradient) {
    final state = ref.watch(synologyMusicProvider);
    final auth = ref.watch(synologyAuthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 渐变上的搜索框：浅色模式白底、深色模式深底
    final fieldColor =
        isDark ? const Color(0xFF1E2F45) : Colors.white.withValues(alpha: 0.95);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final hintColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF7A8BA0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(fontSize: _kFontSizeMedium, color: textColor),
              decoration: InputDecoration(
                hintText: '搜索歌曲 / 专辑 / 歌手',
                hintStyle:
                    TextStyle(fontSize: _kFontSizeMedium, color: hintColor),
                prefixIcon: Icon(Icons.search, size: 20, color: hintColor),
                suffixIcon: state.isSearching
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: hintColor),
                        tooltip: '清空',
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(synologyMusicProvider.notifier)
                              .clearSearch();
                        },
                      )
                    : null,
                filled: true,
                fillColor: fieldColor,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      BorderSide(color: onGradient.withValues(alpha: 0.8)),
                ),
              ),
            ),
          ),
          // NAS 连接状态指示器（绿色=在线，灰色=离线）
          _buildConnectionIndicator(auth, onGradient),
          // 头像入口（点击进入设置/个人中心）
          _buildAvatarEntry(onGradient),
        ],
      ),
    );
  }

  /// NAS 连接状态指示器
  Widget _buildConnectionIndicator(SynologyAuthState auth, Color onGradient) {
    final isOnline = auth.isLoggedIn;
    return Tooltip(
      message: isOnline ? 'NAS 已连接：${auth.account ?? ''}' : 'NAS 未连接',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOnline ? Colors.greenAccent : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: isOnline
                ? [
                    BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.5),
                        blurRadius: 4)
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  /// 头像入口（点击进入设置页，个人中心后续独立页面）
  Widget _buildAvatarEntry(Color onGradient) {
    return IconButton(
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: onGradient.withValues(alpha: 0.2),
        child: Icon(Icons.person, size: 18, color: onGradient),
      ),
      tooltip: '个人中心',
      onPressed: () => context.go('/profile'),
    );
  }

  Widget _buildTabBar(ColorScheme scheme, Color onGradient) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 2),
      child: TabBar(
        controller: _tabController,
        indicatorColor: onGradient,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        labelColor: onGradient,
        unselectedLabelColor: onGradient.withValues(alpha: 0.65),
        labelStyle: const TextStyle(
            fontSize: _kFontSizeMedium, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: _kFontSizeMedium, fontWeight: FontWeight.w500),
        tabs: [
          for (final tab in SynologyMusicTab.values) Tab(text: tab.label),
        ],
      ),
    );
  }

  // ============================
  // Tab 内容
  // ============================

  Widget _buildTabContent(ColorScheme scheme) {
    final state = ref.watch(synologyMusicProvider);

    // 搜索态优先展示搜索结果
    if (state.isSearching) {
      return _buildSearchResult(state, scheme);
    }

    if (state.isLoading && _isEmptyForTab(state)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在加载音乐库...',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (state.error != null && _isEmptyForTab(state)) {
      return _buildError(state.error!, scheme);
    }

    switch (SynologyMusicTab.values[_tabController.index]) {
      case SynologyMusicTab.home:
        return _buildHomeTab(state, scheme);
      case SynologyMusicTab.songs:
        return _buildSongList(state.songs, scheme);
      case SynologyMusicTab.albums:
        return _buildAlbumGrid(state.albums, scheme);
      case SynologyMusicTab.artists:
        return _buildArtistList(state.artists, scheme);
      case SynologyMusicTab.playlists:
        return _buildPlaylistList(state.playlists, scheme);
    }
  }

  bool _isEmptyForTab(SynologyMusicState state) {
    switch (SynologyMusicTab.values[_tabController.index]) {
      case SynologyMusicTab.home:
        return false; // 首页永不为空（有快捷入口）
      case SynologyMusicTab.songs:
        return state.songs.isEmpty;
      case SynologyMusicTab.albums:
        return state.albums.isEmpty;
      case SynologyMusicTab.artists:
        return state.artists.isEmpty;
      case SynologyMusicTab.playlists:
        return state.playlists.isEmpty;
    }
  }

  // ============================
  // 首页 Tab（QQ音乐/酷狗风格：快捷入口 + 横向滚动推荐）
  // ============================

  /// 滚动到音乐流派区域（首页底部）
  ///
  /// 使用 GlobalKey + Scrollable.ensureVisible 精确滚动，
  /// 避免直接滚动到 maxScrollExtent 导致位置不准确。
  Widget _buildHomeSectionHeader(
      String title, SynologyMusicTab? targetTab, ColorScheme scheme) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: _kListItemHorizontalPadding),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: _kSectionTitleFontSize,
                  fontWeight: _kSectionTitleFontWeight,
                  color: scheme.onSurface)),
          const Spacer(),
          // targetTab 为 null 时隐藏"更多"按钮（如我的锁定/音乐流派，无对应完整列表页）
          if (targetTab != null)
            TextButton(
              onPressed: () => _switchTab(targetTab),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('更多',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: _kMoreButtonFontSize)),
                Icon(Icons.chevron_right,
                    size: _kMoreButtonIconSize, color: scheme.onSurfaceVariant),
              ]),
            ),
        ],
      ),
    );
  }

  /// 最近播放横向卡片列表（PRD 首屏核心模块，客户端本地存储）
  ///
  /// 卡片：封面（正方形圆角）+ 标题（1行截断）+ 副标题（1行截断）
  /// + 右下角悬浮播放按钮。点击卡片播放该歌曲，长按弹出移除菜单。
  /// 播放最近播放记录中的歌曲
  /// 我的锁定（My Pins）横向卡片列表
  ///
  /// Pin 接口返回简化歌曲信息（id/title/artist/album），无封面 URL，
  /// 卡片用渐变色占位封面 + 标题 + 歌手展示。
  /// 播放锁定的歌曲（从全量歌曲列表按 ID 匹配完整歌曲）
  /// 最近播放长按菜单：播放 / 移除该记录
  /// 歌曲列表长按操作菜单
  /// 音乐流派 2 列网格色块卡片（PRD 页面最底部模块）
  ///
  /// 每个卡片：渐变色块 + 流派名称 + 歌曲数量。点击随机播放该流派全部歌曲。
  /// 随机播放指定流派的全部歌曲（shuffle 模式）
  /// 随机播放指定流派的全部歌曲（shuffle 模式，PRD 要求）
  /// 通用加载指示器（歌曲/专辑/歌手列表触底加载时使用）
  void _switchTab(SynologyMusicTab tab) {
    _tabController.animateTo(tab.index);
  }

  /// Random100：从全量歌曲中随机抽取 100 首播放（PRD 系统内置随机歌单）
  ///
  /// 全量歌曲少于 100 首时全部播放。
  void _shufflePlay() {
    final songs = ref.read(synologyMusicProvider).songs;
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可播放的歌曲')),
      );
      return;
    }
    final shuffled = [...songs]..shuffle();
    final random100 = shuffled.take(100).toList();
    ref.read(synologyPlaybackProvider.notifier).playQueue(random100, 0);
  }

  // ============================
  // 歌曲列表
  // ============================

  // ============================
  // 专辑网格
  // ============================

  // ============================
  // 歌手列表
  // ============================

  // ============================
  // 歌单列表
  // ============================

  // ============================
  // 搜索结果
  // ============================

  /// 歌手搜索结果列表：头像 + 名字 + 简介摘要 + 数据出处标签
  ///
  /// 数据来源标注（Last.fm / 群晖 NAS / Wikipedia），方便用户判断可信度；
  /// 点击进入该歌手歌曲列表。
  // ============================
  // 弹层：专辑 / 歌手 / 歌单 歌曲
  // ============================

  String? _albumCoverUrl(AudioAlbum album) {
    return ref.read(synologyAuthProvider.notifier).api.getAlbumCoverUrl(
          albumName: album.name,
          albumArtistName: album.albumArtist,
        );
  }

  // ============================
  // 退出登录
  // ============================
}
