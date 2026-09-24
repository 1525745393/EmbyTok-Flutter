// 从 settings_view.dart 拆分（part 文件，无行为变化）

part of '../settings_view.dart';

// ==================== _SettingsRecommendRules ====================

extension _SettingsRecommendRules on SettingsView {
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

  Widget _buildFeedLibraryTile(BuildContext context, WidgetRef ref) {
    final selectedLibraries = ref.watch(selectedLibrariesProvider);
    final feedType = ref.watch(feedTypeProvider);
    return settingsLibrarySelectionTile(
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

  Widget _buildFeedExcludePlayedTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(feedExcludePlayedProvider);
    return settingsSwitchTile(
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

  Widget _buildRecommendLibraryTile(BuildContext context, WidgetRef ref) {
    final recommendLibraries = ref.watch(recommendLibrariesProvider);
    return settingsLibrarySelectionTile(
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

  Widget _buildDiscoverGenresTile(BuildContext context, WidgetRef ref) {
    final discover = ref.watch(discoverProvider);
    // 从 genres 列表匹配已知名称；未匹配的 selectedGenreIds 项直接作为名称显示
    final knownNames = discover.genres
        .where((g) => discover.selectedGenreIds.contains(g.id))
        .map((g) => g.name)
        .toSet();
    final unmatched = discover.selectedGenreIds
        .where((id) => !discover.genres.any((g) => g.id == id))
        .toList();
    final names = [...knownNames, ...unmatched];
    final scheme = Theme.of(context).colorScheme;
    final empty = discover.selectedGenreIds.isEmpty;
    return ListTile(
      leading: settingsIconContainer(
          icon: Icons.explore_outlined, color: Colors.orange),
      title: Text(
        '发现·类型',
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: empty
            ? Text(
                '选择 Emby 类型（标签），首页「发现」展示对应影片',
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
                  for (final name in names)
                    settingsLibraryChip(
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
          settingsHelpButton(
            helpText:
                '「发现·类型」决定首页顶栏「发现」数据源中的类型来源。\n\n· 从 Emby 服务器拉取全部类型（流派），多选后发现页按所选类型逐个拉取影片合并展示\n· 可与「发现·标签」「发现·合集」同时生效，三种来源的影片合并去重\n· 不选择任何来源时，发现页为空并引导去设置\n\n与推荐、关注相互独立。',
            title: '发现·类型',
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _showDiscoverSourceDialog(
        context,
        ref,
        title: '选择发现类型',
        emptyMessage: '无法获取类型列表，请检查服务器连接',
        itemsOf: (s) => s.genres,
        selectedOf: (s) => s.selectedGenreIds,
        refresh: () => ref.read(discoverProvider.notifier).refreshGenres(),
        onSave: (ids) => ref.read(discoverProvider.notifier).saveSelection(ids),
      ),
    );
  }

  Widget _buildDiscoverTagsTile(BuildContext context, WidgetRef ref) {
    final discover = ref.watch(discoverProvider);
    final names = discover.tags
        .where((t) => discover.selectedTagIds.contains(t.id))
        .map((t) => t.name)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final empty = discover.selectedTagIds.isEmpty || names.isEmpty;
    return ListTile(
      leading: settingsIconContainer(
          icon: Icons.label_outline, color: Colors.lightBlue),
      title: Text(
        '发现·标签',
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: empty
            ? Text(
                '选择 Emby 标签（Tags），首页「发现」展示标签下影片',
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
                    settingsLibraryChip(
                      label: '已选 ${discover.selectedTagIds.length} 个标签',
                      icon: Icons.label_outline,
                      color: scheme.onSurfaceVariant,
                      background: scheme.surfaceContainerHighest,
                    )
                  else
                    for (final name in names)
                      settingsLibraryChip(
                        label: name,
                        icon: Icons.label_outline,
                        color: scheme.onSurfaceVariant,
                        background: scheme.surfaceContainerHighest,
                      ),
                ],
              ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          settingsHelpButton(
            helpText:
                '「发现·标签」决定首页顶栏「发现」数据源中的标签来源。\n\n· 从 Emby 服务器拉取全部标签（Tags），多选后发现页按所选标签逐个拉取影片合并展示\n· 标签与类型（Genres）不同：类型是流派分类，标签是自定义标记（如 4K、国配、导演剪辑）\n· 可与「发现·类型」「发现·合集」同时生效，三种来源的影片合并去重\n· 不选择任何来源时，发现页为空并引导去设置\n\n与推荐、关注相互独立。',
            title: '发现·标签',
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _showDiscoverSourceDialog(
        context,
        ref,
        title: '选择发现标签',
        emptyMessage: '无法获取标签列表，请检查服务器连接',
        itemsOf: (s) => s.tags,
        selectedOf: (s) => s.selectedTagIds,
        refresh: () => ref.read(discoverProvider.notifier).refreshTags(),
        onSave: (ids) => ref.read(discoverProvider.notifier).saveTags(ids),
      ),
    );
  }

  Widget _buildDiscoverCollectionsTile(BuildContext context, WidgetRef ref) {
    final discover = ref.watch(discoverProvider);
    final names = discover.collections
        .where((c) => discover.selectedCollectionIds.contains(c.id))
        .map((c) => c.name)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final empty = discover.selectedCollectionIds.isEmpty || names.isEmpty;
    return ListTile(
      leading: settingsIconContainer(
          icon: Icons.collections_bookmark_outlined, color: Colors.deepOrange),
      title: Text(
        '发现·合集',
        style: TextStyle(color: scheme.onSurface, fontSize: _kFontSizeLarge),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: empty
            ? Text(
                '选择 Emby 合集，首页「发现」展示合集内影片',
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
                    settingsLibraryChip(
                      label: '已选 ${discover.selectedCollectionIds.length} 个合集',
                      icon: Icons.collections_bookmark_outlined,
                      color: scheme.onSurfaceVariant,
                      background: scheme.surfaceContainerHighest,
                    )
                  else
                    for (final name in names)
                      settingsLibraryChip(
                        label: name,
                        icon: Icons.collections_bookmark_outlined,
                        color: scheme.onSurfaceVariant,
                        background: scheme.surfaceContainerHighest,
                      ),
                ],
              ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          settingsHelpButton(
            helpText:
                '「发现·合集」决定首页顶栏「发现」数据源中的合集来源。\n\n· 从 Emby 服务器拉取全部合集（BoxSet，如系列电影、导演合辑），多选后发现页按所选合集逐个拉取合集内影片合并展示\n· 可与「发现·类型」「发现·标签」同时生效，三种来源的影片合并去重\n· 服务器没有合集（BoxSet）时列表为空\n\n合集内容来自服务器整理的系列/合辑，与推荐、关注相互独立。',
            title: '发现·合集',
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: () => _showDiscoverSourceDialog(
        context,
        ref,
        title: '选择发现合集',
        emptyMessage: '无法获取合集列表（服务器可能没有合集），请检查服务器连接',
        itemsOf: (s) => s.collections,
        selectedOf: (s) => s.selectedCollectionIds,
        refresh: () => ref.read(discoverProvider.notifier).refreshCollections(),
        onSave: (ids) =>
            ref.read(discoverProvider.notifier).saveCollections(ids),
      ),
    );
  }

  Future<void> _showDiscoverSourceDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String emptyMessage,
    required List<Library> Function(DiscoverState) itemsOf,
    required List<String> Function(DiscoverState) selectedOf,
    required Future<void> Function() refresh,
    required Future<void> Function(List<String>) onSave,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    // 确保条目列表已加载（refresh 后重新读取，避免使用旧快照）
    await refresh();
    if (!context.mounted) return;
    final state = ref.read(discoverProvider);
    final effectiveItems = itemsOf(state);
    final selectedIds = selectedOf(state);

    // 把已选但不在列表中的项追加到末尾，让用户可以取消
    final knownIds = effectiveItems.map((e) => e.id).toSet();
    final extraSelected = selectedIds
        .where((id) => !knownIds.contains(id))
        .map((id) => Library(id: id, name: id, type: 'Unknown'))
        .toList();
    final allItems = [...effectiveItems, ...extraSelected];

    if (allItems.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    // 本地副本供勾选（不直接改 provider，点确定才保存）
    final selected = Set<String>.from(selectedIds);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) => ListView.builder(
              itemCount: allItems.length,
              itemBuilder: (context, i) {
                final g = allItems[i];
                final checked = selected.contains(g.id);
                final isExtra = i >= effectiveItems.length;
                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    isExtra ? '${g.name}（未在服务器列表）' : g.name,
                    style: TextStyle(
                      color:
                          isExtra ? scheme.onSurfaceVariant : scheme.onSurface,
                      fontStyle: isExtra ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
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
              onSave(selected.toList());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendMinRatingTile(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(recommendMinRatingProvider);
    return settingsTapTile(
      icon: Icons.star_outline,
      iconColor: Colors.amber,
      title: '评分阈值',
      subtitle: rating == 0 ? '不过滤' : '≥ $rating',
      onTap: () => _showRecommendRatingDialog(context, ref, rating),
      helpText:
          '设置推荐内容的最低评分门槛。\n\n只有 Emby 社区评分（CommunityRating）≥ 该值的影片才会进入推荐页，用于过滤烂片。\n\n· 默认 4.0\n· 调高 → 推荐更精但内容更少\n· 调低 → 内容更多但质量参差\n\n注意：仅影响「高分」等评分相关数据源。',
    );
  }

  Widget _buildRecommendExcludePlayedTile(BuildContext context, WidgetRef ref) {
    final exclude = ref.watch(recommendExcludePlayedProvider);
    return settingsSwitchTile(
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

  Widget _buildRecommendMinRuntimeTile(BuildContext context, WidgetRef ref) {
    final sec = ref.watch(recommendMinRuntimeSecProvider);
    return settingsTapTile(
      icon: Icons.timer_outlined,
      iconColor: Colors.deepOrange,
      title: '最短时长',
      subtitle: sec == 0 ? '不过滤' : '$sec 秒以上',
      onTap: () => _showRecommendRuntimeDialog(context, ref, sec),
      helpText:
          '过滤推荐内容的最短时长（秒）。\n\n短于该时长的内容（如短片、花絮）不会出现在推荐页。\n\n· 默认 30 秒；设为 0 则不过滤\n· 调大可过滤短片、预告片',
    );
  }
}
