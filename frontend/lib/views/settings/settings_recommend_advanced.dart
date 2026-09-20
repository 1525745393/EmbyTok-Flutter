part of '../settings_view.dart';

// 从 settings_view.dart 拆分（part 文件，无行为变化）

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
          leading: settingsIconContainer(
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

  // 各数据源对应的 Emby 规则说明（帮助按钮展示）
  static const Map<String, String> _sourceHelpTexts = {
    'latest':
        '「最新影片」数据源规则（Emby /Items/Latest）：\n\n· 按服务器「最新入库」排序拉取所选媒体库最近入库的视频\n· 单选媒体库时只在该库内取；多选时合并展示\n· 参与通用过滤：最短时长、排除已看、反疲劳、用户评分\n\n无新入库内容时标签自动隐藏。',
    'resume':
        '「继续观看」数据源规则（Emby Resume 接口）：\n\n· 拉取服务器记录的「未看完」视频\n· 依赖播放位置上报：看过但未看完才会出现在这里\n· 参与通用过滤（最短时长、反疲劳等）\n\n没有未看完的视频时标签自动隐藏。',
    'suggestions':
        '「为你推荐」数据源规则（Emby /Users/{id}/Suggestions）：\n\n· 调用 Emby 服务器的个性化建议接口\n· 内容由服务器基于观看历史生成\n· 老版本 Emby / Jellyfin 不支持该接口时返回空\n\n无建议数据时标签自动隐藏。',
    'nativeRecommendations':
        '「精选」数据源规则（Emby /Movies/Recommendations + /Shows/Recommended）：\n\n· 由 Emby 服务器基于观看历史生成，无分页\n· 单选媒体库时限定该库；多选时跨库全局推荐\n· 老版本 Emby / Jellyfin 不支持端点时返回空\n\n依赖服务器端推荐数据，无数据时标签自动隐藏。',
    'similar':
        '「相似」数据源规则（Emby /Items/{id}/Similar）：\n\n· 种子选取顺序：收藏影片 → 高完播影片 → 最近高分项\n· 取 Top 种子后并发请求 Similar 接口合并结果\n· 受「使用观看历史」开关影响：关闭时无种子来源\n\n需要观看历史支撑，冷启动用户可能为空。',
    'recommendations':
        '「高分」数据源规则（Emby 高分推荐接口）：\n\n· 从所选媒体库拉取高评分视频（CommunityRating ≥ 评分阈值）\n· 多媒体库并发拉取后合并去重\n· 受设置影响：评分阈值、排除已看、推荐类型、最短时长\n\n评分数据不足时内容会减少。',
    'localRecommend':
        '「移动客户端推荐」数据源规则（本地信号源，非 Emby 接口）：\n\n· 直接拉取你在 Emby 中「收藏的影片」\n· 不依赖服务器推荐能力，任何 Emby 版本都可用\n· 无收藏时标签自动隐藏\n\n内容与「收藏」页一致。',
  };

  static String sourceHelpText(String key) =>
      _sourceHelpTexts[key] ?? '该数据源暂无规则说明。';

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
          leading: settingsIconContainer(
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
              settingsHelpButton(
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                settingsHelpButton(
                  helpText: _RecommendTagMappingTileState.sourceHelpText(
                      entries[i].value),
                  title: entries[i].key,
                ),
                Icon(Icons.chevron_right,
                    color: scheme.onSurfaceVariant, size: 20),
              ],
            ),
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
