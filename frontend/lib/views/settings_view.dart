// 设置页面：主题、播放、字幕、存储、账户、关于等
// 优化：组件提取、配置化、UI 优化、新增功能

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show LicenseRegistry, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/artist_metadata_provider.dart';
import '../providers/server_registry_provider.dart';
import '../providers/service_mode_provider.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import '../services/artist_metadata_service.dart' show BatchScanResult;
import '../utils/app_preferences.dart'
    show AppPreferencesService, OrientationMode, FeedType;
import '../utils/constants.dart';
import '../utils/donate_colors.dart';
import '../utils/formatters.dart' show formatBytes;
import '../utils/logger.dart';
import '../utils/performance_monitor.dart';
import '../widgets/library_selector.dart';
import 'music/artist_batch_scan_dialog.dart';

// 设置页面常量定义（分离到单独文件）
part 'settings/settings_constants.dart';

// 设置页面辅助组件（分离到单独文件）
part 'settings/settings_widgets.dart';

// ==================== 主页面 ====================

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 音乐服务模式下隐藏视频相关分组（视频库/推荐/播放/字幕/统计/视频方向等）
    final isMusicMode = ref.watch(serviceModeProvider) == AppServiceMode.music;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: Row(
          children: [
            Icon(Icons.settings, color: scheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('设置'),
          ],
        ),
        // 搜索入口：快速定位 25+ 设置项
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索设置',
            onPressed: () => _showSettingsSearch(context, ref),
          ),
        ],
      ),
      body: ListView(
        // 底部避让刘海屏黑条区域
        padding: EdgeInsets.fromLTRB(
            0, 8, 0, 8 + MediaQuery.paddingOf(context).bottom),
        children: [
          // 视频库设置（PR #66：视频流 / 推荐可分别设置；音乐模式隐藏）
          if (!isMusicMode)
            _buildSection(
              context,
              ref,
              '视频库',
              Icons.video_library_outlined,
              Colors.deepPurple,
              [
                _buildFeedLibraryTile(context, ref),
                _buildFeedExcludePlayedTile(context, ref),
              ],
            ),
          // 规则筛选（PR：按 推荐/关注/发现 分区，让用户清楚每项规则作用于哪个页面）
          if (!isMusicMode)
            _buildSection(
              context,
              ref,
              '规则筛选',
              Icons.rule_outlined,
              Colors.pink,
              [
                _buildRuleScopeHint(context, ref),
                // 推荐页（默认展开）
                _RuleSection(
                  icon: Icons.recommend_outlined,
                  title: '推荐页',
                  initiallyExpanded: true,
                  childrenBuilder: () => [
                    _buildRecommendLibraryTile(context, ref),
                    _buildRecommendMinRatingTile(context, ref),
                    _buildRecommendExcludePlayedTile(context, ref),
                    _buildRecommendMinRuntimeTile(context, ref),
                    _buildRecommendIncludeTypesTile(context, ref),
                    // 高级选项折叠区：完播率门控、时间衰减、反疲劳、用户评分
                    _RecommendAdvancedTile(
                      advancedTilesBuilder: () => [
                        _buildRecommendUseWatchHistoryTile(context, ref),
                        _buildRecommendHalfLifeDaysTile(context, ref),
                        _buildRecommendAntiFatigueEnabledTile(context, ref),
                        _buildRecommendAntiFatigueDaysTile(context, ref),
                        _buildRecommendUserRatingEnabledTile(context, ref),
                        _buildRecommendUserRatingMinTile(context, ref),
                      ],
                    ),
                    // 推荐标签数据源映射（用户可自定义每个标签绑定的数据源）
                    const _RecommendTagMappingTile(),
                  ],
                ),
                // 关注页
                _RuleSection(
                  icon: Icons.person_pin_outlined,
                  title: '关注页',
                  childrenBuilder: () => [
                    _buildRecommendNextUpSeriesCountTile(context, ref),
                    _buildRecommendFavActorNewCountTile(context, ref),
                    _buildFollowActorVideoCountTile(context, ref),
                    _buildFollowOnlyUnwatchedTile(context, ref),
                    _buildSharedRuleHint(context, ref),
                  ],
                ),
                // 发现页
                _RuleSection(
                  icon: Icons.explore_outlined,
                  title: '发现页',
                  childrenBuilder: () => [
                    _buildDiscoverGenresTile(context, ref),
                  ],
                ),
              ],
            ),
          // 播放设置（音乐模式隐藏：均为视频播放器设置）
          if (!isMusicMode)
            _buildSection(
              context,
              ref,
              '播放',
              Icons.play_circle_outline,
              Colors.green,
              [
                _buildAutoPlayTile(context, ref),
                _buildAutoResumeAfterInterruptionTile(context, ref),
                _buildFullscreenGestureBackTile(context, ref),
                _buildPlaybackRateTile(context, ref),
                _buildGestureControlTile(context, ref),
              ],
            ),
          // 字幕设置（音乐模式隐藏）
          if (!isMusicMode)
            _buildSection(
              context,
              ref,
              '字幕',
              Icons.closed_caption_outlined,
              Colors.teal,
              [
                _buildSubtitleLanguageTile(context, ref),
                _buildSubtitleSizeTile(context, ref),
              ],
            ),
          // 外观设置（主题通用保留；视频方向仅视频模式）
          _buildSection(
            context,
            ref,
            '外观',
            Icons.palette_outlined,
            Colors.indigo,
            [
              _buildThemeTile(context, ref),
              if (!isMusicMode) _buildOrientationTile(context, ref),
            ],
          ),
          // 存储设置
          _buildSection(
            context,
            ref,
            '存储',
            Icons.storage_outlined,
            Colors.grey,
            [
              _buildCacheTile(context, ref),
              _buildResetSettingsTile(context, ref),
              _buildExportLogsTile(context, ref),
              _buildClearLogsTile(context, ref),
            ],
          ),
          // PR #81：观看统计（视频完播率，音乐模式隐藏）
          if (!isMusicMode)
            _buildSection(
              context,
              ref,
              '统计',
              Icons.analytics_outlined,
              Colors.deepPurple,
              [
                _buildWatchStatsTile(context, ref),
              ],
            ),
          // 服务器设置：服务模式（视频/音乐）+ 视频数据源
          // 音乐模式仅保留模式切换与服务器管理，隐藏视频数据源信息
          _buildSection(
            context,
            ref,
            '服务器',
            Icons.cloud_outlined,
            Colors.blue,
            [
              _buildServiceModeSelector(context, ref),
              _buildServerRegistryTile(context, ref),
              if (!isMusicMode) ...[
                _buildServerGroupLabel(
                    context, ref, '视频数据源', Icons.movie_outlined),
                _buildServerInfoTile(context, ref),
              ],
            ],
          ),
          // 音乐库设置：群晖 Audio Station 数据源 + 歌手元数据
          _buildSection(
            context,
            ref,
            '音乐库',
            Icons.library_music_outlined,
            const Color(0xFF2C8EF4),
            [
              _buildServerGroupLabel(
                  context, ref, '音乐数据源', Icons.library_music_outlined),
              _buildSynologyMusicTile(context, ref),
              _buildLastFmTile(context, ref),
              _buildNasMetadataSyncTile(context, ref),
              _buildServerGroupLabel(
                  context, ref, '歌手元数据', Icons.person_outline),
              _buildArtistMetadataCacheTile(context, ref),
              _buildBatchScanTile(context, ref),
            ],
          ),
          // 关于
          _buildSection(
            context,
            ref,
            '关于',
            Icons.info_outline,
            Colors.blueGrey,
            [
              _buildAboutTile(context, ref),
              _buildCheckUpdateTile(context, ref),
              _buildDonateTile(context, ref),
              _buildVersionTile(context, ref),
            ],
          ),
          // 开发者选项（仅开发模式显示）
          if (kDebugMode)
            _buildSection(
              context,
              ref,
              '开发者选项',
              Icons.developer_mode,
              Colors.purple,
              [
                _buildPerformanceMonitorTile(context, ref),
              ],
            ),
          // 账户
          _buildSection(
            context,
            ref,
            '账户',
            Icons.account_circle_outlined,
            Colors.blue,
            [
              _buildProfileTile(context, ref),
              _buildSelfSignedCertificateTile(context, ref),
            ],
          ),
          const SizedBox(height: _kSpacingXXLarge),
          _buildLogoutButton(context, ref),
          const SizedBox(height: _kSpacingXXXXLarge),
        ],
      ),
    );
  }

  // ==================== 分组构建 ====================

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData sectionIcon,
    Color sectionColor,
    List<Widget> children,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题：图标 + 文字，增加视觉层次
        Padding(
          padding: const EdgeInsets.fromLTRB(
              20, _kSectionTitleTopPadding, 20, _kSectionTitleVerticalPadding),
          child: Row(
            children: [
              Container(
                width: _kSectionIconContainerSize,
                height: _kSectionIconContainerSize,
                decoration: BoxDecoration(
                  color: sectionColor.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(_kSectionIconContainerRadius),
                ),
                child: Icon(sectionIcon,
                    color: sectionColor, size: _kSectionIconSize),
              ),
              const SizedBox(width: _kSectionIconTextSpacing),
              Text(
                title,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeMedium,
                  fontWeight: FontWeight.w700,
                  letterSpacing: _kSectionTitleLetterSpacing,
                ),
              ),
            ],
          ),
        ),
        // 卡片容器：圆角 + 阴影 + 边框
        // 修复：将背景色从 Container 移到 Material 上，避免 Container 的背景色
        // 遮挡 ListTile 的墨水效果（Flutter 警告：ListTile background invisible）
        Container(
          margin: const EdgeInsets.symmetric(
              horizontal: _kSectionCardHorizontalMargin),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kSectionCardRadius),
            border: Border.all(
              color:
                  scheme.onSurface.withValues(alpha: _kSectionCardBorderAlpha),
              width: _kSectionCardBorderWidth,
            ),
          ),
          child: Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(_kSectionCardRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _buildItemList(children),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildItemList(List<Widget> children) {
    final widgets = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      widgets.add(children[i]);
      if (i < children.length - 1) {
        widgets.add(const Divider(height: 1, indent: _kDividerIndent));
      }
    }
    return widgets;
  }

  // ==================== 设置项构建 ====================

  // 媒体库 - 视频流使用（PR #66）：chips 可视化预览已选数据源
  Widget _buildFeedLibraryTile(BuildContext context, WidgetRef ref) {
    final selectedLibraries = ref.watch(selectedLibrariesProvider);
    final feedType = ref.watch(feedTypeProvider);
    return _librarySelectionTile(
      icon: Icons.video_library_outlined,
      iconColor: Colors.deepPurple,
      title: _kTitleFeedLibrary,
      libraries: selectedLibraries,
      // 收藏夹模式：视频流数据源为收藏夹（收藏的影片/剧集/合集/演员）
      favoritesMode: feedType == FeedType.favorites,
      favoritesLabel: '收藏夹',
      onTap: () => LibrarySelector.show(context, scope: LibraryScope.feed),
      // 快捷移除单个媒体库 + SnackBar 撤销（防误操作）
      onChipTap: (libraryId) {
        final notifier = ref.read(selectedLibraryIdsProvider.notifier);
        final removedName = selectedLibraries
            .where((l) => l.id == libraryId)
            .map((l) => l.name)
            .firstOrNull;
        notifier.toggleLibrary(libraryId);
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(
          content: Text('已移除${removedName ?? "媒体库"}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => notifier.toggleLibrary(libraryId),
          ),
        ));
      },

      helpText:
          '选择首页视频流的数据源媒体库。\n\n· 可多选，视频流会合并展示所选媒体库的内容\n· 切换为「收藏夹」模式后，视频流改为展示收藏的影片/剧集/合集/演员\n· 点击 chips 可快速移除单个媒体库（支持撤销）\n\n提示：排除已观看等规则在此基础上生效。',
    );
  }

  // 媒体库 - 视频流排除已观看
  Widget _buildFeedExcludePlayedTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(feedExcludePlayedProvider);
    return _SwitchTile(
      icon: Icons.visibility_off_outlined,
      iconColor: Colors.teal,
      title: _kTitleExcludePlayed,
      subtitle: exclude ? '视频流不显示已看过的视频' : '已看过的也会显示',
      value: exclude,
      onChanged: (value) {
        ref.read(feedExcludePlayedProvider.notifier).setExclude(value);
      },
      helpText:
          '开启后，首页视频流不再显示已经看过（Emby 标记为已播放）的视频。\n\n关闭则已看过的视频也会出现在视频流中。\n\n注意：此开关只影响视频流与网格视图的过滤，不影响收藏、关注等其他页面。',
    );
  }

  // 媒体库 - 推荐使用（PR #66）：chips 可视化预览已选数据源
  Widget _buildRecommendLibraryTile(BuildContext context, WidgetRef ref) {
    final recommendLibraries = ref.watch(recommendLibrariesProvider);
    return _librarySelectionTile(
      icon: Icons.recommend_outlined,
      iconColor: Colors.pink,
      title: '推荐使用',
      libraries: recommendLibraries,
      favoritesMode: false,
      onTap: () => LibrarySelector.show(context, scope: LibraryScope.recommend),
      onChipTap: (libraryId) {
        final notifier = ref.read(recommendLibraryIdsProvider.notifier);
        final removedName = recommendLibraries
            .where((l) => l.id == libraryId)
            .map((l) => l.name)
            .firstOrNull;
        notifier.toggleLibrary(libraryId);
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(
          content: Text('已移除${removedName ?? "媒体库"}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => notifier.toggleLibrary(libraryId),
          ),
        ));
      },
      helpText:
          '选择「推荐页」使用的媒体库范围。\n\n推荐算法（相似推荐、高分、为你推荐等）只会从这些媒体库中取内容，未选中的媒体库不会出现在推荐页。\n\n可多选，点击 chips 可快速移除单个媒体库。',
    );
  }

  // 媒体库 - 发现标签（首页顶栏「发现」数据源，PRD）
  Widget _buildDiscoverGenresTile(BuildContext context, WidgetRef ref) {
    final discover = ref.watch(discoverProvider);
    final names = discover.genres
        .where((g) => discover.selectedGenreIds.contains(g.id))
        .map((g) => g.name)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final empty = discover.selectedGenreIds.isEmpty || names.isEmpty;
    return ListTile(
      leading:
          _IconContainer(icon: Icons.explore_outlined, color: Colors.orange),
      title: Text(
        '发现标签',
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: empty
            ? Text(
                '选择 Emby 标签，首页「发现」展示对应影片',
                style: TextStyle(
                  color: scheme.onSurfaceVariant
                      .withValues(alpha: _kTileSubtitleAlpha),
                  fontSize: _kFontSizeBody,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (names.isEmpty)
                    _libraryChip(
                      label: '已选 ${discover.selectedGenreIds.length} 个标签',
                      icon: Icons.sell_outlined,
                      color: scheme.onSurfaceVariant,
                      background: scheme.surfaceContainerHighest,
                    )
                  else
                    for (final name in names)
                      _libraryChip(
                        label: name,
                        icon: Icons.sell_outlined,
                        color: scheme.onSurfaceVariant,
                        background: scheme.surfaceContainerHighest,
                      ),
                ],
              ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _helpButton(
            helpText:
                '「发现标签」决定首页顶栏「发现」数据源展示的内容。\n\n· 选择 Emby 中的标签（类型/流派），发现页只展示对应标签的影片\n· 不选择时发现页为空或展示全部\n\n常用于自定义「发现」入口的浏览内容，与推荐、关注相互独立。',
            title: '发现标签',
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _showDiscoverGenresDialog(context, ref),
    );
  }

  // 发现标签多选对话框：拉取服务器类型列表，勾选保存
  Future<void> _showDiscoverGenresDialog(
      BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(discoverProvider.notifier);
    // 确保类型列表已加载
    await notifier.refreshGenres();
    final state = ref.read(discoverProvider);

    if (state.genres.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取标签列表，请检查服务器连接')),
      );
      return;
    }

    // 本地副本供勾选（不直接改 provider，点确定才保存）
    final selected = Set<String>.from(state.selectedGenreIds);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: const Text('选择发现标签'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) => ListView.builder(
              itemCount: state.genres.length,
              itemBuilder: (context, i) {
                final g = state.genres[i];
                final checked = selected.contains(g.id);
                return CheckboxListTile(
                  value: checked,
                  title:
                      Text(g.name, style: TextStyle(color: scheme.onSurface)),
                  dense: true,
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      selected.add(g.id);
                    } else {
                      selected.remove(g.id);
                    }
                  }),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(discoverProvider.notifier)
                  .saveSelection(selected.toList());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // PR #78：推荐 - 评分阈值
  Widget _buildRecommendMinRatingTile(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(recommendMinRatingProvider);
    return _TapTile(
      icon: Icons.star_outline,
      iconColor: Colors.amber,
      title: '评分阈值',
      subtitle: rating == 0 ? '不过滤' : '≥ $rating',
      onTap: () => _showRecommendRatingDialog(context, ref, rating),
      helpText:
          '设置推荐内容的最低评分门槛。\n\n只有 Emby 社区评分（CommunityRating）≥ 该值的影片才会进入推荐页，用于过滤烂片。\n\n· 默认 4.0\n· 调高 → 推荐更精但内容更少\n· 调低 → 内容更多但质量参差\n\n注意：仅影响「高分」等评分相关数据源。',
    );
  }

  // PR #78：推荐 - 排除已观看
  Widget _buildRecommendExcludePlayedTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(recommendExcludePlayedProvider);
    return _SwitchTile(
      icon: Icons.visibility_off_outlined,
      iconColor: Colors.brown,
      title: '排除已观看',
      subtitle: exclude ? '不再推荐已看过的视频' : '已看过的也会推荐',
      value: exclude,
      onChanged: (value) {
        ref.read(recommendExcludePlayedProvider.notifier).setExclude(value);
      },
      helpText:
          '开启后，推荐页不再展示你已经看过的视频。\n\n适合想发现新内容的场景；关闭则推荐中会混入已看过的内容。\n\n与「视频流排除已观看」互不影响，两者独立生效。',
    );
  }

  // PR #78：推荐 - 最短时长
  Widget _buildRecommendMinRuntimeTile(BuildContext context, WidgetRef ref) {
    final sec = ref.watch(recommendMinRuntimeSecProvider);
    return _TapTile(
      icon: Icons.timer_outlined,
      iconColor: Colors.deepOrange,
      title: '最短时长',
      subtitle: sec == 0 ? '不过滤' : '$sec 秒以上',
      onTap: () => _showRecommendRuntimeDialog(context, ref, sec),
      helpText:
          '过滤推荐内容的最短时长（秒）。\n\n短于该时长的内容（如短片、花絮）不会出现在推荐页。\n\n· 默认 30 秒；设为 0 则不过滤\n· 调大可过滤短片、预告片',
    );
  }

  // 推荐评分阈值对话框
  void _showRecommendRatingDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 使用 StatefulBuilder 让 Slider 拖动时能局部刷新显示值
    // 避免 provider 更新后 dialog 内显示值仍为旧值的 UI 不一致问题
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('评分阈值'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current == 0 ? '不过滤' : '≥ ${current.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: _kFontSizeXXLarge, fontWeight: FontWeight.bold),
                ),
                Slider(
                  min: 0,
                  max: 10,
                  divisions: 20,
                  value: current,
                  label: current == 0 ? '不过滤' : current.toStringAsFixed(1),
                  // 拖动时仅更新 UI 显示值，松手时才写入持久化，减少无效写入
                  onChanged: (v) {
                    setDialogState(() => current = v);
                  },
                  onChangeEnd: (v) {
                    ref.read(recommendMinRatingProvider.notifier).setRating(v);
                  },
                ),
                const Text(
                  '0 = 不过滤；越高越严格（小众片变少）',
                  style:
                      TextStyle(fontSize: _kFontSizeSmall, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 推荐最短时长对话框
  void _showRecommendRuntimeDialog(
      BuildContext context, WidgetRef ref, int current) {
    // StatefulBuilder：Slider 拖动时局部刷新显示值
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('最短时长'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current == 0 ? '不过滤' : '$current 秒以上',
                  style: const TextStyle(
                      fontSize: _kFontSizeXXLarge, fontWeight: FontWeight.bold),
                ),
                Slider(
                  min: 0,
                  max: 600,
                  divisions: 30,
                  value: current.toDouble().clamp(0, 600),
                  label: current == 0 ? '不过滤' : '${current}s',
                  // 拖动时仅更新 UI 显示值，松手时才写入持久化，减少无效写入
                  onChanged: (v) {
                    setDialogState(() => current = v.round());
                  },
                  onChangeEnd: (v) {
                    ref
                        .read(recommendMinRuntimeSecProvider.notifier)
                        .setMinRuntime(v.round());
                  },
                ),
                const Text(
                  '过滤测试片 / 预告片（默认 30s）',
                  style:
                      TextStyle(fontSize: _kFontSizeSmall, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }

  // PR #79：推荐 - 类型偏好
  // 5 个可切换的类型（多选）
  static const Map<String, String> _kRecommendTypeLabels = {
    'Movie': '电影',
    'Episode': '剧集',
    'Video': '视频',
    'MusicVideo': '音乐视频',
    'Series': '电视剧',
  };

  Widget _buildRecommendIncludeTypesTile(BuildContext context, WidgetRef ref) {
    final types = ref.watch(recommendIncludeTypesProvider);
    return _TapTile(
      icon: Icons.category_outlined,
      iconColor: Colors.indigo,
      title: '推荐类型',
      subtitle: _formatTypes(types),
      onTap: () => _showRecommendTypesDialog(context, ref, types),
      helpText:
          '选择推荐页包含的内容类型。\n\n可勾选：电影 / 剧集 / 单集 / 视频 / 音乐视频等。\n\n未勾选的类型不会出现在推荐结果中，用于控制推荐内容的体裁范围。',
    );
  }

  String _formatTypes(Set<String> types) {
    if (types.length == 5) return '全部类型';
    return types.map((t) => _kRecommendTypeLabels[t] ?? t).toList().join('、');
  }

  void _showRecommendTypesDialog(
      BuildContext context, WidgetRef ref, Set<String> current) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('推荐类型'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: _kRecommendTypeLabels.entries.map((entry) {
                  final type = entry.key;
                  final label = entry.value;
                  final checked = current.contains(type);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (_) async {
                      await ref
                          .read(recommendIncludeTypesProvider.notifier)
                          .toggle(type);
                      if (!context.mounted) return;
                      setLocalState(() {});
                    },
                    title: Text(label),
                    dense: true,
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // PR #85：完播率门控开关
  // - 关闭：推荐结果完全由 Emby 服务器决定（不应用黑名单/权重/种子）
  // - 开启：根据你的完播率历史优化推荐（默认）
  Widget _buildRecommendUseWatchHistoryTile(
      BuildContext context, WidgetRef ref) {
    final useWatchHistory = ref.watch(recommendUseWatchHistoryProvider);
    return _SwitchTile(
      icon: Icons.history_toggle_off_outlined,
      iconColor: Colors.deepPurple,
      title: '使用观看历史优化推荐',
      subtitle:
          useWatchHistory ? '已开启：黑名单、源权重、相似种子生效' : '已关闭：推荐结果仅由 Emby 服务器决定',
      value: useWatchHistory,
      onChanged: (value) {
        ref.read(recommendUseWatchHistoryProvider.notifier).setUse(value);
      },
      helpText:
          '开启后，推荐算法会参考你的观看历史计算相似推荐与「为你推荐」。\n\n· 开启 → 推荐更贴合你的口味（需要服务器端有播放记录）\n· 关闭 → 推荐退化为冷启动策略（按评分/热度）\n\n关闭时「相似」标签可能没有数据。',
    );
  }

  // PR #85：时间衰减半衰期（天）
  // - 0 天 = 不衰减（所有完播记录等权重）
  // - 14 天 = 默认（14 天前的记录权重衰减到 0.5）
  // - 范围 0-90 天
  Widget _buildRecommendHalfLifeDaysTile(BuildContext context, WidgetRef ref) {
    final halfLifeDays = ref.watch(recommendHalfLifeDaysProvider);
    return _TapTile(
      icon: Icons.timelapse_outlined,
      iconColor: Colors.brown,
      title: '记忆半衰期（天）',
      subtitle:
          halfLifeDays == 0 ? '不衰减，所有记录等权重' : '$halfLifeDays 天前的记录权重衰减到 0.5',
      onTap: () => _showHalfLifeDaysDialog(context, ref, halfLifeDays),
      helpText:
          '时间衰减半衰期（天）。\n\n观看历史对推荐的影响随时间衰减：半衰期越短，越久远的观看记录权重越低，推荐越偏向近期口味。\n\n· 默认 14 天\n· 调小 → 只看近期偏好\n· 调大 → 长期偏好更稳定',
    );
  }

  void _showHalfLifeDaysDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 预设值：0, 3, 7, 14, 30, 60, 90
    final options = <double>[0, 3, 7, 14, 30, 60, 90];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder：选中后立即更新选中态视觉反馈，不立即关闭对话框
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('记忆半衰期'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '越短 = 推荐越关注最近的偏好；越长 = 老的偏好也会影响推荐。\n0 = 不衰减',
                      style: TextStyle(fontSize: _kFontSizeBody),
                    ),
                  ),
                  ...options.map((days) {
                    final selected = current == days;
                    return RadioListTile<double>(
                      value: days,
                      groupValue: current,
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref
                            .read(recommendHalfLifeDaysProvider.notifier)
                            .setDays(v);
                        if (!dialogContext.mounted) return;
                        setLocalState(() => current = v);
                      },
                      title: Text(days == 0 ? '不衰减 (0 天)' : '$days 天'),
                      dense: true,
                      selected: selected,
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // PR #88：反推荐疲劳开关
  // - 关闭：所有展示过的 item 也会被重推
  // - 开启：X 天内展示过的 item 不再推荐
  Widget _buildRecommendAntiFatigueEnabledTile(
      BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(recommendAntiFatigueEnabledProvider);
    return _SwitchTile(
      icon: Icons.repeat_on_outlined,
      iconColor: Colors.indigo,
      title: '避免重复推荐',
      // 同时 watch 天数 provider，使 subtitle 随天数变化实时更新
      subtitle: enabled
          ? '已开启：${ref.watch(recommendAntiFatigueDaysProvider)} 天内不重推'
          : '已关闭：所有 item 都可能被推荐',
      value: enabled,
      onChanged: (value) {
        ref
            .read(recommendAntiFatigueEnabledProvider.notifier)
            .setEnabled(value);
      },

      helpText:
          '反疲劳机制：避免同一演员/导演的内容在推荐中连续刷屏。\n\n开启后，推荐结果会限制同一创作者的视频出现密度，浏览体验更丰富。\n\n适合关注演员数量较少、内容高度集中的场景。',
    );
  }

  // PR #88：反推荐疲劳天数（默认 30，范围 1-90）
  Widget _buildRecommendAntiFatigueDaysTile(
      BuildContext context, WidgetRef ref) {
    final days = ref.watch(recommendAntiFatigueDaysProvider);
    return _TapTile(
      icon: Icons.history_toggle_off,
      iconColor: Colors.deepOrange,
      title: '不重推天数',
      subtitle: '$days 天内展示过的 item 不再推荐',
      onTap: () => _showAntiFatigueDaysDialog(context, ref, days),
      helpText:
          '反疲劳窗口（天）：在多少天内对同一创作者的内容去重/限流。\n\n窗口越大，同一创作者的内容被限制的时间越长。\n\n与「反疲劳开关」配合使用，仅在开启时生效。',
    );
  }

  void _showAntiFatigueDaysDialog(
      BuildContext context, WidgetRef ref, int current) {
    // 预设值：1, 3, 7, 14, 30, 60, 90
    final options = <int>[1, 3, 7, 14, 30, 60, 90];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder：选中后立即更新选中态视觉反馈，不立即关闭对话框
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('不重推天数'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '越长 = 越不容易看到重复内容；越短 = 推荐变化越快。',
                      style: TextStyle(fontSize: _kFontSizeBody),
                    ),
                  ),
                  ...options.map((d) {
                    final selected = current == d;
                    return RadioListTile<int>(
                      value: d,
                      groupValue: current,
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref
                            .read(recommendAntiFatigueDaysProvider.notifier)
                            .setDays(v);
                        if (!dialogContext.mounted) return;
                        setLocalState(() => current = v);
                      },
                      title: Text('$d 天'),
                      dense: true,
                      selected: selected,
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 关注：取最近几部剧的下一集（默认 5，范围 1-10）
  Widget _buildRecommendNextUpSeriesCountTile(
      BuildContext context, WidgetRef ref) {
    final count = ref.watch(recommendNextUpSeriesCountProvider);
    return _TapTile(
      icon: Icons.live_tv,
      iconColor: Colors.teal,
      title: '关注·最近剧集数',
      subtitle: '展示最近 $count 部剧的下一集',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·最近剧集数',
        current: count,
        min: 1,
        max: 10,
        label: (v) => '$v 部',
        description: '数量越多，你正在追的剧续播排得越靠前；太少会只剩演员新片。',
        apply: (v) =>
            ref.read(recommendNextUpSeriesCountProvider.notifier).setCount(v),
      ),
      helpText:
          '「关注」视频流中，每个已收藏剧集最多展示的「最近剧集」数量。\n\n用于控制关注页的剧集内容密度。\n\n· 默认 5\n· 调大 → 关注页出现更多连续剧集',
    );
  }

  // 关注：收藏演员新作品条数（默认 20，范围 5-40）
  Widget _buildRecommendFavActorNewCountTile(
      BuildContext context, WidgetRef ref) {
    final count = ref.watch(recommendFavActorNewCountProvider);
    return _TapTile(
      icon: Icons.person,
      iconColor: Colors.indigo,
      title: '关注·演员新片数',
      subtitle: '收藏演员新作品展示 $count 条',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·演员新片数',
        current: count,
        min: 5,
        max: 40,
        label: (v) => '$v 条',
        description: '控制收藏演员新作品在关注页里占多少条。',
        apply: (v) =>
            ref.read(recommendFavActorNewCountProvider.notifier).setCount(v),
      ),
      helpText:
          '「关注」视频流中，每位已收藏演员最多展示的新作品数量。\n\n· 默认 20（范围 5–40）\n· 调大 → 每位演员展示更多作品\n\n只影响关注页，不影响其他页面。',
    );
  }

  // 关注页：每演员视频数（默认 3，范围 1-10）
  Widget _buildFollowActorVideoCountTile(BuildContext context, WidgetRef ref) {
    final count = ref.watch(followActorVideoCountProvider);
    return _TapTile(
      icon: Icons.person_add_alt,
      iconColor: Colors.indigo,
      title: '关注·每演员视频数',
      subtitle: '每个收藏演员展示 $count 条',
      onTap: () => _showCountSliderDialog(
        context,
        ref,
        title: '关注·每演员视频数',
        current: count,
        min: 1,
        max: 10,
        label: (v) => '$v 条',
        description: '关注视频流按演员逐个拉取，每个收藏演员最多显示 N 条视频。',
        apply: (v) =>
            ref.read(followActorVideoCountProvider.notifier).setCount(v),
      ),
      helpText:
          '「关注·每演员视频数」：关注视频流中每位演员最多展示的视频数量。\n\n· 范围 1–10，默认 3\n· 调小 → 关注流更紧凑、刷新更快\n· 调大 → 每位演员展示更多视频，加载更慢\n\n只在「关注」页面生效。',
    );
  }

  // 关注页：只看未观看（默认开）
  Widget _buildFollowOnlyUnwatchedTile(BuildContext context, WidgetRef ref) {
    final onlyUnwatched = ref.watch(followOnlyUnwatchedProvider);
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: _helpButton(
        helpText:
            '开启后，「关注」视频流只显示你尚未观看过的视频。\n\n· 开启 → 已看过的视频不会出现在关注视频流，方便追新\n· 关闭 → 已看过的视频也会显示\n\n「已观看」依据 Emby 服务器记录的播放状态判断。',
        title: '关注·只看未观看',
      ),
      title: const Text('关注·只看未观看'),
      subtitle: Text(
        onlyUnwatched ? '已看过的视频不会出现在关注视频流' : '已看过的视频也会显示',
        style: TextStyle(
          fontSize: _kFontSizeSmall,
          color: scheme.onSurfaceVariant,
        ),
      ),
      value: onlyUnwatched,
      onChanged: (v) =>
          ref.read(followOnlyUnwatchedProvider.notifier).setOnlyUnwatched(v),
    );
  }

  // 通用数量滑块对话框
  void _showCountSliderDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int current,
    required int min,
    required int max,
    required String Function(int v) label,
    required String description,
    required Future<void> Function(int v) apply,
  }) {
    var value = current.toDouble();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setLocalState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(description,
                    style: const TextStyle(fontSize: _kFontSizeBody)),
              ),
              Text(label(value.round()),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Slider(
                value: value,
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: label(value.round()),
                onChanged: (v) => setLocalState(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await apply(value.round());
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  // PR #89：用户评分加权开关
  // - 关闭：仅按 communityRating 过滤（已有逻辑）
  // - 开启：用户评分 < 阈值的 item 也跳过（除非收藏）
  Widget _buildRecommendUserRatingEnabledTile(
      BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(recommendUserRatingEnabledProvider);
    return _SwitchTile(
      icon: Icons.star_rate_outlined,
      iconColor: Colors.purple,
      title: '用户评分加权',
      // 同时 watch 阈值 provider，使 subtitle 随阈值变化实时更新
      subtitle: enabled
          ? '已开启：跳过用户评分 < ${ref.watch(recommendUserRatingMinProvider).toStringAsFixed(1)} 的 item（收藏项豁免）'
          : '已关闭：仅按社区评分过滤',
      value: enabled,
      onChanged: (value) {
        ref.read(recommendUserRatingEnabledProvider.notifier).setEnabled(value);
      },

      helpText:
          '开启后，推荐结果额外按你的个人评分（UserRating）加权。\n\n适合你给影片打过分的场景：高分内容更容易出现在推荐中。\n\n关闭则仅按社区评分/热度推荐。',
    );
  }

  // PR #89：用户评分最低阈值（0-10，默认 4.0）
  Widget _buildRecommendUserRatingMinTile(BuildContext context, WidgetRef ref) {
    final minRating = ref.watch(recommendUserRatingMinProvider);
    return _TapTile(
      icon: Icons.star_half,
      iconColor: Colors.deepPurple,
      title: '最低用户评分',
      subtitle: minRating == 0 ? '不过滤' : '≥ $minRating（0-10）',
      onTap: () => _showUserRatingMinDialog(context, ref, minRating),
      helpText:
          '设置个人评分参与推荐的阈值：只有你打分 ≥ 该值的内容才计入推荐加权。\n\n· 默认 4.0\n· 调高 → 只信任你的高分评价\n· 调低 → 更多打分参与推荐\n\n仅在「个人评分参与推荐」开启时生效。',
    );
  }

  void _showUserRatingMinDialog(
      BuildContext context, WidgetRef ref, double current) {
    // 预设值：0（关闭）/ 3.0 / 4.0 / 5.0 / 6.0 / 7.0 / 8.0
    final options = <double>[0, 3, 4, 5, 6, 7, 8];
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder：选中后立即更新选中态视觉反馈，不立即关闭对话框
        return StatefulBuilder(
          builder: (_, setLocalState) {
            return AlertDialog(
              title: const Text('最低用户评分'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '用户评分 < 阈值的 item 不再推荐（收藏项豁免）。0 = 关闭该过滤。',
                      style: TextStyle(fontSize: _kFontSizeBody),
                    ),
                  ),
                  ...options.map((d) {
                    final selected = (current - d).abs() < 0.01;
                    return RadioListTile<double>(
                      value: d,
                      groupValue: current,
                      onChanged: (v) async {
                        if (v == null) return;
                        await ref
                            .read(recommendUserRatingMinProvider.notifier)
                            .setMin(v);
                        if (!dialogContext.mounted) return;
                        setLocalState(() => current = v);
                      },
                      title: Text(d == 0 ? '0（关闭）' : '≥ $d'),
                      dense: true,
                      selected: selected,
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('完成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 播放 - 自动播放
  Widget _buildAutoPlayTile(BuildContext context, WidgetRef ref) {
    final isAutoPlay = ref.watch(isAutoPlayProvider);
    return _SwitchTile(
      icon: Icons.play_circle_outline,
      iconColor: Colors.green,
      title: _kTitleAutoPlay,
      subtitle: _kSubtitleAutoPlay,
      value: isAutoPlay,
      onChanged: (value) {
        ref.read(isAutoPlayProvider.notifier).setEnabled(value);
      },
      helpText:
          '开启后，视频播放完成会自动播放下一个推荐视频。\n\n· 开启 → 连续播放，适合刷视频场景\n· 关闭 → 播完停止，返回视频信息页\n\n在视频流的「自动连播」体验与手动浏览之间切换。',
    );
  }

  // 播放 - 焦点恢复自动续播（来电结束后是否自动恢复播放）
  Widget _buildAutoResumeAfterInterruptionTile(
      BuildContext context, WidgetRef ref) {
    final autoResume = ref.watch(autoResumeAfterInterruptionProvider);
    return _SwitchTile(
      icon: Icons.phone_in_talk_outlined,
      iconColor: Colors.green,
      title: '焦点恢复自动续播',
      subtitle: '来电结束后自动恢复播放',
      value: autoResume,
      onChanged: (value) {
        ref.read(autoResumeAfterInterruptionProvider.notifier).set(value);
      },
      helpText:
          '开启后，播放因来电、通知、切后台等中断时，回到 App 会自动恢复到中断位置继续播放。\n\n关闭则中断后回到视频开头。\n\n与「播放位置记忆」配合使用，中断恢复更流畅。',
    );
  }

  // 播放 - 全屏排除边缘返回手势（Android 手势导航）
  Widget _buildFullscreenGestureBackTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(fullscreenGestureBackExcludedProvider);
    return _SwitchTile(
      icon: Icons.swipe_outlined,
      iconColor: Colors.indigo,
      title: '全屏禁用手势返回',
      subtitle: '全屏时禁用系统边缘返回手势，避免拖进度误退全屏',
      value: exclude,
      onChanged: (value) {
        ref.read(fullscreenGestureBackExcludedProvider.notifier).set(value);
      },
      helpText:
          '全屏播放时，允许通过手势（如右滑/下滑）返回上一页。\n\n· 开启 → 手势返回更顺手\n· 关闭 → 只能用系统返回键退出全屏\n\n避免误触退出全屏时建议关闭。',
    );
  }

  // 播放 - 默认倍速
  Widget _buildPlaybackRateTile(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(defaultPlaybackRateProvider);
    return _TapTile(
      icon: Icons.speed_outlined,
      iconColor: Colors.orange,
      title: _kTitlePlaybackRate,
      subtitle: '${rate.toStringAsFixed(1)}x',
      onTap: () => _showPlaybackRateDialog(context, ref, rate),
      helpText: '设置视频默认播放倍速。\n\n支持 0.5x–2.0x。播放器播放时会使用该倍速，播放中也可临时调整。',
    );
  }

  // 播放 - 手势控制
  Widget _buildGestureControlTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.touch_app_outlined,
      iconColor: Colors.purple,
      title: _kTitleGestureControl,
      subtitle: _kSubtitleGestureControl,
      onTap: () => _showGestureControlDialog(context),
      helpText:
          '设置视频播放页的手势控制方式。\n\n支持：单击暂停/播放、双击快进快退、左右滑动调节进度、上下滑动调节亮度/音量等。\n\n可在此开关或调整各项手势灵敏度。',
    );
  }

  // 字幕 - 默认语言
  Widget _buildSubtitleLanguageTile(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(defaultSubtitleLanguageProvider);
    return _TapTile(
      icon: Icons.closed_caption_outlined,
      iconColor: Colors.teal,
      title: '默认字幕语言',
      subtitle: lang.isEmpty ? '关闭' : _getLanguageName(lang),
      onTap: () => _showSubtitleDialog(context, ref, lang),
      helpText:
          '选择默认字幕语言。\n\n当视频含多语言字幕时，优先加载该语言字幕。\n\n· 跟随系统 → 使用设备语言\n· 指定语言 → 始终加载指定字幕\n\n如果服务器没有该语言字幕则回退到默认字幕。',
    );
  }

  // 字幕 - 字幕大小
  Widget _buildSubtitleSizeTile(BuildContext context, WidgetRef ref) {
    final size = ref.watch(subtitleSizeProvider);
    return _TapTile(
      icon: Icons.format_size_outlined,
      iconColor: Colors.teal,
      title: '字幕大小',
      subtitle: _subtitleSizeLabel(size),
      onTap: () => _showSubtitleSizeDialog(context, ref, size),
      helpText: '调节字幕显示大小。\n\n· 偏小 → 画面更干净\n· 偏大 → 字幕更清晰\n\n实时预览，无需重启。',
    );
  }

  // 外观 - 主题
  Widget _buildThemeTile(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return _TapTile(
      icon: Icons.dark_mode_outlined,
      iconColor: Colors.indigo,
      title: _kTitleTheme,
      subtitle: _themeLabel(themeMode),
      onTap: () => _showThemeDialog(context, ref, themeMode),
      helpText:
          '选择 App 主题：跟随系统 / 浅色 / 深色。\n\n· 跟随系统 → 随设备深色模式自动切换\n· 深色 → 夜间观看更舒适\n\n设置后立即生效。',
    );
  }

  // 外观 - 方向过滤
  Widget _buildOrientationTile(BuildContext context, WidgetRef ref) {
    final orientationMode = ref.watch(orientationModeProvider);
    return _TapTile(
      icon: Icons.screen_rotation_outlined,
      iconColor: Colors.indigo,
      title: '视频方向',
      subtitle: orientationMode.zhLabel,
      onTap: () => _showOrientationDialog(context, ref, orientationMode),
      helpText:
          '设置视频播放时的屏幕方向。\n\n· 跟随系统 → 横竖屏自由旋转\n· 横屏 → 播放强制横屏（适合大屏观影）\n· 竖屏 → 保持竖屏浏览',
    );
  }

  // 存储 - 清除缓存
  Widget _buildCacheTile(BuildContext context, WidgetRef ref) {
    final cacheSize = ref.watch(cacheSizeProvider);
    return _TapTile(
      icon: Icons.cleaning_services_outlined,
      iconColor: Colors.grey,
      title: '清除缓存',
      subtitle: formatBytes(cacheSize),
      onTap: () => _showClearCacheDialog(context, ref),
      helpText:
          '管理图片/视频封面缓存。\n\n· 查看当前缓存占用\n· 一键清理缓存释放存储空间\n\n封面缓存用于加速列表加载；清理后需重新下载，但不会丢失任何数据。',
    );
  }

  // 存储 - 歌手元数据缓存管理（V1.1）
  // 查看歌手简介/头像缓存大小，支持单独清除
  Widget _buildArtistMetadataCacheTile(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: ref.read(artistMetadataServiceProvider).getCacheSize(),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        return _TapTile(
          icon: Icons.person_outline,
          iconColor: Colors.purple,
          title: '歌手元数据缓存',
          subtitle: '简介/头像缓存 ${formatBytes(size)}，点击清除',
          onTap: () => _showClearArtistMetadataDialog(context, ref),
          helpText:
              '管理艺术家/歌手元数据缓存（头像、简介等）。\n\n· 查看缓存条目数\n· 清理缓存后，歌手详情将从数据源重新拉取\n\n适用于音乐服务模式。',
        );
      },
    );
  }

  // 存储 - 批量补全歌手元数据（V1.2）
  // 扫描音乐库中所有歌手，批量获取缺失的头像和简介
  Widget _buildBatchScanTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.auto_fix_high,
      iconColor: Colors.teal,
      title: _kTitleBatchScan,
      subtitle: '扫描音乐库中所有歌手，批量获取缺失的头像和简介',
      onTap: () => _startBatchScan(context, ref),
      helpText:
          '批量扫描设置：控制启动/刷新时是否全量扫描服务器内容。\n\n· 开启 → 启动后自动拉取最新媒体库（耗流量、加载慢）\n· 关闭 → 只加载本地缓存（加载快、内容可能滞后）\n\n建议在内容更新频繁时开启，日常使用可关闭。',
    );
  }

  // 开始批量扫描
  Future<void> _startBatchScan(BuildContext context, WidgetRef ref) async {
    // 检查是否已登录群晖
    final authState = ref.read(synologyAuthProvider);
    if (!authState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text(_kHintLoginFirst),
          duration: Duration(seconds: _kSnackBarDurationShort),
        ),
      );
      return;
    }

    // 获取音乐库中所有歌手
    try {
      final api = ref.read(synologyAuthProvider.notifier).api;
      // 分页遍历所有歌曲，只收集歌手名，不保留整首歌对象，避免大库 OOM
      final artistSet = <String>{};
      int offset = 0;
      const int limit = 200;
      while (true) {
        final batch = await api.getSongs(offset: offset, limit: limit);
        if (batch.isEmpty) break;
        for (final s in batch) {
          final name = s.artistDisplay;
          if (name.isNotEmpty) artistSet.add(name);
        }
        if (batch.length < limit) break;
        offset += limit;
      }
      final artistNames = artistSet.toList();

      if (!context.mounted) return; // 修复：异步后检查 context.mounted
      if (artistNames.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text(_kHintNoArtists),
            duration: Duration(seconds: _kSnackBarDurationShort),
          ),
        );
        return;
      }

      // 显示批量扫描对话框
      if (context.mounted) {
        final result = await showDialog<BatchScanResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ArtistBatchScanDialog(
            artistNames: artistNames,
          ),
        );

        if (result != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描完成：${result.summary}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return; // 修复：异步后检查 context.mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取歌手列表失败：${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 显示清除歌手元数据缓存对话框
  Future<void> _showClearArtistMetadataDialog(
      BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除歌手元数据缓存'),
        content: const Text('确定要清除所有歌手简介和头像缓存吗？清除后下次访问歌手时将重新从网络获取。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(artistMetadataServiceProvider).clearAllCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('歌手元数据缓存已清除'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 存储 - 重置所有偏好设置到默认值
  // 仅清除"设置类"偏好，不影响登录信息、观看历史、收藏等用户数据
  Widget _buildResetSettingsTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.restore,
      iconColor: Colors.deepOrange,
      title: '重置设置',
      subtitle: '恢复所有偏好为默认值（不影响登录/历史/收藏）',
      onTap: () => _showResetSettingsDialog(context, ref),
      helpText:
          '将所有设置恢复为默认值。\n\n不影响：登录的服务器、观看历史、收藏数据。\n\n仅重置本页可见的偏好项，操作不可撤销，建议先确认当前配置。',
    );
  }

  // 存储 - 导出错误日志（P2 新增）
  // 将内存中的 WARN/ERROR 日志导出到文件，并复制路径到剪贴板
  // 使用 Clipboard 替代 share_plus，避免引入额外依赖
  Widget _buildExportLogsTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.file_download_outlined,
      iconColor: Colors.blueGrey,
      title: '导出日志',
      subtitle: '导出最近 500 条 WARN/ERROR 日志用于排查',
      onTap: () => _exportLogs(context),
      helpText:
          '将最近 500 条 WARN/ERROR 日志导出为文本文件，并复制文件路径到剪贴板。\n\n用于排查崩溃、加载失败等异常，提交反馈时可附带该日志。',
    );
  }

  // 存储 - 清除已持久化的日志文件（P2 新增）
  // 清除内存缓冲区和磁盘上的日志文件
  Widget _buildClearLogsTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.delete_outline,
      iconColor: Colors.red,
      title: '清除日志',
      subtitle: '删除本地保存的日志文件',
      onTap: () => _showClearLogsDialog(context),
      helpText: '删除本地保存的日志文件（内存缓冲区 + 磁盘文件）。\n\n清除后无法恢复；排查问题时建议先导出再清除。',
    );
  }

  // PR #81：观看统计 tile
  // - 显示总次数 + 平均完播率
  // - 点击查看详情 + 清除按钮
  Widget _buildWatchStatsTile(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(watchStatsProvider);
    final avg = (stats.avgCompletion * 100).toStringAsFixed(0);
    return _TapTile(
      icon: Icons.analytics_outlined,
      iconColor: Colors.deepPurple,
      title: '观看统计',
      subtitle: stats.totalCount == 0
          ? '暂无数据'
          : '总 ${stats.totalCount} 次 · 平均完播率 $avg%',
      onTap: () => _showWatchStatsDialog(context, ref),
      helpText: '查看本机观看统计：总播放次数、平均完播率。\n\n点击可查看详情并支持清空统计。\n\n数据仅保存在本机，不会上传。',
    );
  }

  // 服务器 - 服务器管理入口（多服务器控制台）
  Widget _buildServerRegistryTile(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverRegistryProvider);
    final active = ref.watch(activeServerProvider);
    return _TapTile(
      icon: Icons.dns_outlined,
      iconColor: Colors.blueGrey,
      title: '服务器管理',
      subtitle: servers.isEmpty
          ? '配置 Emby / 群晖等多台服务器并快速切换'
          : '${servers.length} 台服务器 · 当前：${active?.name ?? '未激活'}',
      onTap: () => context.push('/servers'),
      helpText:
          '管理已配置的服务器（Emby / Jellyfin / 群晖 Audio Station 等）。\n\n· 查看已添加的服务器列表与状态\n· 添加、编辑、删除服务器\n· 快速切换当前使用的服务器\n\n切换服务器后，媒体库/登录状态跟随切换。',
    );
  }

  // 服务器 - 服务模式选择（视频服务 / 音乐服务）
  Widget _buildServiceModeSelector(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(serviceModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<AppServiceMode>(
            segments: [
              for (final m in AppServiceMode.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.label),
                  icon: Icon(m.icon, size: 16),
                ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) async {
              final next = selection.first;
              if (next == mode) return;
              await ref.read(serviceModeProvider.notifier).setMode(next);
              if (!context.mounted) return;
              // 切换模式后回到首页，立即展示对应界面
              context.go('/');
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: _kFontSizeBody)),
            ),
          ),
          const SizedBox(height: _kSpacingMedium),
          Text(
            mode == AppServiceMode.music
                ? '首页将显示音乐库界面（群晖 Audio Station）'
                : '首页将显示视频流界面（Emby / Plex）',
            style: TextStyle(
                fontSize: _kFontSizeSmall, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // 服务器 - 数据源分组标签（视频 / 音乐）
  /// 规则筛选子分区折叠卡片：推荐/关注/发现 各页面设置分区
  static Widget _ruleSectionDivider(ColorScheme scheme) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: scheme.outlineVariant.withValues(alpha: 0.4),
    );
  }

  /// 规则筛选分组顶部引导：说明分组结构与生效时机
  Widget _buildRuleScopeHint(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(
        '以下规则按 推荐 / 关注 / 发现 页面分类设置。'
        '媒体库、标签等数据源修改后实时生效；评分、时长等规则在刷新页面后生效。',
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 规则筛选 - 关注页共享规则说明
  /// 评分/时长/类型等规则与推荐页共用同一开关（关注内容同样经过过滤），
  /// 避免用户误以为需要到推荐页单独配置。
  Widget _buildSharedRuleHint(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Text(
        '评分阈值 / 最短时长 / 包含类型 / 排除已观看 等规则与推荐页共用同一开关，'
        '一个设置同时作用于关注页。',
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildServerGroupLabel(
    BuildContext context,
    WidgetRef ref,
    String label,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: _kFontSizeSmall,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 服务器 - 服务器信息
  Widget _buildServerInfoTile(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return _InfoTile(
      icon: Icons.cloud_outlined,
      iconColor: Colors.blue,
      title: '当前服务器',
      subtitle: auth.backendUrl ?? '未连接',
      helpText:
          '当前正在使用的服务器地址。\n\n如需切换或添加服务器，请使用上方「服务器管理」入口。\n\n服务器切换后，媒体库、推荐与收藏内容都会跟随当前服务器变化。',
    );
  }

  // 服务器 - 群晖 Audio Station 音乐
  Widget _buildSynologyMusicTile(BuildContext context, WidgetRef ref) {
    final synoAuth = ref.watch(synologyAuthProvider);
    return _TapTile(
      icon: Icons.library_music_outlined,
      iconColor: const Color(0xFF2C8EF4),
      title: '群晖音乐',
      subtitle: synoAuth.isLoggedIn
          ? (synoAuth.account ?? '已登录')
          : '连接群晖 NAS Audio Station',
      onTap: () => context.push('/music'),
      helpText:
          '配置群晖 Audio Station 音乐服务。\n\n· 填写服务器地址、账号密码\n· 用于音乐服务模式下的音乐库浏览与播放\n\n需要群晖开启 Audio Station 并授予当前用户访问权限。',
    );
  }

  // 服务器 - Last.fm 音乐元数据补充（歌手头像/简介）
  Widget _buildLastFmTile(BuildContext context, WidgetRef ref) {
    final keyAsync = ref.watch(lastfmApiKeyAsyncProvider);
    final configured = (keyAsync.valueOrNull ?? '').isNotEmpty;
    return _TapTile(
      icon: Icons.graphic_eq,
      iconColor: const Color(0xFFD51007),
      title: 'Last.fm 补充',
      subtitle:
          configured ? '已配置：歌手头像/简介优先用 Last.fm' : '配置 API Key，补充歌手图与简介（免费）',
      onTap: () =>
          _showLastFmKeyDialog(context, ref, keyAsync.valueOrNull ?? ''),
      helpText:
          '配置 Last.fm 服务（可选）。\n\n用于获取歌手头像、简介等补充信息，丰富歌手详情页。\n\n· 需要注册 Last.fm API Key\n· 未配置时歌手详情仅显示服务器已有信息',
    );
  }

  /// NAS 歌手元数据同步开关（V1.1）
  ///
  /// 开启后，歌手元数据会同步到群晖 NAS（/appdata/EmbTok/artist_metadata/），
  /// 支持多设备共享。需要先登录群晖 Audio Station。
  Widget _buildNasMetadataSyncTile(BuildContext context, WidgetRef ref) {
    final service = ref.read(artistMetadataServiceProvider);
    final isLoggedIn = ref.read(synologyAuthProvider).isLoggedIn;

    return _SwitchTile(
      icon: Icons.cloud_sync_outlined,
      iconColor: Colors.teal,
      title: 'NAS 元数据同步',
      subtitle: service.nasSyncEnabled
          ? '已开启：歌手简介/头像同步到群晖，多设备共享'
          : '开启后同步到 NAS（需先登录群晖）',
      value: service.nasSyncEnabled,
      onChanged: (value) {
        if (!isLoggedIn) return;
        service.nasSyncEnabled = value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'NAS 元数据同步已开启' : 'NAS 元数据同步已关闭'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      helpText:
          '开启后，自动同步 NAS（群晖）音乐库的元数据（歌手、专辑、曲目信息）。\n\n· 开启 → 音乐库信息保持最新（同步耗时）\n· 关闭 → 仅使用本地缓存（更快但可能滞后）\n\n首次配置后建议开启一次完成全量同步。',
    );
  }

  /// Last.fm API Key 配置弹窗（免费申请：last.fm/api/account/create）
  void _showLastFmKeyDialog(
      BuildContext context, WidgetRef ref, String currentKey) {
    final controller = TextEditingController(text: currentKey);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Last.fm API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '免费申请：https://www.last.fm/api/account/create',
                style: TextStyle(fontSize: _kFontSizeSmall),
              ),
              const SizedBox(height: _kSpacingXSmall),
              const Text(
                '用于补充歌手头像与简介（未配置时自动使用群晖/Wikipedia 数据）',
                style: TextStyle(fontSize: _kFontSizeSmall),
              ),
              const SizedBox(height: _kSpacingXLarge),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '如：xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                autocorrect: false,
                enableSuggestions: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final saved = await saveLastFmApiKey(controller.text.trim());
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(saved ? 'Last.fm API Key 已保存' : '保存失败，请重试'),
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 关于 - 应用信息
  Widget _buildAboutTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.info_outline,
      iconColor: Colors.blueGrey,
      title: '关于 EmbyTok',
      subtitle: '了解更多关于应用的信息',
      onTap: () => _showAboutDialog(context, ref),
      helpText:
          '关于页包含：\n\n· 应用简介与当前版本\n· 开源许可证列表\n· 项目 GitHub 仓库与联系方式\n\n如需反馈问题或查看源码，可在此找到入口。',
    );
  }

  // 关于 - 检查更新
  Widget _buildCheckUpdateTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.system_update_outlined,
      iconColor: Colors.green,
      title: '检查更新',
      subtitle: '检查是否有新版本',
      onTap: () => _checkForUpdate(context, ref),
      helpText:
          '检查是否有新版本。\n\n· 自动检测 GitHub Releases 最新版本\n· 发现新版本可一键下载安装包\n\n国内网络下载失败时，可稍后重试或使用代理。',
    );
  }

  // 关于 - 打赏支持
  Widget _buildDonateTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.volunteer_activism_outlined,
      iconColor: Colors.red,
      title: '打赏支持',
      subtitle: '请作者喝杯咖啡',
      onTap: () => _showDonateDialog(context),
      helpText: '支持开发者：查看捐赠方式。\n\n捐赠是自愿行为，不影响任何功能使用。',
    );
  }

  // 关于 - 意见反馈
  Widget _buildFeedbackTile(BuildContext context, WidgetRef ref) {
    return _TapTile(
      icon: Icons.feedback_outlined,
      iconColor: Colors.orange,
      title: '意见反馈',
      subtitle: '通过邮件反馈问题或建议',
      onTap: () async {
        final uri = Uri(
          scheme: 'mailto',
          path: 'support@embytok.app',
          queryParameters: {'subject': 'EmbyTok 意见反馈'},
        );
        try {
          await launchUrl(uri);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未找到邮件应用')),
            );
          }
        }
      },
      helpText: '提交使用反馈或问题报告。\n\n建议附上：设备型号、App 版本、操作步骤、是否可复现，以及导出日志内容，便于快速定位。',
    );
  }

  // 关于 - 版本信息（动态读取，避免硬编码）
  Widget _buildVersionTile(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final subtitle = versionAsync.when(
      data: (v) => v,
      loading: () => '加载中…',
      error: (_, __) => '未知',
    );
    return _InfoTile(
      icon: Icons.new_releases_outlined,
      iconColor: Colors.blueGrey,
      title: '版本',
      subtitle: subtitle,
      helpText:
          '当前 App 版本与构建号。\n\n版本格式：主版本.次版本.修订号+构建号\n· 修订号 +1 → 小修复\n· 次版本 +1 → 新功能\n\n如发现新版本无法下载，可到「检查更新」重试。',
    );
  }

  // P2-5：性能监控面板（仅开发模式）
  // 开启后显示悬浮面板，监控内存使用、帧率、Widget 重建次数、API 请求统计
  Widget _buildPerformanceMonitorTile(BuildContext context, WidgetRef ref) {
    final enabled = PerformanceMonitor.instance.enabled;
    return _SwitchTile(
      icon: Icons.analytics_outlined,
      iconColor: Colors.purple,
      title: '性能监控面板',
      subtitle: enabled ? '已开启：悬浮显示内存/FPS/重建次数/API 请求' : '已关闭：开发调试用，不影响发布版本',
      value: enabled,
      onChanged: (value) {
        if (value) {
          PerformanceMonitor.instance.enable();
        } else {
          PerformanceMonitor.instance.disable();
        }
        // 提示用户
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '性能监控面板已开启' : '性能监控面板已关闭'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      helpText: '开启后显示实时性能监控（帧率、内存占用等）。\n\n· 调试用，日常可关闭\n· 开启会略微增加系统开销',
    );
  }

  // 账户 - 用户信息
  Widget _buildProfileTile(BuildContext context, WidgetRef ref) {
    // 音乐模式显示群晖账户，视频模式显示 Emby 账户
    if (ref.read(serviceModeProvider) == AppServiceMode.music) {
      final syno = ref.watch(synologyAuthProvider);
      return _InfoTile(
        icon: Icons.account_circle_outlined,
        iconColor: Colors.blue,
        title: syno.account ?? (syno.isLoggedIn ? '群晖账号' : '未登录'),
        subtitle: syno.serverUrl ?? '未连接群晖 NAS',
        helpText:
            '当前登录的账号信息（音乐模式）。\n\n· 显示群晖 Audio Station 账号与 NAS 地址\n· 信息不符时，可到「服务器管理」重新登录或切换服务器',
      );
    }
    final auth = ref.watch(authProvider);
    final name = auth.user?.name ?? '未登录';
    return _InfoTile(
      icon: Icons.account_circle_outlined,
      iconColor: Colors.blue,
      title: name,
      subtitle: auth.backendUrl ?? '未连接服务器',
      helpText:
          '当前登录的账号信息（视频模式）。\n\n· 显示 Emby 账号名与服务器地址\n· 信息不符时，可到「服务器管理」重新登录或切换服务器',
    );
  }

  // P0-1：允许自签名证书（默认关闭，即启用 SSL 证书校验）
  // 开启时允许连接使用自签名证书的内网 NAS，存在中间人攻击风险
  Widget _buildSelfSignedCertificateTile(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: _loadAllowSelfSignedCertificate(),
      builder: (context, snapshot) {
        final allow = snapshot.data ?? false;
        return _SwitchTile(
          icon: Icons.security_outlined,
          iconColor: Colors.orange,
          title: '允许自签名证书',
          subtitle:
              allow ? '已允许：可连接自签名证书的内网服务器（存在安全风险）' : '已禁用：严格校验 SSL 证书（推荐）',
          value: allow,
          onChanged: (value) {
            if (value) {
              // 开启时弹出安全风险提示
              _showSelfSignedCertificateWarning(context, ref);
            } else {
              // 关闭时直接保存
              _setAllowSelfSignedCertificate(context, false);
            }
          },
          helpText:
              '开启后允许连接使用自签名证书的服务器（如内网 NAS、自建 Emby）。\n\n· 开启 → 信任自签名证书，避免 TLS 校验失败\n· 关闭 → 只信任受信任 CA 签发的证书\n\n仅在你信任该服务器时开启，否则存在中间人攻击风险。',
        );
      },
    );
  }

  /// 从 SharedPreferences 读取是否允许自签名证书
  Future<bool> _loadAllowSelfSignedCertificate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kStorageKeyAllowSelfSignedCertificate) ?? false;
  }

  /// 保存是否允许自签名证书到 SharedPreferences
  ///
  /// 注意：证书校验配置在 ApiClient 初始化时读取，
  /// 修改后需要重启 App 才能生效。
  Future<void> _setAllowSelfSignedCertificate(
      BuildContext context, bool allow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStorageKeyAllowSelfSignedCertificate, allow);
    if (allow) {
      AppLogger.warn('已允许自签名证书，SSL 校验已禁用，存在安全风险');
    } else {
      AppLogger.info('已禁用自签名证书，SSL 校验已启用');
    }
    // 提示用户重启 App 生效
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allow ? '已允许自签名证书，重启 App 后生效' : '已禁用自签名证书，重启 App 后生效'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 显示自签名证书安全风险提示对话框
  void _showSelfSignedCertificateWarning(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.error, size: 24),
            const SizedBox(width: 8),
            const Text('安全风险提示'),
          ],
        ),
        content: const Text(
          '允许自签名证书将禁用 SSL 证书校验，可能导致中间人攻击，'
          '使您的账号密码和播放数据面临泄露风险。\n\n'
          '仅建议在受信任的内网环境中使用，且仅连接您自己的服务器。\n\n'
          '确定要开启吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _setAllowSelfSignedCertificate(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('确认开启'),
          ),
        ],
      ),
    );
  }

  // 退出登录按钮
  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(Icons.logout, color: scheme.onError),
          label: Text(
            '退出登录',
            style: TextStyle(color: scheme.onError, fontSize: _kFontSizeXLarge),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _showLogoutDialog(context, ref),
        ),
      ),
    );
  }

  // ==================== 设置搜索 ====================

  // 构建设置项搜索索引：每个入口包含标题、分组、关键词、点击回调
  // 点击回调捕获当前 context 和 ref，确保搜索结果可直接执行操作
  List<_SettingEntry> _buildSearchIndex(BuildContext context, WidgetRef ref) {
    return <_SettingEntry>[
      // 媒体库
      _SettingEntry(
        title: '视频流使用',
        section: '视频库',
        keywords: '视频流 媒体库 feed library',
        onTap: (ctx) => LibrarySelector.show(ctx, scope: LibraryScope.feed),
      ),
      _SettingEntry(
        title: '排除已观看',
        section: '视频库',
        keywords: '视频流 排除 已观看 played',
        onTap: (ctx) {
          final value = ref.read(feedExcludePlayedProvider);
          ref.read(feedExcludePlayedProvider.notifier).setExclude(!value);
        },
      ),
      _SettingEntry(
        title: '推荐使用',
        section: '视频库',
        keywords: '推荐 媒体库 recommend library',
        onTap: (ctx) =>
            LibrarySelector.show(ctx, scope: LibraryScope.recommend),
      ),
      // 推荐
      _SettingEntry(
        title: '评分阈值',
        section: '推荐',
        keywords: '推荐 评分 阈值 rating',
        onTap: (ctx) => _showRecommendRatingDialog(
            ctx, ref, ref.read(recommendMinRatingProvider)),
      ),
      _SettingEntry(
        title: '排除已观看',
        section: '推荐',
        keywords: '推荐 排除 已观看 played',
        onTap: (ctx) {
          final value = ref.read(recommendExcludePlayedProvider);
          ref.read(recommendExcludePlayedProvider.notifier).setExclude(!value);
        },
      ),
      _SettingEntry(
        title: '最短时长',
        section: '推荐',
        keywords: '推荐 最短 时长 runtime',
        onTap: (ctx) => _showRecommendRuntimeDialog(
            ctx, ref, ref.read(recommendMinRuntimeSecProvider)),
      ),
      _SettingEntry(
        title: '推荐类型',
        section: '推荐',
        keywords: '推荐 类型 movie episode video musicvideo series',
        onTap: (ctx) => _showRecommendTypesDialog(
            ctx, ref, ref.read(recommendIncludeTypesProvider)),
      ),
      _SettingEntry(
        title: '使用观看历史优化推荐',
        section: '推荐',
        keywords: '推荐 观看历史 完播率 门控 watch history',
        onTap: (ctx) {
          final value = ref.read(recommendUseWatchHistoryProvider);
          ref.read(recommendUseWatchHistoryProvider.notifier).setUse(!value);
        },
      ),
      _SettingEntry(
        title: '记忆半衰期',
        section: '推荐',
        keywords: '推荐 半衰期 衰减 halflife',
        onTap: (ctx) => _showHalfLifeDaysDialog(
            ctx, ref, ref.read(recommendHalfLifeDaysProvider)),
      ),
      _SettingEntry(
        title: '避免重复推荐',
        section: '推荐',
        keywords: '推荐 反疲劳 重复 anti fatigue',
        onTap: (ctx) {
          final value = ref.read(recommendAntiFatigueEnabledProvider);
          ref
              .read(recommendAntiFatigueEnabledProvider.notifier)
              .setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '不重推天数',
        section: '推荐',
        keywords: '推荐 反疲劳 天数 days',
        onTap: (ctx) => _showAntiFatigueDaysDialog(
            ctx, ref, ref.read(recommendAntiFatigueDaysProvider)),
      ),
      _SettingEntry(
        title: '用户评分加权',
        section: '推荐',
        keywords: '推荐 用户评分 加权 rating',
        onTap: (ctx) {
          final value = ref.read(recommendUserRatingEnabledProvider);
          ref
              .read(recommendUserRatingEnabledProvider.notifier)
              .setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '最低用户评分',
        section: '推荐',
        keywords: '推荐 最低 用户评分 min rating',
        onTap: (ctx) => _showUserRatingMinDialog(
            ctx, ref, ref.read(recommendUserRatingMinProvider)),
      ),
      // 播放
      _SettingEntry(
        title: '自动播放',
        section: '播放',
        keywords: '播放 自动 autoplay',
        onTap: (ctx) {
          final value = ref.read(isAutoPlayProvider);
          ref.read(isAutoPlayProvider.notifier).setEnabled(!value);
        },
      ),
      _SettingEntry(
        title: '焦点恢复自动续播',
        section: '播放',
        keywords: '播放 焦点 来电 恢复 续播 resume interruption',
        onTap: (ctx) {
          final value = ref.read(autoResumeAfterInterruptionProvider);
          ref.read(autoResumeAfterInterruptionProvider.notifier).set(!value);
        },
      ),
      _SettingEntry(
        title: '全屏禁用手势返回',
        section: '播放',
        keywords: '播放 手势 全屏 返回 边缘 gesture back swipe',
        onTap: (ctx) {
          final value = ref.read(fullscreenGestureBackExcludedProvider);
          ref.read(fullscreenGestureBackExcludedProvider.notifier).set(!value);
        },
      ),
      _SettingEntry(
        title: '默认播放倍速',
        section: '播放',
        keywords: '播放 倍速 rate speed',
        onTap: (ctx) => _showPlaybackRateDialog(
            ctx, ref, ref.read(defaultPlaybackRateProvider)),
      ),
      _SettingEntry(
        title: '手势控制',
        section: '播放',
        keywords: '播放 手势 gesture 滑动 双击 长按',
        onTap: (ctx) => _showGestureControlDialog(ctx),
      ),
      // 字幕
      _SettingEntry(
        title: '默认字幕语言',
        section: '字幕',
        keywords: '字幕 语言 subtitle 中英日韩',
        onTap: (ctx) => _showSubtitleDialog(
            ctx, ref, ref.read(defaultSubtitleLanguageProvider)),
      ),
      _SettingEntry(
        title: '字幕大小',
        section: '字幕',
        keywords: '字幕 大小 size small medium large',
        onTap: (ctx) =>
            _showSubtitleSizeDialog(ctx, ref, ref.read(subtitleSizeProvider)),
      ),
      // 外观
      _SettingEntry(
        title: '主题',
        section: '外观',
        keywords: '外观 主题 深色 浅色 theme dark light',
        onTap: (ctx) => _showThemeDialog(ctx, ref, ref.read(themeModeProvider)),
      ),
      _SettingEntry(
        title: '视频方向',
        section: '外观',
        keywords: '外观 方向 竖屏 横屏 orientation',
        onTap: (ctx) =>
            _showOrientationDialog(ctx, ref, ref.read(orientationModeProvider)),
      ),
      // 存储
      _SettingEntry(
        title: '清除缓存',
        section: '存储',
        keywords: '存储 缓存 清除 cache',
        onTap: (ctx) => _showClearCacheDialog(ctx, ref),
      ),
      _SettingEntry(
        title: '重置设置',
        section: '存储',
        keywords: '存储 重置 设置 reset restore 默认',
        onTap: (ctx) => _showResetSettingsDialog(ctx, ref),
      ),
      _SettingEntry(
        title: '导出日志',
        section: '存储',
        keywords: '存储 日志 导出 log export 排查',
        onTap: (ctx) => _exportLogs(ctx),
      ),
      _SettingEntry(
        title: '清除日志',
        section: '存储',
        keywords: '存储 日志 清除 删除 log clear',
        onTap: (ctx) => _showClearLogsDialog(ctx),
      ),
      // 统计
      _SettingEntry(
        title: '观看统计',
        section: '统计',
        keywords: '统计 观看 完播率 stats',
        onTap: (ctx) => _showWatchStatsDialog(ctx, ref),
      ),
      // 关于
      _SettingEntry(
        title: '关于 EmbyTok',
        section: '关于',
        keywords: '关于 about embytok',
        onTap: (ctx) => _showAboutDialog(ctx, ref),
      ),
      _SettingEntry(
        title: '检查更新',
        section: '关于',
        keywords: '检查更新 update 升级 版本',
        onTap: (ctx) => _checkForUpdate(ctx, ref),
      ),
      _SettingEntry(
        title: '打赏支持',
        section: '关于',
        keywords: '打赏 赞赏 捐款 赞助 donate 咖啡',
        onTap: (ctx) => _showDonateDialog(ctx),
      ),
      _SettingEntry(
        title: '意见反馈',
        section: '关于',
        keywords: '意见反馈 反馈 邮件 建议 bug 报告',
        onTap: (ctx) => _buildFeedbackTile(ctx, ref),
      ),
    ];
  }

  // 显示设置搜索对话框
  void _showSettingsSearch(BuildContext context, WidgetRef ref) {
    final isMusicMode = ref.read(serviceModeProvider) == AppServiceMode.music;
    // 音乐模式：过滤视频相关设置项（视频库/推荐/播放/字幕/统计/视频方向）
    const videoSections = {'视频库', '推荐', '播放', '字幕', '统计'};
    final entries = _buildSearchIndex(context, ref)
        .where((e) =>
            !isMusicMode ||
            (!videoSections.contains(e.section) && e.title != '视频方向'))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _SettingsSearchSheet(entries: entries),
    );
  }

  // ==================== 组件定义 ====================

  // 点击型设置项
  /// 数据源选择 tile：已选媒体库以 chips 可视化预览（全量展示，自动换行）
  ///
  /// 相比单一文本副标题，用户无需进入弹窗即可看清当前生效的媒体库集合；
  /// 收藏夹模式（视频流）以高亮 chip 标识。点击进入 [LibrarySelector] 弹窗。
  static Widget _librarySelectionTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required List<Library> libraries,
    required bool favoritesMode,
    String favoritesLabel = '收藏夹',
    required VoidCallback onTap,

    /// 媒体库 chip 点击回调（快捷移除单个数据源，如 null 则 chips 只读）
    ValueChanged<String>? onChipTap,

    /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
    String? helpText,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final chips = <Widget>[
        if (favoritesMode)
          _libraryChip(
            label: favoritesLabel,
            icon: Icons.star,
            color: scheme.primary,
            background: scheme.primaryContainer,
          ),
        if (!favoritesMode)
          for (final lib in libraries)
            _tapChip(
              onTap: onChipTap == null ? null : () => onChipTap(lib.id),
              chip: _libraryChip(
                label: lib.name,
                icon: _libraryTypeIcon(lib.type),
                color: scheme.onSurfaceVariant,
                background: scheme.surfaceContainerHighest,
              ),
            ),
        if (!favoritesMode && libraries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '未选择',
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: _kFontSizeBody,
              ),
            ),
          ),
      ];
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helpButton(helpText: helpText, title: title),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
        onTap: onTap,
      );
    });
  }

  /// 媒体库类型图标（Emby Library.type）
  static IconData _libraryTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movies':
      case 'movie':
        return Icons.movie_outlined;
      case 'tvshows':
      case 'tvshow':
      case 'series':
        return Icons.live_tv_outlined;
      case 'music':
        return Icons.music_note_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  /// 可点击 chip 包装：提供点击反馈（用于媒体库快捷移除）
  static Widget _tapChip({
    required VoidCallback? onTap,
    required Widget chip,
  }) {
    return onTap == null
        ? chip
        : GestureDetector(
            onTap: onTap,
            child: chip,
          );
  }

  /// 数据源 chip 胶囊
  static Widget _libraryChip({
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _TapTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,

    /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
    String? helpText,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant
                      .withValues(alpha: _kTileSubtitleAlpha),
                  fontSize: _kFontSizeBody,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helpButton(helpText: helpText, title: title),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
        onTap: onTap,
      );
    });
  }

  // 开关型设置项
  static Widget _SwitchTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,

    /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
    String? helpText,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant
                      .withValues(alpha: _kTileSubtitleAlpha),
                  fontSize: _kFontSizeBody,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helpButton(helpText: helpText, title: title),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: scheme.primary,
            ),
          ],
        ),
      );
    });
  }

  // 信息型设置项（不可点击）
  static Widget _InfoTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,

    /// 帮助文本：非空时在 trailing 显示帮助按钮，点击弹出详细说明
    String? helpText,
  }) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        leading: _IconContainer(icon: icon, color: iconColor ?? scheme.primary),
        title: Text(
          title,
          style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: _kFontSizeBody,
                ),
              )
            : null,
        trailing: _helpButton(helpText: helpText, title: title),
      );
    });
  }

  /// 帮助按钮：helpText 非空时显示（?）图标，点击弹出详细帮助
  static Widget _helpButton({
    required String? helpText,
    required String title,
  }) {
    if (helpText == null || helpText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return IconButton(
        icon:
            Icon(Icons.help_outline, size: 19, color: scheme.onSurfaceVariant),
        tooltip: '帮助',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
        onPressed: () => _showHelp(context, title, helpText),
      );
    });
  }

  /// 弹出设置项帮助（底部弹层：标题 + 详细说明）
  static void _showHelp(BuildContext context, String title, String helpText) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline, size: 22, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 20, color: scheme.onSurfaceVariant),
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  helpText,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 图标容器
  static Widget _IconContainer({required IconData icon, required Color color}) {
    return Container(
      width: _kTileIconContainerSize,
      height: _kTileIconContainerSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: _kTileIconContainerBgAlpha),
        borderRadius: BorderRadius.circular(_kTileIconContainerRadius),
      ),
      child: Icon(icon, color: color, size: _kTileIconSize),
    );
  }

  // ==================== 对话框 ====================

  void _showThemeDialog(BuildContext context, WidgetRef ref, String current) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: _kDialogSelectTheme,
        options: const [
          ('跟随系统', 'system'),
          ('深色', 'dark'),
          ('浅色', 'light'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(themeModeProvider.notifier).setTheme(v);
        },
      ),
    );
  }

  void _showPlaybackRateDialog(
    BuildContext context,
    WidgetRef ref,
    double current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '默认播放倍速',
        options: const [
          ('0.5x', 0.5),
          ('0.75x', 0.75),
          ('1.0x', 1.0),
          ('1.25x', 1.25),
          ('1.5x', 1.5),
          ('2.0x', 2.0),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(defaultPlaybackRateProvider.notifier).set(v);
        },
      ),
    );
  }

  void _showGestureControlDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 手势说明与 fullscreen_video_page.dart 中实际实现保持一致：
    // - 单击：切换控制栏显隐（非播放/暂停）
    // - 双击左右 1/3：快进/快退 10 秒；双击中间 1/3：点赞（收藏）
    // - 长按：2x 倍速播放（松开恢复）
    // - 上下滑动：左半屏调亮度，右半屏调音量
    // - 左右滑动：拖动进度条（每像素 100ms）
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('手势控制', style: TextStyle(color: scheme.onSurface)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GestureItem(
              icon: Icons.touch_app,
              title: '单击',
              description: '显示/隐藏控制栏',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.double_arrow,
              title: '双击左右侧',
              description: '快退 / 快进 10 秒',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.favorite,
              title: '双击中间',
              description: '点赞（加入收藏）',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.fast_forward,
              title: '长按',
              description: '2x 倍速播放，松开恢复',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.swipe_up,
              title: '上下滑动（左半屏）',
              description: '调节屏幕亮度',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.volume_up,
              title: '上下滑动（右半屏）',
              description: '调节音量',
            ),
            SizedBox(height: _kSpacingXLarge),
            const _GestureItem(
              icon: Icons.swipe,
              title: '左右滑动',
              description: '拖动进度条定位',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('关闭', style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSubtitleDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '默认字幕语言',
        options: const [
          ('关闭', ''),
          ('中文（简体）', 'zh-CN'),
          ('中文（繁体）', 'zh-TW'),
          ('英语', 'en'),
          ('日语', 'ja'),
          ('韩语', 'ko'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(defaultSubtitleLanguageProvider.notifier).set(v);
        },
      ),
    );
  }

  void _showSubtitleSizeDialog(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '字幕大小',
        options: const [
          ('小', 'small'),
          ('中', 'medium'),
          ('大', 'large'),
        ],
        currentValue: current,
        onSelect: (v) {
          ref.read(subtitleSizeProvider.notifier).set(v);
        },
      ),
    );
  }

  void _showOrientationDialog(
    BuildContext context,
    WidgetRef ref,
    OrientationMode current,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _OptionDialog(
        title: '视频方向',
        options: const [
          ('全部', 'both'),
          ('只看竖屏', 'vertical'),
          ('只看横屏', 'horizontal'),
        ],
        currentValue: _orientationModeToString(current),
        onSelect: (v) {
          ref.read(orientationModeProvider.notifier).setMode(
                _parseOrientationMode(v),
              );
        },
      ),
    );
  }

  String _orientationModeToString(OrientationMode mode) {
    return switch (mode) {
      OrientationMode.vertical => 'vertical',
      OrientationMode.horizontal => 'horizontal',
      OrientationMode.both => 'both',
    };
  }

  OrientationMode _parseOrientationMode(String value) {
    return switch (value) {
      'vertical' => OrientationMode.vertical,
      'horizontal' => OrientationMode.horizontal,
      _ => OrientationMode.both,
    };
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('清除缓存', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '确定要清除全部缓存吗？这将删除临时下载的缩略图和字幕文件。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(cacheSizeProvider.notifier).clear();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('缓存已清除'),
                    backgroundColor: scheme.primary,
                  ),
                );
              } catch (e) {
                AppLogger.error('清除缓存失败', error: e);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('清除失败：$e'),
                    backgroundColor: scheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('清除', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // 重置设置对话框：清除所有偏好设置，提示用户重启生效
  void _showResetSettingsDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('重置设置', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '将所有偏好设置恢复为默认值，包括：播放、字幕、外观、推荐、媒体库等。\n\n'
          '不影响：登录信息、观看历史、搜索历史、收藏。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await const AppPreferencesService().resetAllSettings();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('设置已重置并立即生效'),
                    backgroundColor: scheme.primary,
                    duration: const Duration(seconds: 4),
                  ),
                );
              } catch (e) {
                AppLogger.error('重置设置失败', error: e);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('重置失败：$e'),
                    backgroundColor: scheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('重置', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // 导出日志：预览内容 + 复制/打开文件操作
  Future<void> _exportLogs(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    try {
      final logContent = await AppLogger.exportLogs();

      if (logContent.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('暂无日志可导出'),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        );
        return;
      }

      // 写入临时文件以便系统查看器打开
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/embytok_export.log');
      await tempFile.writeAsString(logContent);

      if (!context.mounted) return;
      _showExportLogsDialog(context, logContent, tempFile.path);
    } catch (e) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: scheme.surface,
          title: Text('导出失败', style: TextStyle(color: scheme.onSurface)),
          content: Text(
            '导出日志时出错：$e',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('确定', style: TextStyle(color: scheme.primary)),
            ),
          ],
        ),
      );
    }
  }

  void _showExportLogsDialog(
    BuildContext context,
    String logContent,
    String filePath,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // 取最后 20 行作为预览
    final lines = logContent.split('\n');
    final previewLines =
        lines.length > 20 ? lines.sublist(lines.length - 20) : lines;
    final preview = previewLines.join('\n');
    final hasMore = lines.length > 20;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Row(
          children: [
            Text('导出日志', style: TextStyle(color: scheme.onSurface)),
            const Spacer(),
            Text(
              '共 ${logContent.length} 字符',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeSmall),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '... 省略前 ${lines.length - 20} 行',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: _kFontSizeSmall),
                  ),
                ),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    preview,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: _kFontSizeTiny,
                      color: scheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: logContent));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('日志内容已复制到剪贴板'),
                  backgroundColor: scheme.primary,
                ),
              );
            },
            child: const Text('复制内容'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await OpenFilex.open(filePath, type: 'text/plain');
              if (result.type != ResultType.done && dialogContext.mounted) {
                // 无法打开时降级为复制内容
                await Clipboard.setData(ClipboardData(text: logContent));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('无法打开文件，日志内容已复制到剪贴板'),
                    backgroundColor: scheme.primary,
                  ),
                );
              }
            },
            child: const Text('打开文件'),
          ),
        ],
      ),
    );
  }

  // 清除日志确认对话框
  void _showClearLogsDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('清除日志', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '将删除本地保存的所有 WARN/ERROR 日志文件，此操作不可恢复。\n\n'
          '如有问题正在排查，建议先导出日志再清除。',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AppLogger.clearLogs();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('日志已清除'),
                    backgroundColor: scheme.primary,
                  ),
                );
              } catch (e) {
                AppLogger.error('清除日志失败', error: e);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('清除失败：$e'),
                    backgroundColor: scheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('清除', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // PR #81：观看统计详情对话框
  // - 显示总次数、平均完播率、最近 7 天统计、最近 10 条记录
  // - 提供"清除统计"按钮
  void _showWatchStatsDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (_) => Consumer(builder: (dialogContext, ref, _) {
        final stats = ref.watch(watchStatsProvider);
        return AlertDialog(
          backgroundColor: scheme.surface,
          title: Text('观看统计', style: TextStyle(color: scheme.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 概览
                  _buildStatRow(scheme, '总观看次数', '${stats.totalCount}'),
                  _buildStatRow(
                    scheme,
                    '平均完播率',
                    '${(stats.avgCompletion * 100).toStringAsFixed(0)}%',
                  ),
                  _buildStatRow(scheme, '最近 7 天', '${stats.last7DaysCount} 次'),
                  _buildStatRow(
                    scheme,
                    '近 7 天完播率',
                    '${(stats.last7DaysAvgCompletion * 100).toStringAsFixed(0)}%',
                  ),
                  const SizedBox(height: _kSpacingXXLarge),
                  // 最近 10 条
                  if (stats.records.isNotEmpty) ...[
                    Text(
                      '最近观看',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: _kFontSizeMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: _kSpacingMedium),
                    ...stats.records.take(10).map((r) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.itemTitle ?? r.itemId,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: _kFontSizeSmall,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(r.completionRate * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: r.completionRate >= 0.8
                                    ? Colors.green
                                    : scheme.onSurfaceVariant,
                                fontSize: _kFontSizeSmall,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '暂无观看记录。开始播放视频后这里会显示统计。',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: _kFontSizeBody,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text('关闭', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            if (stats.totalCount > 0)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: dialogContext,
                    builder: (confirmContext) => AlertDialog(
                      backgroundColor: scheme.surface,
                      title: Text('清除统计',
                          style: TextStyle(color: scheme.onSurface)),
                      content: Text('确定要清除所有观看统计吗？',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmContext, false),
                          child: Text('取消',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(confirmContext, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.error),
                          child: Text('清除',
                              style: TextStyle(color: scheme.onError)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(watchStatsProvider.notifier).clear();
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    } catch (e) {
                      AppLogger.error('清除统计失败', error: e);
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('清除失败：$e'),
                          backgroundColor: scheme.error,
                        ),
                      );
                    }
                  }
                },
                child: Text('清除统计', style: TextStyle(color: scheme.error)),
              ),
          ],
        );
      }),
    );
  }

  // 辅助：统计行
  Widget _buildStatRow(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeBody)),
          Text(value,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: _kFontSizeLarge,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('退出登录', style: TextStyle(color: scheme.onSurface)),
        content: Text(
          '确定要退出当前账号吗？',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () {
              // 按服务模式退出对应服务：音乐模式退群晖，视频模式退 Emby
              if (ref.read(serviceModeProvider) == AppServiceMode.music) {
                ref.read(synologyAuthProvider.notifier).logout();
              } else {
                ref.read(authProvider.notifier).logout();
              }
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text('退出', style: TextStyle(color: scheme.onError)),
          ),
        ],
      ),
    );
  }

  // 检查更新：调 GitHub Releases API 对比版本号
  Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;

    // 1. 等待版本信息加载完成：避免 appVersionProvider 未 resolve 时
    //    用 '0.0.0' 参与比较，导致"已最新却提示有新版本"
    String currentVersion;
    try {
      currentVersion = await ref.read(appVersionProvider.future);
    } catch (_) {
      currentVersion = '0.0.0';
    }
    if (!context.mounted) return;
    // 去掉 buildNumber，只保留 x.y.z
    var currentVer = currentVersion;
    final plusIdx = currentVer.indexOf('+');
    if (plusIdx > 0) currentVer = currentVer.substring(0, plusIdx);

    // 2. 显示加载对话框（PopScope 禁止返回键关闭，避免误关设置页）
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Text('正在检查更新…',
                  style: TextStyle(
                      color: scheme.onSurface, fontSize: _kFontSizeLarge)),
            ],
          ),
        ),
      ),
    );

    // 3. 调用 GitHub API 检查（包裹 try-catch，网络异常时关闭加载框并提示用户）
    final updateService = ref.read(updateCheckServiceProvider);
    try {
      final result = await updateService.checkForUpdate(currentVer);

      // 关闭加载对话框
      if (context.mounted) Navigator.pop(context);

      if (!context.mounted) return;

      // 4. 展示结果
      if (result.latestRelease == null) {
        // 无法获取 Release 信息（网络错误或无 Release）
        _showUpdateResultDialog(
          context,
          icon: Icons.cloud_off,
          title: '检查失败',
          message: '无法获取更新信息，请检查网络连接后重试。',
          actionText: '关闭',
          onAction: null,
          secondaryActionText: '前往 GitHub',
          onSecondaryAction: () =>
              _launchUrl(updateService.releasePageUrl, context),
        );
      } else if (result.hasUpdate) {
        // 有新版本
        final release = result.latestRelease!;
        // 查找 APK 下载链接
        final apkAssets = release.assets.where((a) => a.isApk).toList();
        final hasApk = apkAssets.isNotEmpty;
        // 网络失败回退缓存时提示来源，避免用户误以为版本没变化
        final cacheHint = result.fromCache ? '\n\n（网络不可用，以上为上次检查结果）' : '';
        _showUpdateResultDialog(
          context,
          icon: Icons.system_update,
          title: '发现新版本',
          message: '当前版本：$currentVer\n最新版本：${release.version}\n\n'
              '${release.body.isNotEmpty ? release.body : release.name}'
              '$cacheHint',
          actionText: hasApk ? '下载安装' : '前往下载',
          onAction: () {
            if (hasApk) {
              _startDownloadApk(context, ref, apkAssets.first, release);
            } else {
              _launchUrl(release.htmlUrl, context);
            }
          },
          secondaryActionText: '稍后再说',
          onSecondaryAction: null,
        );
      } else {
        // 已是最新版本（fromCache 时标题区分，避免误读为实时结论）
        _showUpdateResultDialog(
          context,
          icon: result.fromCache ? Icons.history : Icons.check_circle,
          title: result.fromCache ? '上次检查：已是最新' : '已是最新版本',
          message: '当前版本：$currentVer\n'
              '${result.fromCache ? '（网络不可用，以上为上次检查结果）' : '您使用的是最新版本。'}',
          actionText: '关闭',
          onAction: null,
          secondaryActionText: null,
          onSecondaryAction: null,
        );
      }
    } catch (e) {
      // 异常处理：关闭加载对话框，显示错误提示
      AppLogger.error('检查更新失败', error: e);
      if (context.mounted) Navigator.pop(context);
      if (!context.mounted) return;

      // 根据错误类型显示不同提示
      String errorTitle;
      String errorMessage;
      if (e is UpdateRateLimitException) {
        errorTitle = '请求过于频繁';
        errorMessage = 'GitHub API 请求次数已达上限，请稍后再试。';
      } else {
        errorTitle = '检查失败';
        errorMessage = '检查更新时出错：$e';
      }

      _showUpdateResultDialog(
        context,
        icon: Icons.error_outline,
        title: errorTitle,
        message: errorMessage,
        actionText: '关闭',
        onAction: null,
        secondaryActionText: '前往 GitHub',
        onSecondaryAction: () =>
            _launchUrl(updateService.releasePageUrl, context),
      );
    }
  }

  /// 开始下载 APK：显示进度对话框，下载完成后触发安装
  void _startDownloadApk(
    BuildContext context,
    WidgetRef ref,
    ReleaseAsset apkAsset,
    ReleaseInfo release,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final updateService = ref.read(updateCheckServiceProvider);
    final cancelToken = CancelToken();
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('准备下载...');
    // 跟踪对话框是否仍在显示，防止对话框关闭后还继续处理下载结果
    bool isDialogActive = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // 启动下载：延迟到第一帧后执行，避免在 builder 中直接调用异步操作
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isDialogActive) return;
          updateService.downloadApk(
            apkAsset,
            version: release.version,
            onProgress: (p) {
              if (!isDialogActive) return;
              progressNotifier.value = p;
              statusNotifier.value =
                  '${(p * 100).toStringAsFixed(0)}%  ·  ${formatBytes(apkAsset.size)}';
            },
            cancelToken: cancelToken,
            // Release 正文附带 SHA256 时强制校验，防止镜像源篡改
            expectedSha256: release.sha256Digest,
          ).then((savePath) {
            if (ctx.mounted && isDialogActive) {
              isDialogActive = false;
              Navigator.pop(ctx);
              _showInstallDialog(ctx, savePath, release, scheme);
            }
          }).catchError((Object e) {
            if (e is DioException && CancelToken.isCancel(e)) return;
            if (ctx.mounted && isDialogActive) {
              isDialogActive = false;
              Navigator.pop(ctx);
              _showDownloadError(ctx, e.toString(), apkAsset.downloadUrl);
            }
          });
        });

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading, size: 28, color: scheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    '正在下载更新',
                    style: TextStyle(
                      fontSize: _kFontSizeXLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _kSpacingXXXLarge),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) {
                  return LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  );
                },
              ),
              const SizedBox(height: _kSpacingLarge),
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) {
                  return Text(
                    status,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: _kFontSizeSmall,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelToken.cancel();
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    ).then((_) {
      // 对话框关闭时释放资源
      progressNotifier.dispose();
      statusNotifier.dispose();
    });
  }

  // 显示下载失败对话框
  void _showDownloadError(
      BuildContext context, String error, String fallbackUrl) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: _kSpacingXXLarge),
            const Text(
              '下载失败',
              style: TextStyle(
                fontSize: _kFontSizeXXLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kSpacingXLarge),
            Text(
              error,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: _kFontSizeBody,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchUrl(fallbackUrl, context);
            },
            child: const Text('浏览器下载'),
          ),
        ],
      ),
    );
  }

  // 显示安装确认对话框
  void _showInstallDialog(
    BuildContext context,
    String apkPath,
    ReleaseInfo release,
    ColorScheme scheme,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: _kSpacingXXLarge),
            const Text(
              '下载完成',
              style: TextStyle(
                fontSize: _kFontSizeXXLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kSpacingMedium),
            Text(
              '版本 ${release.version} 已下载完成，是否立即安装？',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: _kFontSizeBody,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后安装'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _installApk(context, apkPath);
            },
            child: const Text('立即安装'),
          ),
        ],
      ),
    );
  }

  /// 安装 APK：使用 open_filex 调用系统安装器
  /// 失败时通过 SnackBar 告知用户原因，避免"点击无反应"的困惑
  Future<void> _installApk(BuildContext context, String apkPath) async {
    final scheme = Theme.of(context).colorScheme;
    try {
      final file = File(apkPath);
      if (!await file.exists()) {
        AppLogger.error('安装失败：文件不存在', data: {'path': apkPath});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('安装失败：安装文件不存在'),
            backgroundColor: scheme.error,
          ),
        );
        return;
      }
      final result = await OpenFilex.open(apkPath,
          type: 'application/vnd.android.package-archive');
      AppLogger.debug('APK 安装结果',
          data: {'type': result.type.name, 'message': result.message});
      // 打开失败（非 done）时提示用户
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开安装器：${result.message}'),
            backgroundColor: scheme.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('安装 APK 失败', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('安装失败：$e'),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  // 显示更新结果对话框
  void _showUpdateResultDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String actionText,
    VoidCallback? onAction,
    String? secondaryActionText,
    VoidCallback? onSecondaryAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary),
            const SizedBox(height: _kSpacingXXLarge),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: _kFontSizeXXLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _kSpacingXLarge),
            Text(
              message,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: _kFontSizeMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          if (secondaryActionText != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSecondaryAction?.call();
              },
              child: Text(secondaryActionText),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction?.call();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  // 打开外部 URL；失败时提示用户，避免"点击无反应"
  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('打开链接失败', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接，请检查系统浏览器')),
        );
      }
    }
  }

  /// 打赏支持对话框
  ///
  /// 组合方式：展示微信/支付宝收款码（如已提供），并提供外部打赏链接。
  /// 收款码图片放置在 assets/images/ 下，文件名固定为：
  /// - donate_wechat.png（微信收款码）
  /// - donate_alipay.png（支付宝收款码）
  /// 如未提供图片，则显示占位提示 + 跳转链接。
  void _showDonateDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: DonateColors.donateAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism,
                    color: DonateColors.donateAccent, size: 32),
              ),
              const SizedBox(height: _kSpacingXLarge),
              Text(
                '打赏支持',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: _kFontSizeXXLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: _kSpacingSmall),
              Text(
                '如果这个应用对你有帮助，\n可以请作者喝杯咖啡 ☕',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeBody,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _kSpacingXXLarge),
              // 收款码区域：用 errorBuilder 处理图片缺失
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_wechat.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _DonatePlaceholder(
                    icon: Icons.chat_outlined,
                    label: '微信收款码',
                    hint: '尚未提供，敬请期待',
                    color: DonateColors.wechat,
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingXLarge),
              // 支付宝收款码
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/donate_alipay.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _DonatePlaceholder(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '支付宝收款码',
                    hint: '尚未提供，敬请期待',
                    color: DonateColors.alipay,
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingXXLarge),
              // 外部打赏链接（如爱发电等）
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl(
                    'https://github.com/1525745393/EmbyTok-Flutter', context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '前往 GitHub 仓库',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: _kFontSizeBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingMedium),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 动态读取版本号
    final versionAsync = ref.read(appVersionProvider);
    final version = versionAsync.maybeWhen(
      data: (v) => v,
      orElse: () => 'unknown',
    );
    // 版权年份动态
    const startYear = 2024;
    final currentYear = DateTime.now().year;
    final copyrightYear =
        currentYear > startYear ? '$startYear-$currentYear' : '$startYear';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.play_circle_filled,
                    color: scheme.onPrimary, size: 44),
              ),
              const SizedBox(height: _kSpacingXLarge),
              // 应用名
              Text(
                'EmbyTok',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: _kFontSizeXXXLarge,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: _kSpacingXSmall),
              // 版本号
              Text(
                '版本 $version',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeBody,
                ),
              ),
              const SizedBox(height: _kSpacingXXXLarge),
              // 应用介绍
              Text(
                'EmbyTok 是一款面向 Emby 媒体服务器与群晖 Audio Station 的媒体客户端，提供类似 TikTok 的上下滑动刷片体验，同时支持音乐库浏览与播放，让你以更现代、便捷的方式享受个人媒体库。',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: _kSpacingXXLarge),
              // 功能亮点
              const _AboutFeatureRow(
                icon: Icons.swipe_vertical,
                text: '上下滑动，沉浸式刷片体验',
              ),
              const SizedBox(height: _kSpacingLarge),
              const _AboutFeatureRow(
                icon: Icons.favorite_border,
                text: '收藏管理，快速访问心仪内容',
              ),
              const SizedBox(height: _kSpacingLarge),
              const _AboutFeatureRow(
                icon: Icons.library_music_outlined,
                text: '支持 Emby 视频与群晖 Audio Station 音乐',
              ),
              const SizedBox(height: _kSpacingXXXLarge),
              const Divider(height: 1),
              const SizedBox(height: _kSpacingXLarge),
              // GitHub 仓库入口：点击跳转到项目仓库
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _launchUrl(
                    'https://github.com/1525745393/EmbyTok-Flutter', context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'GitHub 仓库',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: _kFontSizeBody,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 14, color: scheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _kSpacingXLarge),
              // 版权
              Text(
                '© $copyrightYear EmbyTok  contributors',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: _kFontSizeSmall,
                ),
              ),
              const SizedBox(height: _kSpacingXSmall),
              Text(
                '本软件基于开源协议发布',
                style: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: _kFontSizeSmall,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 打开自定义中文许可证页面（替代框架英文 showLicensePage）
              _showLicensePage(context, version: version, scheme: scheme);
            },
            child: const Text('开源许可证'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 打开自定义中文许可证页面
  ///
  /// 替代框架内置的英文 [showLicensePage]，使用 [LicenseRegistry] 异步收集
  /// 所有依赖的许可证条目，渲染为中文界面的可展开列表。
  void _showLicensePage(
    BuildContext context, {
    required String version,
    required ColorScheme scheme,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LicensePage(
          applicationName: 'EmbyTok',
          applicationVersion: version,
          primaryColor: scheme.primary,
        ),
      ),
    );
  }

  // ==================== 工具方法 ====================

  String _themeLabel(String mode) {
    switch (mode) {
      case 'dark':
        return '深色';
      case 'light':
        return '浅色';
      case 'system':
      default:
        return '跟随系统';
    }
  }

  String _subtitleSizeLabel(String size) {
    switch (size) {
      case 'small':
        return '小';
      case 'large':
        return '大';
      case 'medium':
      default:
        return '中等';
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'zh-CN':
        return '中文（简体）';
      case 'zh-TW':
        return '中文（繁体）';
      case 'en':
        return '英语';
      case 'ja':
        return '日语';
      case 'ko':
        return '韩语';
      default:
        return code;
    }
  }
}

