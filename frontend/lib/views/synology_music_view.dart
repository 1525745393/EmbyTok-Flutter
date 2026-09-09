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
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/audio_models.dart';
import '../services/artist_info_service.dart';
import '../services/lastfm_service.dart';
import 'synology_full_player.dart';
import '../providers/providers.dart';
import '../providers/recent_playbacks_provider.dart';
import '../utils/image_cache_manager.dart';
import '../utils/logger.dart';

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
  final _searchController = TextEditingController();
  final _homeScrollController = ScrollController();
  Timer? _searchDebounce;

  /// 精选专辑缓存：首次计算后缓存，避免每次 build 重新 shuffle 导致内容跳变
  /// 下拉刷新时清除，重新抽样
  List<AudioAlbum>? _cachedFeaturedAlbums;

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
                        final tab = SynologyMusicTab.values[_tabController.index];
                        final notifier = ref.read(synologyMusicProvider.notifier);
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
    final onGradient = Colors.white;

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
                      icon: Icon(Icons.arrow_back, color: onGradient),
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
                    const SizedBox(width: 48),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.library_music, color: onGradient, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '群晖音乐',
                          style: TextStyle(
                            color: onGradient,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout, color: onGradient),
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
          const SizedBox(height: 16),
          Text(
            '尚未连接群晖 Audio Station',
            style: TextStyle(fontSize: 16, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可浏览和播放 NAS 上的音乐',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
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
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: '搜索歌曲 / 专辑 / 歌手',
                hintStyle: TextStyle(fontSize: 14, color: hintColor),
                prefixIcon: Icon(Icons.search, size: 20, color: hintColor),
                suffixIcon: state.isSearching
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: hintColor),
                        tooltip: '清空',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(synologyMusicProvider.notifier).clearSearch();
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
                  borderSide: BorderSide(color: onGradient.withValues(alpha: 0.8)),
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
                ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 4)]
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
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
      return const Center(child: CircularProgressIndicator());
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

  Widget _buildHomeTab(SynologyMusicState state, ColorScheme scheme) {
    // 最近播放记录（客户端本地存储，PRD 首屏核心模块）
    final recentPlaybacks = ref.watch(recentPlaybacksProvider);

    // 精选专辑：从全量专辑中随机抽样，与最近添加去重（name+artist 组合，避免同名不同艺术家被错误去重）
    // 首次计算后缓存，避免每次 build 重新 shuffle 导致内容频繁跳变
    // 注意：仅当 state.albums 非空时才缓存，避免异步数据未加载时缓存空列表导致模块永远不显示
    final featured = _cachedFeaturedAlbums ?? (state.albums.isNotEmpty
        ? _cachedFeaturedAlbums = () {
            final recentKeys = state.recentAlbums
                .map((e) => '${e.name}||${e.displayArtist ?? e.albumArtist}')
                .toSet();
            final candidates = state.albums
                .where((a) => !recentKeys
                    .contains('${a.name}||${a.displayArtist ?? a.albumArtist}'))
                .toList()
              ..shuffle();
            return candidates.take(12).toList();
          }()
        : const <AudioAlbum>[]);

    return ListView(
      controller: _homeScrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        // 快捷入口
        _buildQuickEntries(scheme),
        const SizedBox(height: 20),
        // 最近播放（无记录时整个模块隐藏，PRD 要求）
        if (recentPlaybacks.isNotEmpty) ...[
          _buildHomeSectionHeader('最近播放', SynologyMusicTab.songs, scheme),
          const SizedBox(height: 10),
          _buildRecentPlaybacksList(recentPlaybacks, scheme),
          const SizedBox(height: 20),
        ],
        // 最近添加（time_add 倒序，NAS 原生接口）
        if (state.recentAlbums.isNotEmpty) ...[
          _buildHomeSectionHeader('最近添加', SynologyMusicTab.albums, scheme),
          const SizedBox(height: 10),
          _buildAlbumHorizontalList(state.recentAlbums, scheme),
          const SizedBox(height: 20),
        ],
        // 我的锁定（My Pins / 用户收藏，SYNO.AudioStation.Pin）
        if (state.pins.isNotEmpty) ...[
          _buildHomeSectionHeader('我的锁定', null, scheme),
          const SizedBox(height: 10),
          _buildPinsList(state.pins, scheme),
          const SizedBox(height: 20),
        ],
        // 我的歌单
        if (state.playlists.isNotEmpty) ...[
          _buildHomeSectionHeader('我的歌单', SynologyMusicTab.playlists, scheme),
          const SizedBox(height: 10),
          _buildPlaylistHorizontalList(state.playlists.take(8).toList(), scheme),
          const SizedBox(height: 20),
        ],
        // 精选专辑（客户端随机抽样，与最近添加去重）
        if (featured.isNotEmpty) ...[
          _buildHomeSectionHeader('精选专辑', SynologyMusicTab.albums, scheme),
          const SizedBox(height: 10),
          _buildAlbumHorizontalList(featured, scheme),
          const SizedBox(height: 20),
        ],
        // 热门艺术家（song_count 倒序）
        if (state.topArtists.isNotEmpty) ...[
          _buildHomeSectionHeader('热门艺术家', SynologyMusicTab.artists, scheme),
          const SizedBox(height: 10),
          _buildArtistHorizontalList(state.topArtists, scheme),
          const SizedBox(height: 20),
        ],
        // 音乐流派（2列网格色块卡片，PRD 页面最底部模块）
        if (state.genres.isNotEmpty) ...[
          _buildHomeSectionHeader('音乐流派', null, scheme),
          const SizedBox(height: 10),
          _buildGenreGrid(state.genres, scheme),
        ],
        // 全空占位（注意：不检查 pins —— 只要有锁定歌曲就不显示全空占位）
        if (state.recentAlbums.isEmpty &&
            state.topArtists.isEmpty &&
            state.genres.isEmpty &&
            state.playlists.isEmpty &&
            state.albums.isEmpty &&
            state.songs.isEmpty &&
            recentPlaybacks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.library_music_outlined,
                      size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('音乐库暂无内容',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickEntries(ColorScheme scheme) {
    final entries = [
      _QuickEntry(
        icon: Icons.music_note, label: '歌曲',
        color: const Color(0xFF4A90D9),
        onTap: () => _switchTab(SynologyMusicTab.songs),
      ),
      _QuickEntry(
        icon: Icons.album, label: '专辑',
        color: const Color(0xFFE67E22),
        onTap: () => _switchTab(SynologyMusicTab.albums),
      ),
      _QuickEntry(
        icon: Icons.person, label: '歌手',
        color: const Color(0xFF9B59B6),
        onTap: () => _switchTab(SynologyMusicTab.artists),
      ),
      _QuickEntry(
        icon: Icons.playlist_play, label: '歌单',
        color: const Color(0xFF27AE60),
        onTap: () => _switchTab(SynologyMusicTab.playlists),
      ),
      _QuickEntry(
        icon: Icons.category, label: '流派',
        color: const Color(0xFF1ABC9C),
        onTap: _scrollToGenres,
      ),
      _QuickEntry(
        icon: Icons.folder, label: '文件夹',
        color: const Color(0xFF3498DB),
        onTap: () => context.go('/folder'),
      ),
      _QuickEntry(
        icon: Icons.shuffle, label: 'Random100',
        color: const Color(0xFFE74C3C),
        onTap: _shufflePlay,
      ),
      _QuickEntry(
        icon: Icons.settings, label: '设置',
        color: const Color(0xFF7F8C8D),
        onTap: () => context.go('/settings'),
      ),
    ];
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) =>
            _QuickEntryButton(entry: entries[index]),
      ),
    );
  }

  /// 滚动到音乐流派区域（首页底部）
  void _scrollToGenres() {
    if (_homeScrollController.hasClients) {
      _homeScrollController.animateTo(
        _homeScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildHomeSectionHeader(
      String title, SynologyMusicTab? targetTab, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const Spacer(),
          // targetTab 为 null 时隐藏"更多"按钮（如我的锁定/音乐流派，无对应完整列表页）
          if (targetTab != null)
            TextButton(
              onPressed: () => _switchTab(targetTab),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('更多', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumHorizontalList(List<AudioAlbum> albums, ColorScheme scheme) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final album = albums[index];
          final coverUrl = ref
              .read(synologyAuthProvider.notifier)
              .api
              .getAlbumCoverUrl(
                albumName: album.name,
                albumArtistName: album.displayArtist ?? album.albumArtist,
              );
          return GestureDetector(
            onTap: () => _showAlbumSongs(album),
            child: SizedBox(
              width: 110,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl, fit: BoxFit.cover,
                            cacheManager: AppImageCacheManager.thumbnail,
                            errorWidget: (_, __, ___) => _albumCoverFallback(scheme),
                          )
                        : _albumCoverFallback(scheme),
                  ),
                ),
                const SizedBox(height: 6),
                Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                Text(album.displayArtist ?? album.albumArtist ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistHorizontalList(List<AudioArtist> artists, ColorScheme scheme) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final artist = artists[index];
          final coverUrl = ref
              .read(synologyAuthProvider.notifier)
              .api
              .getArtistCoverUrl(artist.name);
          return GestureDetector(
            onTap: () => _showArtistSongs(artist),
            child: SizedBox(
              width: 72,
              child: Column(children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.surfaceContainerHighest,
                  backgroundImage: coverUrl != null
                      ? CachedNetworkImageProvider(coverUrl,
                          cacheManager: AppImageCacheManager.thumbnail)
                      : null,
                  child: coverUrl == null
                      ? Text(artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))
                      : null,
                ),
                const SizedBox(height: 6),
                Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistHorizontalList(
      List<AudioPlaylist> playlists, ColorScheme scheme) {
    final gradients = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFFD26F), const Color(0xFFFF9472)],
    ];
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final gradient = gradients[index % gradients.length];
          return GestureDetector(
            onTap: () => _showPlaylistSongs(playlist),
            child: SizedBox(
              width: 110,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
                      ),
                      child: const Icon(Icons.playlist_play, color: Colors.white, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(playlist.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface)),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// 最近播放横向卡片列表（PRD 首屏核心模块，客户端本地存储）
  ///
  /// 卡片：封面（正方形圆角）+ 标题（1行截断）+ 副标题（1行截断）
  /// + 右下角悬浮播放按钮。点击卡片播放该歌曲，长按弹出移除菜单。
  Widget _buildRecentPlaybacksList(
      List<RecentPlayback> records, ColorScheme scheme) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final record = records[index];
          return GestureDetector(
            onTap: () => _playRecentPlayback(record),
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () => _showRecentPlaybackMenu(record, scheme),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: record.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: record.coverUrl!,
                                  fit: BoxFit.cover,
                                  cacheManager: AppImageCacheManager.thumbnail,
                                  errorWidget: (_, __, ___) =>
                                      _albumCoverFallback(scheme),
                                )
                              : _albumCoverFallback(scheme),
                        ),
                      ),
                      // 右下角悬浮播放按钮
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: () => _playRecentPlayback(record),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.play_arrow,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                Text(record.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  /// 播放最近播放记录中的歌曲
  void _playRecentPlayback(RecentPlayback record) {
    if (record.mediaType != RecentPlaybackType.song) return;
    // 从当前歌曲列表中找到匹配的歌曲并播放
    final songs = ref.read(synologyMusicProvider).songs;
    final match = songs.where((s) => s.id == record.mediaId).toList();
    if (match.isNotEmpty) {
      ref.read(synologyPlaybackProvider.notifier).playQueue(match, 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该歌曲已不在当前列表中')),
      );
    }
  }

  /// 我的锁定（My Pins）横向卡片列表
  ///
  /// Pin 接口返回简化歌曲信息（id/title/artist/album），无封面 URL，
  /// 卡片用渐变色占位封面 + 标题 + 歌手展示。
  Widget _buildPinsList(List<AudioPin> pins, ColorScheme scheme) {
    final gradients = [
      [const Color(0xFFFF6B6B), const Color(0xFFEE5A6F)],
      [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFFA751), const Color(0xFFFF6B6B)],
    ];
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pins.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final pin = pins[index];
          final gradient = gradients[index % gradients.length];
          return GestureDetector(
            onTap: () => _playPin(pin),
            child: SizedBox(
              width: 110,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(pin.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                Text(pin.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// 播放锁定的歌曲（从全量歌曲列表按 ID 匹配完整歌曲）
  void _playPin(AudioPin pin) {
    final songs = ref.read(synologyMusicProvider).songs;
    final match = songs.where((s) => s.id == pin.id).toList();
    if (match.isNotEmpty) {
      ref.read(synologyPlaybackProvider.notifier).playQueue(match, 0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${pin.title}」已不在当前歌曲列表中')),
      );
    }
  }

  /// 最近播放长按菜单：播放 / 移除该记录
  void _showRecentPlaybackMenu(RecentPlayback record, ColorScheme scheme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('播放'),
              onTap: () {
                Navigator.pop(ctx);
                _playRecentPlayback(record);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('移除该记录'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(recentPlaybacksProvider.notifier)
                    .remove(record.mediaId, record.mediaType);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 音乐流派 2 列网格色块卡片（PRD 页面最底部模块）
  ///
  /// 每个卡片：渐变色块 + 流派名称 + 歌曲数量。点击随机播放该流派全部歌曲。
  Widget _buildGenreGrid(List<AudioGenre> genres, ColorScheme scheme) {
    final gradients = [
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFFD26F), const Color(0xFFFF9472)],
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final gradient = gradients[index % gradients.length];
          return GestureDetector(
            onTap: () => _playGenreShuffle(genre),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    genre.name.isEmpty ? '未分类' : genre.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${genre.songCount} 首',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 随机播放指定流派的全部歌曲（shuffle 模式）
  /// 随机播放指定流派的全部歌曲（shuffle 模式，PRD 要求）
  Future<void> _playGenreShuffle(AudioGenre genre) async {
    final name = genre.name.isEmpty ? '未分类' : genre.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在加载「$name」流派...')),
    );
    try {
      final api = ref.read(synologyAuthProvider.notifier).api;
      final songs = await api.getSongs(genre: genre.name, limit: 500);
      if (songs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「$name」流派暂无歌曲')),
          );
        }
        return;
      }
      final shuffled = [...songs]..shuffle();
      ref.read(synologyPlaybackProvider.notifier).playQueue(shuffled, 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载「$name」失败：$e')),
        );
      }
    }
  }

  Widget _albumCoverFallback(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 32),
    );
  }

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

  Widget _buildError(String error, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(synologyMusicProvider.notifier).loadTab(
                SynologyMusicTab.values[_tabController.index],
                force: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // ============================
  // 歌曲列表
  // ============================

  Widget _buildSongList(List<AudioSong> songs, ColorScheme scheme) {
    if (songs.isEmpty) {
      return _buildEmpty('暂无歌曲', scheme);
    }
    final playback = ref.watch(synologyPlaybackProvider);
    final musicState = ref.watch(synologyMusicProvider);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: songs.length + (musicState.hasMoreSongs ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载更多
        if (index >= songs.length) {
          if (!musicState.isLoadingMoreSongs) {
            // 延迟到下一帧触发，避免 build 中副作用
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(synologyMusicProvider.notifier).loadMoreSongs();
              }
            });
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
            ),
          );
        }
        final song = songs[index];
        final isCurrent = playback.currentSong?.id == song.id;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              ref
                  .read(synologyPlaybackProvider.notifier)
                  .playQueue(songs, index);
            },
            child: Row(
              children: [
                _SongCover(songId: song.id, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isCurrent && playback.isPlaying)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _EqualizerBars(
                                color: scheme.primary,
                                size: 12,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (song.artistDisplay.isNotEmpty) song.artistDisplay,
                          if (song.albumDisplay.isNotEmpty) song.albumDisplay,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  song.durationText,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================
  // 专辑网格
  // ============================

  Widget _buildAlbumGrid(List<AudioAlbum> albums, ColorScheme scheme,
      {bool paginated = true}) {
    if (albums.isEmpty) {
      return _buildEmpty('暂无专辑', scheme);
    }
    final musicState = ref.watch(synologyMusicProvider);
    final showLoadingCell = paginated && musicState.hasMoreAlbums;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
      ),
      itemCount: albums.length + (showLoadingCell ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载更多
        if (index >= albums.length) {
          if (!musicState.isLoadingMoreAlbums && paginated) {
            // 延迟到下一帧触发，避免 build 中副作用
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(synologyMusicProvider.notifier).loadMoreAlbums();
              }
            });
          }
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        final album = albums[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showAlbumSongs(album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 大封面卡片（QQ音乐/酷狗专辑风格）
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _AlbumCover(album: album),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                album.artistDisplay.isEmpty ? '未知歌手' : album.artistDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // 歌手列表
  // ============================

  Widget _buildArtistList(List<AudioArtist> artists, ColorScheme scheme,
      {bool paginated = true}) {
    if (artists.isEmpty) {
      return _buildEmpty('暂无歌手', scheme);
    }
    final musicState = ref.watch(synologyMusicProvider);
    final showLoadingCell = paginated && musicState.hasMoreArtists;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.82,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
      ),
      itemCount: artists.length + (showLoadingCell ? 1 : 0),
      itemBuilder: (context, index) {
        // 触底加载更多
        if (index >= artists.length) {
          if (!musicState.isLoadingMoreArtists && paginated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(synologyMusicProvider.notifier).loadMoreArtists();
              }
            });
          }
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          );
        }
        final artist = artists[index];
        // 圆形头像网格（QQ音乐/酷狗歌手风格）：优先显示 NAS 歌手图，
        // 无图时回退为首字母渐变头像
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showArtistSongs(artist),
          child: Column(
            children: [
              _ArtistAvatar(artistName: artist.name, size: 72),
              const SizedBox(height: 8),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // 歌单列表
  // ============================

  Widget _buildPlaylistList(List<AudioPlaylist> playlists, ColorScheme scheme) {
    if (playlists.isEmpty) {
      return _buildEmpty('暂无歌单', scheme);
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        // 歌单封面渐变取色（QQ音乐/酷狗歌单卡风格）
        const palettes = [
          [Color(0xFF5B8DEF), Color(0xFF8E6BF0)],
          [Color(0xFF26B8A0), Color(0xFF3F9DE0)],
          [Color(0xFFF07B5B), Color(0xFFF0A94F)],
          [Color(0xFFE05B8D), Color(0xFF8E5BF0)],
          [Color(0xFF3FA7D8), Color(0xFF6B8FE0)],
          [Color(0xFF6BC75B), Color(0xFF3FA7A0)],
        ];
        final colors = palettes[index % palettes.length];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showPlaylistSongs(playlist),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.queue_music,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 40,
                        ),
                      ),
                      // 右上角类型角标
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            playlist.type == 'smart' ? '智能' : '普通',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // 搜索结果
  // ============================

  Widget _buildSearchResult(SynologyMusicState state, ColorScheme scheme) {
    if (state.isLoading && state.searchResult == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final result = state.searchResult;
    if (result == null ||
        (result.songs.isEmpty &&
            result.albums.isEmpty &&
            result.artists.isEmpty)) {
      return _buildEmpty('未找到「${state.searchKeyword}」相关内容', scheme);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (result.songs.isNotEmpty) ...[
          _buildSectionHeader('歌曲 (${result.songs.length})', scheme),
          _buildSongList(result.songs, scheme),
        ],
        if (result.albums.isNotEmpty) ...[
          _buildSectionHeader('专辑 (${result.albums.length})', scheme),
          _buildAlbumGrid(result.albums, scheme, paginated: false),
        ],
        if (result.artists.isNotEmpty) ...[
          _buildSectionHeader('歌手 (${result.artists.length})', scheme),
          // 搜索结果：头像 + 简介 + 出处 列表（供用户选择）
          _buildArtistSearchList(result.artists, scheme),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 歌手搜索结果列表：头像 + 名字 + 简介摘要 + 数据出处标签
  ///
  /// 数据来源标注（Last.fm / 群晖 NAS / Wikipedia），方便用户判断可信度；
  /// 点击进入该歌手歌曲列表。
  Widget _buildArtistSearchList(List<AudioArtist> artists, ColorScheme scheme) {
    return Column(
      children: [
        for (final artist in artists)
          _ArtistSearchTile(
            artist: artist,
            // 顶部全局搜索只查群晖本地库
            hitSource: ArtistInfoSource.synology,
            onTap: () => _showArtistSongs(artist),
          ),
      ],
    );
  }

  Widget _buildEmpty(String text, ColorScheme scheme) {
    // 使用可滚动容器保证下拉刷新可用
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off_outlined,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  text,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================
  // 弹层：专辑 / 歌手 / 歌单 歌曲
  // ============================

  Future<void> _showAlbumSongs(AudioAlbum album) async {
    final songs =
        await ref.read(synologyMusicProvider.notifier).loadAlbumSongs(album);
    if (!mounted) return;
    await _showSongsSheet(
      title: album.name,
      subtitle: album.artistDisplay,
      songs: songs,
      emptyText: '专辑内暂无歌曲',
      cover: _albumCoverUrl(album),
    );
  }

  Future<void> _showArtistSongs(AudioArtist artist) async {
    // 通过 API 按歌手名过滤歌曲
    final api = ref.read(synologyAuthProvider.notifier).api;
    List<AudioSong> songs;
    try {
      songs = await api.getSongs(artist: artist.name);
    } catch (e) {
      AppLogger.warn('加载歌手歌曲失败',
          data: {'artist': artist.name, 'error': e.toString()});
      songs = const [];
    }
    if (!mounted) return;
    // 歌手详情弹层：歌曲列表 + 顶部搜索按钮（可搜索其他歌手选择）
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ArtistDetailSheet(
        artist: artist,
        initialSongs: songs,
      ),
    );
  }

  Future<void> _showPlaylistSongs(AudioPlaylist playlist) async {
    final songs = await ref
        .read(synologyMusicProvider.notifier)
        .loadPlaylistSongs(playlist.id);
    if (!mounted) return;
    await _showSongsSheet(
      title: playlist.name,
      songs: songs,
      emptyText: '歌单内暂无歌曲',
    );
  }

  Future<void> _showSongsSheet({
    required String title,
    String? subtitle,
    required List<AudioSong> songs,
    required String emptyText,
    String? cover,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  if (cover != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          cacheManager: AppImageCacheManager.thumbnail,
                          errorWidget: (_, __, ___) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.album,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            // 歌手简介允许多行展示（最多 3 行）
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 32),
                    color: scheme.primary,
                    tooltip: '播放全部',
                    onPressed: songs.isEmpty
                        ? null
                        : () {
                            ref
                                .read(synologyPlaybackProvider.notifier)
                                .playQueue(songs, 0);
                            Navigator.pop(ctx);
                          },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: songs.isEmpty
                  ? Center(
                      child: Text(
                        emptyText,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isCurrent = ref
                                .watch(synologyPlaybackProvider)
                                .currentSong
                                ?.id ==
                            song.id;
                        return ListTile(
                          dense: true,
                          leading: _SongCover(songId: song.id, size: 40),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  isCurrent ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          subtitle: song.artistDisplay.isNotEmpty
                              ? Text(
                                  song.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant),
                                )
                              : null,
                          trailing: Text(
                            song.durationText,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                          onTap: () {
                            ref
                                .read(synologyPlaybackProvider.notifier)
                                .playQueue(songs, index);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _albumCoverUrl(AudioAlbum album) {
    return ref.read(synologyAuthProvider.notifier).api.getAlbumCoverUrl(
          albumName: album.name,
          albumArtistName: album.albumArtist,
        );
  }

  // ============================
  // 退出登录
  // ============================

  Future<void> _confirmLogout(ColorScheme scheme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: const Text('退出群晖账号'),
        content: const Text('确定要退出群晖 Audio Station 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // 停止播放并退出
      await ref.read(synologyPlaybackProvider.notifier).stop();
      await ref.read(synologyAuthProvider.notifier).logout();
      ref.read(synologyMusicProvider.notifier).clearSearch();
    }
  }
}

/// 快捷入口数据
class _QuickEntry {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickEntry(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

/// 快捷入口按钮（圆形渐变背景 + 图标 + 文字）
class _QuickEntryButton extends StatelessWidget {
  final _QuickEntry entry;
  const _QuickEntryButton({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: entry.onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  entry.color.withValues(alpha: 0.9),
                  entry.color
                ]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: entry.color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(entry.icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 6),
        Text(entry.label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

// ============================
// 歌曲封面组件
// ============================

class _SongCover extends ConsumerWidget {
  final String songId;
  final double size;

  const _SongCover({required this.songId, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url =
        ref.read(synologyAuthProvider.notifier).api.getSongCoverUrl(songId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                cacheManager: AppImageCacheManager.thumbnail,
                errorWidget: (_, __, ___) => _coverFallback(scheme),
              )
            : _coverFallback(scheme),
      ),
    );
  }

  Widget _coverFallback(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant, size: 20),
    );
  }
}

/// 歌手圆形头像组件
///
/// 优先加载 NAS 歌手图（cover.cgi + artist_name）；无图/加载失败时
/// 回退为「渐变背景 + 歌手名首字母」（QQ音乐/酷狗风格）。
class _ArtistAvatar extends ConsumerStatefulWidget {
  final String artistName;
  final double size;

  const _ArtistAvatar({required this.artistName, required this.size});

  @override
  ConsumerState<_ArtistAvatar> createState() => _ArtistAvatarState();
}

class _ArtistAvatarState extends ConsumerState<_ArtistAvatar> {
  /// 聚合信息（Last.fm → 群晖 → 首字母，缓存命中时同步完成）
  Future<ArtistInfoResult>? _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = ref.read(artistInfoCacheProvider).get(widget.artistName);
  }

  @override
  void didUpdateWidget(covariant _ArtistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _infoFuture = ref.read(artistInfoCacheProvider).get(widget.artistName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = widget.artistName.trim().isEmpty
        ? '?'
        : widget.artistName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.85),
            scheme.primary.withValues(alpha: 0.45),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<ArtistInfoResult>(
        future: _infoFuture,
        builder: (context, snapshot) {
          final url = snapshot.data?.imageUrl;
          if (url == null) return _initialFallback(initial, scheme);
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheManager: AppImageCacheManager.thumbnail,
            errorWidget: (_, __, ___) => _initialFallback(initial, scheme),
          );
        },
      ),
    );
  }

  /// 首字母渐变头像（无图兜底）
  Widget _initialFallback(String initial, ColorScheme scheme) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 歌手搜索结果条目：头像 + 名字 + 简介 + 出处标签
class _ArtistSearchTile extends ConsumerWidget {
  final AudioArtist artist;

  /// 条目来源（在哪搜到的）：群晖 NAS 本地库 / Last.fm 在线搜索。
  /// none 表示不显示条目来源标签（仅内容出处标签）。
  final ArtistInfoSource hitSource;

  /// 点击回调（由页面层提供，复用现有歌手歌曲弹层逻辑）
  final VoidCallback onTap;

  const _ArtistSearchTile({
    required this.artist,
    required this.onTap,
    this.hitSource = ArtistInfoSource.none,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final infoFuture = ref.read(artistInfoCacheProvider).get(artist.name);

    return FutureBuilder<ArtistInfoResult>(
      future: infoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final bio = info?.bio;
        final bioSource = info?.bioSource ?? ArtistInfoSource.none;
        final imageSource = info?.imageSource ?? ArtistInfoSource.none;
        // 内容出处（头像/简介实际来源）；与条目来源相同时不重复显示
        final contentSource =
            bioSource != ArtistInfoSource.none ? bioSource : imageSource;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _ArtistAvatar(artistName: artist.name, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 条目来源标签（在哪搜到的）：群晖 NAS / Last.fm
                          _SourceBadge(
                              source: hitSource,
                              imageSource: ArtistInfoSource.none),
                          // 内容出处标签（头像/简介实际来源）
                          if (contentSource != hitSource)
                            _SourceBadge(
                                source: contentSource,
                                imageSource: ArtistInfoSource.none),
                        ],
                      ),
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 数据出处小标签
class _SourceBadge extends StatelessWidget {
  final ArtistInfoSource source;
  final ArtistInfoSource imageSource;

  const _SourceBadge({required this.source, required this.imageSource});

  @override
  Widget build(BuildContext context) {
    // 取非空的来源优先展示（简介来源 > 头像来源）
    final shown = source != ArtistInfoSource.none
        ? source
        : (imageSource != ArtistInfoSource.none ? imageSource : null);
    if (shown == null) return const SizedBox.shrink();
    final (color, bg) = switch (shown) {
      ArtistInfoSource.lastfm => (
          const Color(0xFFD51007),
          const Color(0xFFD51007).withValues(alpha: 0.12),
        ),
      ArtistInfoSource.synology => (
          const Color(0xFF2C8EF4),
          const Color(0xFF2C8EF4).withValues(alpha: 0.12),
        ),
      ArtistInfoSource.wikipedia => (
          const Color(0xFF616161),
          const Color(0xFF616161).withValues(alpha: 0.12),
        ),
      ArtistInfoSource.none => (null, null),
    };
    if (color == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        shown.label,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 专辑封面组件
class _AlbumCover extends ConsumerWidget {
  final AudioAlbum album;

  const _AlbumCover({required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref.read(synologyAuthProvider.notifier).api.getAlbumCoverUrl(
          albumName: album.name,
          albumArtistName: album.albumArtist,
        );
    return url != null
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            cacheManager: AppImageCacheManager.thumbnail,
            errorWidget: (_, __, ___) => Container(
              color: scheme.surfaceContainerHighest,
              child:
                  Icon(Icons.album, color: scheme.onSurfaceVariant, size: 28),
            ),
          )
        : Container(
            color: scheme.surfaceContainerHighest,
            child: Icon(Icons.album, color: scheme.onSurfaceVariant, size: 28),
          );
  }
}

// ============================
// 底部迷你播放条
// ============================

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(synologyPlaybackProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    final notifier = ref.read(synologyPlaybackProvider.notifier);
    // 超窄屏（<360px）隐藏播放模式和停止按钮，保留核心上一首/播放/下一首
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 10,
      child: InkWell(
        onTap: () => showFullPlayerSheet(context),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条
                LinearProgressIndicator(
                  value: state.duration.inMilliseconds > 0
                      ? (state.position.inMilliseconds /
                              state.duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0,
                  minHeight: 2,
                  backgroundColor: scheme.outlineVariant.withValues(alpha: 0.4),
                  color: scheme.primary,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _SongCover(songId: song.id, size: 44),
                    const SizedBox(width: 10),
                    // 标题 + 歌手
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (song.artistDisplay.isNotEmpty)
                            Text(
                              song.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    // 播放控制（紧凑布局，防窄屏溢出；超窄屏隐藏播放模式和停止按钮）
                    if (!isNarrow)
                      _compactButton(
                        scheme: scheme,
                        icon: Icon(
                          switch (state.mode) {
                            SynologyPlaybackMode.listLoop => Icons.repeat,
                            SynologyPlaybackMode.singleLoop => Icons.repeat_one,
                            SynologyPlaybackMode.shuffle => Icons.shuffle,
                          },
                          size: 17,
                        ),
                        color: state.mode == SynologyPlaybackMode.listLoop
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                        tooltip: '播放模式：${state.mode.label}',
                        onPressed: notifier.cycleMode,
                      ),
                    _compactButton(
                      scheme: scheme,
                      icon: const Icon(Icons.skip_previous, size: 22),
                      color: scheme.onSurface,
                      tooltip: '上一首',
                      onPressed:
                          state.currentIndex > 0 ? notifier.previous : null,
                    ),
                    _compactButton(
                      scheme: scheme,
                      icon: Icon(
                        state.isLoading
                            ? Icons.hourglass_top
                            : state.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                        size: 34,
                      ),
                      color: scheme.primary,
                      tooltip: state.isPlaying ? '暂停' : '播放',
                      onPressed: state.isLoading ? null : notifier.togglePlay,
                    ),
                    _compactButton(
                      scheme: scheme,
                      icon: const Icon(Icons.skip_next, size: 22),
                      color: scheme.onSurface,
                      tooltip: '下一首',
                      onPressed: state.currentIndex < state.queue.length - 1
                          ? notifier.next
                          : null,
                    ),
                    if (!isNarrow)
                      _compactButton(
                        scheme: scheme,
                        icon: const Icon(Icons.close, size: 17),
                        color: scheme.onSurfaceVariant,
                        tooltip: '停止',
                        onPressed: notifier.stop,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 紧凑播放控制按钮（压缩点击热区，避免窄屏溢出）
  Widget _compactButton({
    required ColorScheme scheme,
    required Widget icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: icon,
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

// ============================
// 动态均衡器（当前播放歌曲指示）
// ============================

/// 三根跳动柱子的动态均衡器动画，参考主流音乐 App 的"正在播放"指示
class _EqualizerBars extends StatefulWidget {
  final Color color;
  final double size;

  const _EqualizerBars({required this.color, required this.size});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _phases = [0.0, 2.1, 4.2];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * 3.1415926;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final phase in _phases)
                Container(
                  width: widget.size / 4,
                  height: widget.size *
                      (0.35 + 0.55 * (0.5 + 0.5 * math.sin(t + phase))),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================
// 歌手详情弹层：歌曲列表 + 歌手搜索选择
// ============================

/// 歌手详情弹层
///
/// 顶部展示歌手头像/名字/简介（含出处标签）+ 搜索按钮；
/// 点搜索按钮进入歌手搜索模式：输入关键词 → 结果以
/// 「头像 + 简介 + 出处」列表展示，点选后切换当前歌手并加载其歌曲。
class _ArtistDetailSheet extends ConsumerStatefulWidget {
  final AudioArtist artist;
  final List<AudioSong> initialSongs;

  const _ArtistDetailSheet({
    required this.artist,
    required this.initialSongs,
  });

  @override
  ConsumerState<_ArtistDetailSheet> createState() => _ArtistDetailSheetState();
}

class _ArtistDetailSheetState extends ConsumerState<_ArtistDetailSheet> {
  late AudioArtist _artist = widget.artist;
  late List<AudioSong> _songs = widget.initialSongs;

  /// 是否处于歌手资料搜索模式
  bool _searching = false;
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// 当前搜索目标歌手名（默认 = 当前歌手，可修改搜索其他歌手）
  String _searchTarget = '';

  /// 头部简介/出处（采用某来源后刷新）
  late Future<ArtistInfoResult> _headerInfoFuture;

  @override
  void initState() {
    super.initState();
    _headerInfoFuture =
        ref.read(artistInfoCacheProvider).get(widget.artist.name);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 切换搜索模式（进入时预填当前歌手名）
  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (_searching) {
        _searchController.text = _artist.name;
        _searchTarget = _artist.name;
      } else {
        _searchController.clear();
        _searchTarget = '';
      }
    });
  }

  /// 搜索输入（300ms 防抖，切换搜索目标歌手）
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchTarget = value.trim());
    });
  }

  /// 用户采用某个来源的头像/简介后：刷新头部展示
  void _onAdopted(String artistName) {
    setState(() {
      _headerInfoFuture = ref.read(artistInfoCacheProvider).get(artistName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        // 搜索模式：搜索框 + 当前歌手的各数据源头像/简介（供选择）
        if (_searching) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: '返回歌曲列表',
                      onPressed: _toggleSearch,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: '搜索歌手头像与简介...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _searchTarget.isEmpty
                    ? _buildSearchEmptyHint(scheme)
                    : _ArtistSourcePicker(
                        artistName: _searchTarget,
                        onAdopted: () => _onAdopted(_searchTarget),
                      ),
              ),
            ],
          );
        }

        // 歌曲列表模式：头部（头像/名/简介/出处/搜索按钮/播放全部）+ 歌曲
        return Column(
          children: [
            _buildHeader(scrollController, scheme),
            const Divider(height: 1),
            Expanded(
              child: _songs.isEmpty
                  ? Center(
                      child: Text(
                        '该歌手暂无歌曲',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        final isCurrent = ref
                                .watch(synologyPlaybackProvider)
                                .currentSong
                                ?.id ==
                            song.id;
                        return ListTile(
                          dense: true,
                          leading: _SongCover(songId: song.id, size: 40),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  isCurrent ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          subtitle: song.artistDisplay.isNotEmpty
                              ? Text(
                                  song.artistDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant),
                                )
                              : null,
                          trailing: isCurrent
                              ? Icon(Icons.equalizer,
                                  size: 18, color: scheme.primary)
                              : null,
                          onTap: () {
                            ref
                                .read(synologyPlaybackProvider.notifier)
                                .playQueue(_songs, index);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 头部：歌手信息（头像/名/简介/出处）+ 搜索按钮 + 播放全部
  Widget _buildHeader(ScrollController scrollController, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          // 歌手头像 + 名字 + 简介（出处标签）
          _ArtistAvatar(artistName: _artist.name, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<ArtistInfoResult>(
              future: _headerInfoFuture,
              builder: (context, snapshot) {
                final info = snapshot.data;
                final bio = info?.bio;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SourceBadge(
                          source: info?.bioSource ?? ArtistInfoSource.none,
                          imageSource:
                              info?.imageSource ?? ArtistInfoSource.none,
                        ),
                      ],
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            color: scheme.onSurfaceVariant,
            tooltip: '搜索头像与简介',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 32),
            color: scheme.primary,
            tooltip: '播放全部',
            onPressed: _songs.isEmpty
                ? null
                : () {
                    ref
                        .read(synologyPlaybackProvider.notifier)
                        .playQueue(_songs, 0);
                    Navigator.pop(context);
                  },
          ),
        ],
      ),
    );
  }

  /// 搜索空态提示
  Widget _buildSearchEmptyHint(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_outlined,
              size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '输入歌手名，搜索头像与简介',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// 歌手资料来源选择器：展示当前歌手在各数据源的
/// 头像/简介候选（含出处），点选采用并持久化。
class _ArtistSourcePicker extends ConsumerStatefulWidget {
  final String artistName;

  /// 采用某来源后回调（外层刷新头部展示）
  final VoidCallback onAdopted;

  const _ArtistSourcePicker({
    required this.artistName,
    required this.onAdopted,
  });

  @override
  ConsumerState<_ArtistSourcePicker> createState() => _ArtistSourcePickerState();
}

class _ArtistSourcePickerState extends ConsumerState<_ArtistSourcePicker> {
  /// 并行拉取各数据源的 future：仅在歌手名变化时重建，
  /// 避免外层每次 setState（采用后刷新/防抖）都重复请求
  late Future<_ArtistSourceBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSources();
  }

  @override
  void didUpdateWidget(covariant _ArtistSourcePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _future = _loadSources();
    }
  }

  Future<_ArtistSourceBundle> _loadSources() async {
    final artistName = widget.artistName;
    // 1) Last.fm getinfo（头像大图 + 简介）
    // 2) Wikipedia（简介兜底）
    // 3) 群晖 cover.cgi（头像，同步构造 URL）
    final lastfmService = ref.read(lastfmServiceProvider);
    final lastfmFuture = lastfmService?.fetchArtistInfo(artistName);
    final wikiFuture =
        ref.read(artistInfoServiceProvider).fetchArtistInfo(artistName);
    final results = await Future.wait<Object?>([
      lastfmFuture ?? Future<Object?>.value(null),
      wikiFuture,
    ]);
    final lastfm = results[0] as LastFmArtistInfo?;
    final wiki = results[1] as ArtistInfo?;
    String? synoUrl;
    try {
      synoUrl = ref
          .read(synologyAuthProvider.notifier)
          .api
          .getArtistCoverUrl(artistName);
    } catch (_) {
      synoUrl = null;
    }
    return _ArtistSourceBundle(lastfm: lastfm, wiki: wiki, synoUrl: synoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<_ArtistSourceBundle>(
      future: _future,
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (bundle == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final lastfm = bundle.lastfm;
        final wiki = bundle.wiki;
        // Last.fm 简介可能为空（有头像无简介），此时简介回退 Wikipedia
        final lastfmBioRaw = lastfm?.bio;
        final lastfmBio = lastfmBioRaw != null && lastfmBioRaw.isNotEmpty
            ? lastfmBioRaw
            : null;
        final wikiBioRaw = wiki?.bio;
        final wikiBio =
            wikiBioRaw != null && wikiBioRaw.isNotEmpty ? wikiBioRaw : null;

        // 自动聚合值（用于保留未被采用的另一维度）
        final autoImageUrl = lastfm?.imageUrl ?? bundle.synoUrl;
        final autoImageSource = lastfm?.imageUrl != null
            ? ArtistInfoSource.lastfm
            : (bundle.synoUrl != null
                ? ArtistInfoSource.synology
                : ArtistInfoSource.none);
        final autoBio = lastfmBio ?? wikiBio;
        final autoBioSource = lastfmBio != null
            ? ArtistInfoSource.lastfm
            : (wikiBio != null
                ? ArtistInfoSource.wikipedia
                : ArtistInfoSource.none);

        final hasImage = lastfm?.imageUrl != null || bundle.synoUrl != null;
        final hasBio = lastfmBio != null || wikiBio != null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- 头像来源 ----
            _SourceSectionTitle('头像来源', scheme),
            if (!hasImage)
              _SourceEmptyHint('未找到「${widget.artistName}」的头像', scheme)
            else ...[
              if (lastfm?.imageUrl != null)
                _AvatarSourceCard(
                  imageUrl: lastfm!.imageUrl!,
                  source: ArtistInfoSource.lastfm,
                  hint: 'Last.fm 大图',
                  onTap: () => _adopt(
                    ref,
                    '头像',
                    ArtistInfoResult(
                      imageUrl: lastfm.imageUrl,
                      imageSource: ArtistInfoSource.lastfm,
                      bio: autoBio,
                      bioSource: autoBioSource,
                    ),
                  ),
                ),
              if (bundle.synoUrl != null)
                _AvatarSourceCard(
                  imageUrl: bundle.synoUrl!,
                  source: ArtistInfoSource.synology,
                  hint: '群晖 NAS 专辑封面',
                  onTap: () => _adopt(
                    ref,
                    '头像',
                    ArtistInfoResult(
                      imageUrl: bundle.synoUrl,
                      imageSource: ArtistInfoSource.synology,
                      bio: autoBio,
                      bioSource: autoBioSource,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            // ---- 简介来源 ----
            _SourceSectionTitle('简介来源', scheme),
            if (!hasBio)
              _SourceEmptyHint('未找到「${widget.artistName}」的简介', scheme)
            else ...[
              if (lastfmBio != null)
                _BioSourceCard(
                  bio: lastfmBio,
                  source: ArtistInfoSource.lastfm,
                  onTap: () => _adopt(
                    ref,
                    '简介',
                    ArtistInfoResult(
                      imageUrl: autoImageUrl,
                      imageSource: autoImageSource,
                      bio: lastfmBio,
                      bioSource: ArtistInfoSource.lastfm,
                    ),
                  ),
                ),
              if (wikiBio != null)
                _BioSourceCard(
                  bio: wikiBio,
                  source: ArtistInfoSource.wikipedia,
                  onTap: () => _adopt(
                    ref,
                    '简介',
                    ArtistInfoResult(
                      imageUrl: autoImageUrl,
                      imageSource: autoImageSource,
                      bio: wikiBio,
                      bioSource: ArtistInfoSource.wikipedia,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// 采用某来源结果：持久化 + 提示 + 刷新外层
  ///
  /// [dimension] 为被采用的维度（'头像' / '简介'），用于准确提示。
  Future<void> _adopt(
    WidgetRef ref,
    String dimension,
    ArtistInfoResult result,
  ) async {
    await ref.read(artistInfoCacheProvider)
        .saveOverride(widget.artistName, result);
    widget.onAdopted();
    if (!ref.context.mounted) return;
    final source = dimension == '头像'
        ? result.imageSource.label
        : result.bioSource.label;
    ScaffoldMessenger.of(ref.context).showSnackBar(SnackBar(
      content: Text('已采用 $source 的$dimension'),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// 各数据源拉取结果集合
class _ArtistSourceBundle {
  final LastFmArtistInfo? lastfm;
  final ArtistInfo? wiki;
  final String? synoUrl;

  const _ArtistSourceBundle({this.lastfm, this.wiki, this.synoUrl});
}

/// 分区标题
class _SourceSectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme scheme;

  const _SourceSectionTitle(this.title, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 分区空提示
class _SourceEmptyHint extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const _SourceEmptyHint(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// 头像来源候选卡
class _AvatarSourceCard extends StatelessWidget {
  final String imageUrl;
  final ArtistInfoSource source;
  final String hint;
  final VoidCallback onTap;

  const _AvatarSourceCard({
    required this.imageUrl,
    required this.source,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: ClipOval(
          child: SizedBox(
            width: 56,
            height: 56,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              cacheManager: AppImageCacheManager.thumbnail,
              errorWidget: (_, __, ___) => Container(
                color: scheme.surfaceContainerHighest,
                child: Icon(Icons.person,
                    color: scheme.onSurfaceVariant, size: 28),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(hint,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(width: 8),
            _SourceBadge(source: source, imageSource: ArtistInfoSource.none),
          ],
        ),
        trailing:
            Icon(Icons.check_circle_outline, color: scheme.primary, size: 24),
        onTap: onTap,
      ),
    );
  }
}

/// 简介来源候选卡
class _BioSourceCard extends StatelessWidget {
  final String bio;
  final ArtistInfoSource source;
  final VoidCallback onTap;

  const _BioSourceCard({
    required this.bio,
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Row(
          children: [
            Text('简介',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(width: 8),
            _SourceBadge(source: source, imageSource: ArtistInfoSource.none),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
          ),
        ),
        trailing:
            Icon(Icons.check_circle_outline, color: scheme.primary, size: 24),
        onTap: onTap,
      ),
    );
  }
}
