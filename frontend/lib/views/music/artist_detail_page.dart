// 歌手详情页
//
// 歌手简介功能 V1.0
// 独立的歌手详情页，包含可折叠头部、操作按钮、简介模块、专辑列表、歌曲列表。
//
// 参考 QQ音乐/酷狗音乐的歌手详情页交互：
// - 顶部可折叠头部（SliverAppBar），滚动时头像缩小为导航栏头像
// - 操作按钮行（播放全部、收藏、分享）
// - 简介模块（摘要3行截断，展开全文，来源标注）
// - 专辑列表（横向滚动）
// - 歌曲列表（垂直列表，支持播放）

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/artist_metadata.dart';
import '../../models/audio_models.dart';
import '../../providers/artist_metadata_provider.dart';
import '../../providers/synology_auth_provider.dart';
import '../../providers/synology_playback_provider.dart';
import '../../utils/html_parser.dart';
import 'artist_metadata_editor.dart';
import 'artist_search_picker.dart';
import 'mini_player_bar.dart';
part 'artist_parts/artist_builders.dart';
part 'artist_parts/artist_actions.dart';
part 'artist_parts/artist_builders_extra.dart';

// ===== 歌手详情页常量 =====

/// 头部默认展开高度
const double _kHeaderExpandedHeight = 320.0;

/// 横屏模式头部展开高度
const double _kHeaderExpandedHeightLandscape = 220.0;

/// 竖屏头像半径
const double _kAvatarRadiusPortrait = 60.0;

/// 横屏头像半径
const double _kAvatarRadiusLandscape = 50.0;

/// 折叠状态小头像半径
const double _kAvatarRadiusCollapsed = 16.0;

/// 头像图标尺寸（无图片时）
const double _kAvatarIconSize = 60.0;

/// 折叠头像图标尺寸
const double _kAvatarIconSizeCollapsed = 16.0;

/// 歌手名称字号（竖屏）
const double _kArtistNameFontSizePortrait = 24.0;

/// 歌手名称字号（横屏）
const double _kArtistNameFontSizeLandscape = 20.0;

/// 头部顶部间距
const double _kHeaderTopSpacing = 40.0;

/// 头部小间距
const double _kHeaderSmallSpacing = 8.0;

/// 横屏头部水平边距
const double _kHeaderHorizontalPaddingLandscape = 32.0;

/// 头像下方歌手名称间距
const double _kAvatarNameSpacing = 16.0;

/// 歌手名称下方标签间距
const double _kNameTagsSpacing = 8.0;

/// 页面底部间距
const double _kBottomSpacing = 80.0;

/// 平板横屏阈值（宽度）
const double _kTabletLandscapeWidthThreshold = 600.0;

/// 折叠状态头像显示阈值
const double _kCollapsedAvatarThreshold = 40.0;

/// 歌手详情页
///
/// 通过路由 `/music/artist/:name` 访问，或通过构造函数传入歌手对象。
class ArtistDetailPage extends ConsumerStatefulWidget {
  const ArtistDetailPage({
    super.key,
    this.artistName,
    this.artist,
  });

  /// 歌手名称（路由参数）
  final String? artistName;

  /// 歌手对象（直接传入时优先使用）
  final AudioArtist? artist;

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage> {
  /// 歌手名称
  late String _artistName;

  /// 简介是否展开
  bool _bioExpanded = false;

  /// 是否已收藏
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _artistName = widget.artist?.name ?? widget.artistName ?? '';
    _loadFavoriteStatus();
  }

  /// 加载收藏状态

  /// 保存收藏状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 加载歌手元数据（头像、简介、标签等）
    final metadataAsync = ref.watch(artistMetadataProvider(_artistName));

    // 加载歌手歌曲列表
    final songsAsync = ref.watch(artistSongsProvider(_artistName));

    // 加载歌手专辑列表
    final albumsAsync = ref.watch(artistAlbumsProvider(_artistName));

    return Scaffold(
      body: metadataAsync.when(
        data: (metadata) => _buildContent(
          context,
          scheme,
          metadata,
          songsAsync,
          albumsAsync,
        ),
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在加载歌手信息...',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        error: (e, s) => _buildError(context, e),
      ),
      bottomNavigationBar: const MiniPlayerBar(),
    );
  }

  /// 判断是否为平板横屏模式（V1.2）
  ///
  /// 平板横屏模式下，屏幕宽度大于 600 且宽度大于高度。
  /// 此时使用两栏布局，充分利用宽屏空间。

  /// 构建页面主体内容

  /// 构建平板横屏模式内容（V1.2）
  ///
  /// 两栏布局：左侧专辑列表，右侧歌曲列表。
  /// 头部、简介、相似歌手在顶部全宽显示。

  /// 构建可折叠头部（SliverAppBar）
  ///
  /// [expandedHeight] 展开高度，默认 280，平板横屏模式下使用 220。

  /// 构建竖屏模式头部（V1.2）
  ///
  /// 头像在上，歌手名称和标签在下，垂直排列。

  /// 构建横屏模式头部（V1.2）
  ///
  /// 头像在左，歌手名称和标签在右，水平排列。
  /// 充分利用宽屏空间，减少垂直高度。

  /// 构建风格标签和听众数（V1.2）
  ///
  /// [align] 对齐方式，默认居中。

  /// 构建操作按钮行

  /// 构建歌手简介模块

  /// 显示同名歌手选择界面（V1.2）
  ///
  /// 当用户点击"切换歌手"按钮时，弹出搜索结果列表，
  /// 让用户选择正确的歌手。选择后跳转到对应歌手详情页。

  /// 显示歌手元数据编辑界面（V1.2）
  ///
  /// 当用户点击"编辑"按钮时，弹出编辑界面，
  /// 允许用户手动修改歌手头像和简介。

  /// 构建相似歌手部分（V1.1）
  ///
  /// 横向滚动列表，显示相似歌手头像和名称，点击跳转到对应歌手详情页。

  /// 构建专辑列表部分

  /// 构建专辑卡片

  /// 构建专辑占位图

  /// 构建歌曲列表部分

  /// 构建歌曲列表项

  /// 歌曲长按操作菜单

  /// 构建错误状态

  /// 播放全部歌曲

  /// 播放单首歌曲

  /// 显示所有专辑列表对话框

  /// 显示专辑详情对话框

  /// 构建专辑歌曲列表

  /// 格式化时长
}