// 打赏收款码占位组件：尚未提供图片时显示提示
class _DonatePlaceholder extends StatelessWidget {
  const _DonatePlaceholder({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: _kSpacingMedium),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: _kFontSizeMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: _kSpacingXSmall),
          Text(
            hint,
            style: TextStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: _kFontSizeTiny,
            ),
          ),
        ],
      ),
    );
  }
}

// 关于页的功能亮点行
class _AboutFeatureRow extends StatelessWidget {
  const _AboutFeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: _kFontSizeBody,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 自定义中文许可证页面 ====================

/// 自定义中文许可证页面
///
/// 替代 Flutter 框架内置的英文 [showLicensePage]，使用 [LicenseRegistry]
/// 异步收集所有依赖的许可证条目，渲染为中文界面的可展开列表，
/// 支持按包名搜索过滤。
class _LicensePage extends StatefulWidget {
  const _LicensePage({
    required this.applicationName,
    required this.applicationVersion,
    required this.primaryColor,
  });
  final String applicationName;
  final String applicationVersion;
  final Color primaryColor;

  @override
  State<_LicensePage> createState() => _LicensePageState();
}

class _LicensePageState extends State<_LicensePage> {
  // 收集到的所有许可证条目
  List<_LicenseEntryView> _entries = const [];
  bool _isLoading = true;
  String? _error;
  // 搜索状态
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLicenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 收集 LicenseRegistry.licenses 流并聚合为列表
  Future<void> _loadLicenses() async {
    try {
      final entries = <_LicenseEntryView>[];
      // LicenseRegistry.licenses 是单订阅流，await for 一次性消费
      await for (final entry in LicenseRegistry.licenses) {
        final packages = entry.packages.toList();
        final body = entry.paragraphs.map((p) => p.text).join('\n');
        if (packages.isEmpty) {
          // 无包名的条目归入"未命名包"
          entries.add(_LicenseEntryView(
            packageName: '(未命名包)',
            body: body,
          ));
        } else {
          // 一个 LicenseEntry 可能覆盖多个包，分别建立条目以便搜索
          for (final pkg in packages) {
            entries.add(_LicenseEntryView(packageName: pkg, body: body));
          }
        }
      }
      // 按包名排序，便于查找
      entries.sort((a, b) =>
          a.packageName.toLowerCase().compareTo(b.packageName.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载许可证失败：$e';
        _isLoading = false;
      });
    }
  }

