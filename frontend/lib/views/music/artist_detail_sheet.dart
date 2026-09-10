// 歌手详情弹层组件
//
// 从 synology_music_view.dart 拆分出来，提升代码可维护性。
//
// 功能：
// - 顶部展示歌手头像/名字/简介（含出处标签）+ 搜索按钮
// - 点搜索按钮进入歌手搜索模式：输入关键词 → 结果以
//   「头像 + 简介 + 出处」列表展示，点选后切换当前歌手并加载其歌曲

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/audio_models.dart';
import '../../providers/providers.dart';
import '../../services/artist_info_service.dart';
import '../../services/lastfm_service.dart';
import '../../utils/image_cache_manager.dart';
import '../../utils/logger.dart';
import 'music_cover_widgets.dart';

// ===== 歌手详情弹层常量 =====

/// 小字体（标签、副标题）
const double kArtistFontSizeSmall = 12;

/// 中等字体（列表项正文）
const double kArtistFontSizeBody = 13;

/// 中字体（标题、按钮）
const double kArtistFontSizeMedium = 14;

/// 大字体（页面标题、歌手名）
const double kArtistFontSizeLarge = 16;

/// 特大间距
const double kArtistSpacingXXLarge = 12;

/// 巨大间距
const double kArtistSpacingXXXLarge = 16;

// ============================
// 歌手详情弹层：歌曲列表 + 歌手搜索选择
// ============================

/// 歌手详情弹层
///
/// 顶部展示歌手头像/名字/简介（含出处标签）+ 搜索按钮；
/// 点搜索按钮进入歌手搜索模式：输入关键词 → 结果以
/// 「头像 + 简介 + 出处」列表展示，点选后切换当前歌手并加载其歌曲。
class ArtistDetailSheet extends ConsumerStatefulWidget {
  final AudioArtist artist;
  final List<AudioSong> initialSongs;

  const ArtistDetailSheet({
    required this.artist,
    required this.initialSongs,
  });

  @override
  ConsumerState<ArtistDetailSheet> createState() => ArtistDetailSheetState();
}

class ArtistDetailSheetState extends ConsumerState<ArtistDetailSheet> {
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
                    : ArtistSourcePicker(
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
                            color: scheme.onSurfaceVariant, fontSize: kArtistFontSizeBody),
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
                          leading: SongCover(songId: song.id, size: 40),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: kArtistFontSizeMedium,
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
                                      fontSize: kArtistFontSizeSmall,
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
          ArtistAvatar(artistName: _artist.name, size: 48),
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
                              fontSize: kArtistFontSizeLarge,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SourceBadge(
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
                          fontSize: kArtistFontSizeSmall,
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
          const SizedBox(height: kArtistSpacingXXLarge),
          Text(
            '输入歌手名，搜索头像与简介',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: kArtistFontSizeBody),
          ),
        ],
      ),
    );
  }
}

/// 歌手资料来源选择器：展示当前歌手在各数据源的
/// 头像/简介候选（含出处），点选采用并持久化。
class ArtistSourcePicker extends ConsumerStatefulWidget {
  final String artistName;

  /// 采用某来源后回调（外层刷新头部展示）
  final VoidCallback onAdopted;

  const ArtistSourcePicker({
    required this.artistName,
    required this.onAdopted,
  });

  @override
  ConsumerState<ArtistSourcePicker> createState() => ArtistSourcePickerState();
}

class ArtistSourcePickerState extends ConsumerState<ArtistSourcePicker> {
  /// 并行拉取各数据源的 future：仅在歌手名变化时重建，
  /// 避免外层每次 setState（采用后刷新/防抖）都重复请求
  late Future<ArtistSourceBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadSources();
  }

  @override
  void didUpdateWidget(covariant ArtistSourcePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName) {
      _future = _loadSources();
    }
  }

  Future<ArtistSourceBundle> _loadSources() async {
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
    return ArtistSourceBundle(lastfm: lastfm, wiki: wiki, synoUrl: synoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<ArtistSourceBundle>(
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
            SourceSectionTitle('头像来源', scheme),
            if (!hasImage)
              SourceEmptyHint('未找到「${widget.artistName}」的头像', scheme)
            else ...[
              if (lastfm?.imageUrl != null)
                AvatarSourceCard(
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
                AvatarSourceCard(
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
            const SizedBox(height: kArtistSpacingXXXLarge),
            // ---- 简介来源 ----
            SourceSectionTitle('简介来源', scheme),
            if (!hasBio)
              SourceEmptyHint('未找到「${widget.artistName}」的简介', scheme)
            else ...[
              if (lastfmBio != null)
                BioSourceCard(
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
                BioSourceCard(
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
class ArtistSourceBundle {
  final LastFmArtistInfo? lastfm;
  final ArtistInfo? wiki;
  final String? synoUrl;

  const ArtistSourceBundle({this.lastfm, this.wiki, this.synoUrl});
}

/// 分区标题
class SourceSectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme scheme;

  const SourceSectionTitle(this.title, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: kArtistFontSizeBody,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 分区空提示
class SourceEmptyHint extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const SourceEmptyHint(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: kArtistFontSizeSmall, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// 头像来源候选卡
class AvatarSourceCard extends StatelessWidget {
  final String imageUrl;
  final ArtistInfoSource source;
  final String hint;
  final VoidCallback onTap;

  const AvatarSourceCard({
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
                    fontSize: kArtistFontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(width: 8),
            SourceBadge(source: source, imageSource: ArtistInfoSource.none),
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
class BioSourceCard extends StatelessWidget {
  final String bio;
  final ArtistInfoSource source;
  final VoidCallback onTap;

  const BioSourceCard({
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
                    fontSize: kArtistFontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(width: 8),
            SourceBadge(source: source, imageSource: ArtistInfoSource.none),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: kArtistFontSizeSmall, height: 1.4, color: scheme.onSurfaceVariant),
          ),
        ),
        trailing:
            Icon(Icons.check_circle_outline, color: scheme.primary, size: 24),
        onTap: onTap,
      ),
    );
  }
}