  // 按搜索关键词过滤包名
  List<_LicenseEntryView> get _filtered {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries
        .where((e) => e.packageName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索包名...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                ),
                style: TextStyle(
                    color: scheme.onSurface, fontSize: _kFontSizeXLarge),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('开源许可证'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '取消搜索',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索包名',
              onPressed: () => setState(() => _isSearching = true),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  // 主体内容：加载中 / 错误 / 空态 / 列表 四种状态
  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: widget.primaryColor),
            const SizedBox(height: _kSpacingXLarge),
            Text(
              '正在加载许可证...',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeBody),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: scheme.error, fontSize: _kFontSizeMedium),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? '暂无许可证信息' : '没有匹配「$_searchQuery」的包',
          style: TextStyle(
              color: scheme.onSurfaceVariant, fontSize: _kFontSizeMedium),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length + 1, // +1 为顶部说明卡片
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeaderCard(scheme, list.length);
        final entry = list[index - 1];
        return _buildLicenseTile(scheme, entry);
      },
    );
  }

  // 顶部说明卡片：致谢与应用信息
  Widget _buildHeaderCard(ColorScheme scheme, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: widget.primaryColor),
              const SizedBox(width: 6),
              Text(
                '${widget.applicationName} · 版本 ${widget.applicationVersion}',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: _kFontSizeBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: _kSpacingMedium),
          Text(
            '本应用使用了 $count 个开源软件包，谨向以下项目的作者致以诚挚谢意。',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: _kFontSizeSmall,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // 单个许可证条目：点击展开查看全文
  Widget _buildLicenseTile(ColorScheme scheme, _LicenseEntryView entry) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(
        entry.packageName,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: _kFontSizeMedium,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '点击查看许可证全文',
        style:
            TextStyle(color: scheme.onSurfaceVariant, fontSize: _kFontSizeTiny),
      ),
      children: [
        SelectableText(
          entry.body.isEmpty ? '（无许可证文本）' : entry.body,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: _kFontSizeSmall,
            height: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

/// 许可证条目视图模型
class _LicenseEntryView {
  const _LicenseEntryView({required this.packageName, required this.body});
  final String packageName;
  final String body;
}

// ==================== 推荐高级选项折叠组件 ====================

/// 推荐高级选项折叠 tile
///
/// 基础推荐设置始终显示；高级选项（完播率门控、时间衰减、反疲劳、用户评分）
/// 默认折叠，点击"高级选项"后展开。展开状态为局部 state，页面重建后重置为折叠。
class _RecommendAdvancedTile extends StatefulWidget {
  const _RecommendAdvancedTile({required this.advancedTilesBuilder});

  /// 高级选项 tile 构建器：每次 build 时调用，确保 ref.watch 生效
  final List<Widget> Function() advancedTilesBuilder;

  @override
  State<_RecommendAdvancedTile> createState() => _RecommendAdvancedTileState();
}

class _RecommendAdvancedTileState extends State<_RecommendAdvancedTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: SettingsView._IconContainer(
            icon: Icons.tune,
            color: Colors.pink,
          ),
          title: Text(
            '高级选项',
            style:
                TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
          ),
          subtitle: Text(
            '完播率门控、时间衰减、反疲劳、用户评分',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: _kFontSizeBody,
            ),
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: scheme.onSurfaceVariant,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        // 仅在展开时构建高级 tiles，避免折叠状态下触发不必要的 ref.watch
        if (_expanded) ...[
          const Divider(height: 1, indent: 56),
          ..._buildAdvancedTilesWithDividers(),
        ],
      ],
    );
  }

  // 构建高级选项 tiles，每项之间插入分隔线（最后一项后无分隔线）
  List<Widget> _buildAdvancedTilesWithDividers() {
    final tiles = widget.advancedTilesBuilder();
    final result = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        result.add(const Divider(height: 1, indent: 56));
      }
      result.add(tiles[i]);
    }
    return result;
  }
}

// ==================== 推荐标签数据源映射组件 ====================

/// 推荐标签数据源映射折叠 tile
///
/// 推荐页标签栏的每个标签（最新影片/续看/为你推荐/精选/相似/高分/移动客户端推荐）
/// 默认一对一绑定对应数据源，用户可自定义每个标签绑定的数据源。
class _RecommendTagMappingTile extends StatefulWidget {
  const _RecommendTagMappingTile();

  @override
  State<_RecommendTagMappingTile> createState() =>
      _RecommendTagMappingTileState();
}

class _RecommendTagMappingTileState extends State<_RecommendTagMappingTile> {
  bool _expanded = false;

  // 可选择的 7 个数据源（关注源 nextUp 不参与标签绑定）
  static const List<RecommendSource> _selectableSources = [
    RecommendSource.latest,
    RecommendSource.resume,
    RecommendSource.suggestions,
    RecommendSource.nativeRecommendations,
    RecommendSource.similar,
    RecommendSource.recommendations,
    RecommendSource.localRecommend,
  ];

  static String _sourceLabel(String key) {
    for (final source in _selectableSources) {
      if (source.key == key) return source.label;
    }
    return key;
  }

  Future<void> _pickSource(BuildContext context, WidgetRef ref, String tagLabel,
      String currentKey) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '「$tagLabel」标签数据源',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final source in _selectableSources)
              ListTile(
                leading: Icon(
                  source.key == currentKey
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: source.key == currentKey
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(source.label),
                onTap: () => Navigator.pop(context, source.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != currentKey && context.mounted) {
      await ref
          .read(recommendTagSourceMappingProvider.notifier)
          .setMapping(tagLabel, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: SettingsView._IconContainer(
            icon: Icons.sell_outlined,
            color: Colors.indigo,
          ),
          title: Text(
            '推荐标签数据源',
            style:
                TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
          ),
          subtitle: Text(
            '每个标签可绑定不同数据源',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: _kFontSizeBody,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsView._helpButton(
                helpText:
                    '自定义推荐页顶部标签栏每个标签对应的数据源。\n\n· 默认：最新影片→最新入库、继续观看→未看完、为你推荐→服务器建议、精选→原生精选、相似→相似推荐、高分→高分视频、移动客户端推荐→本地收藏\n· 点击标签行可更换其数据源\n· 更换后，标签栏计数与点击过滤都按新数据源计算\n· 两个标签绑定同一数据源时，内容相同且会同时高亮\n\n可一键恢复默认映射。',
                title: '推荐标签数据源',
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded) ...[
          const Divider(height: 1, indent: 56),
          _RecommendTagMappingListTile(
            pickSource: (context, ref, label, current) =>
                _pickSource(context, ref, label, current),
          ),
        ],
      ],
    );
  }
}

/// 标签映射列表（单独 ConsumerWidget：仅展开时构建，ref.watch 实时生效）
class _RecommendTagMappingListTile extends ConsumerWidget {
  const _RecommendTagMappingListTile({required this.pickSource});

  final Future<void> Function(
          BuildContext context, WidgetRef ref, String label, String current)
      pickSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mapping = ref.watch(recommendTagSourceMappingProvider);
    final entries = mapping.entries.toList(growable: false);
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 56),
          ListTile(
            leading: Icon(Icons.label_outline,
                color: scheme.onSurfaceVariant, size: 20),
            title: Text(
              entries[i].key,
              style: TextStyle(
                  color: scheme.onSurface, fontSize: _kFontSizeMedium),
            ),
            subtitle: Text(
              '数据源：${_RecommendTagMappingTileState._sourceLabel(entries[i].value)}',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: _kFontSizeSmall),
            ),
            trailing: Icon(Icons.chevron_right,
                color: scheme.onSurfaceVariant, size: 20),
            onTap: () =>
                pickSource(context, ref, entries[i].key, entries[i].value),
          ),
        ],
        // 恢复默认映射
        ListTile(
          leading:
              Icon(Icons.restart_alt, color: scheme.onSurfaceVariant, size: 20),
          title: Text(
            '恢复默认映射',
            style: TextStyle(
                color: scheme.onSurfaceVariant, fontSize: _kFontSizeSmall),
          ),
          onTap: () async {
            await ref
                .read(recommendTagSourceMappingProvider.notifier)
                .resetMapping();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已恢复默认标签数据源映射')),
              );
            }
          },
        ),
      ],
    );
  }
}

/// 规则筛选子分区折叠卡片：标题栏 + 可折叠设置项
///
/// 折叠时不构建 children（避免折叠状态下触发不必要的 ref.watch），
/// 展开时通过 childrenBuilder 每次构建，保证 ref.watch 实时生效。
class _RuleSection extends StatefulWidget {
  const _RuleSection({
    required this.icon,
    required this.title,
    required this.childrenBuilder,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final List<Widget> Function() childrenBuilder;
  final bool initiallyExpanded;

  @override
  State<_RuleSection> createState() => _RuleSectionState();
}

class _RuleSectionState extends State<_RuleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: _kFontSizeSmall,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.childrenBuilder(),
        SettingsView._ruleSectionDivider(scheme),
      ],
    );
  }
}

// ==================== 设置搜索 ====================

/// 单个可搜索的设置入口
class _SettingEntry {
  const _SettingEntry({
    required this.title,
    required this.section,
    required this.keywords,
    required this.onTap,
  });
  final String title;
  final String section;
  final String keywords;
  final void Function(BuildContext context) onTap;

  /// 判断该入口是否匹配搜索词（标题、分组、关键词任一命中即可）
  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        section.toLowerCase().contains(q) ||
        keywords.toLowerCase().contains(q);
  }
}

/// 设置搜索底部表单：实时过滤设置项，点击后执行对应操作并关闭
class _SettingsSearchSheet extends StatefulWidget {
  const _SettingsSearchSheet({required this.entries});
  final List<_SettingEntry> entries;

  @override
  State<_SettingsSearchSheet> createState() => _SettingsSearchSheetState();
}

class _SettingsSearchSheetState extends State<_SettingsSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_SettingEntry> get _filtered {
    if (_query.isEmpty) return widget.entries;
    return widget.entries.where((e) => e.matches(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _filtered;
    // 设置为屏幕高度的 70%，确保 Expanded 有明确的高度约束
    final sheetHeight = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: sheetHeight,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索设置项…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            // 搜索结果列表
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配的设置项',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final entry = results[index];
                        return ListTile(
                          leading: Icon(Icons.settings_outlined,
                              color: scheme.primary),
                          title: Text(entry.title),
                          subtitle: Text(
                            entry.section,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: _kFontSizeSmall,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pop(context);
                            entry.onTap(context);
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
}
