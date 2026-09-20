// 从 actors_view.dart 拆分（part 文件，无行为变化）

part of '../actors_view.dart';

// ==================== _ActorActions ====================

extension _ActorActions on _ActorsViewState {
  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 恢复类型筛选
      // 用 containsKey 判断键是否存在，兼容旧版本可能写入的 'null' 字符串数据
      if (prefs.containsKey(kStorageKeyActorsSelectedType)) {
        final savedType = prefs.getString(kStorageKeyActorsSelectedType);
        // 兼容旧版本写入的 'null' 字符串：视为无筛选（null）
        if (savedType != null && savedType.isNotEmpty && savedType != 'null') {
          ref.read(actorsProvider.notifier).setSelectedType(savedType);
        }
      }

      // 恢复 Tab 索引
      final savedTab = prefs.getInt(kStorageKeyActorsSelectedTab);
      if (savedTab != null &&
          savedTab >= 0 &&
          savedTab < _ActorsViewState._actorTabsCount) {
        _tabController.index = savedTab;
      }

      // 恢复搜索关键词
      final savedSearch = prefs.getString(kStorageKeyActorsSearchQuery);
      if (savedSearch != null && savedSearch.isNotEmpty) {
        _searchController.text = savedSearch;
        ref.read(actorsProvider.notifier).searchActors(savedSearch);
      }

      // 恢复排序模式
      final savedSortMode = prefs.getString(kStorageKeyActorsSortMode);
      if (savedSortMode != null &&
          (savedSortMode == kActorsSortDefault ||
              savedSortMode == kActorsSortName ||
              savedSortMode == kActorsSortFavoritedAt)) {
        _sortMode = savedSortMode;
      }

      // 恢复网格列数
      final savedGridColumns = prefs.getInt(kStorageKeyActorsGridColumns);
      if (savedGridColumns == 3 || savedGridColumns == 4) {
        _gridColumns = savedGridColumns as int;
      }
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  Future<void> _saveSelectedType(String? type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (type == null) {
        // "全部"类型：移除保存的键，而非写入 'null' 占位符
        await prefs.remove(kStorageKeyActorsSelectedType);
      } else {
        await prefs.setString(kStorageKeyActorsSelectedType, type);
      }
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  Future<void> _saveSelectedTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyActorsSelectedTab, index);
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    _searchSaveDebounceTimer?.cancel();
    _searchSaveDebounceTimer =
        Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kStorageKeyActorsSearchQuery, query);
      } catch (_) {
        // 存储操作失败不影响主流程，静默处理
      }
    });
  }

  Future<void> _saveSortMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kStorageKeyActorsSortMode, mode);
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  Future<void> _saveGridColumns(int columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kStorageKeyActorsGridColumns, columns);
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  void _saveScrollOffset() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        if (!_scrollController.hasClients) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(
            kStorageKeyActorsScrollOffset, _scrollController.offset);
      } catch (_) {
        // 存储操作失败不影响主流程，静默处理
      }
    });
  }

  Future<void> _restoreScrollOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offset = prefs.getDouble(kStorageKeyActorsScrollOffset);
      if (offset != null && offset > 0 && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final safeOffset = offset.clamp(0.0, maxScroll);
        _scrollController.jumpTo(safeOffset);
      }
    } catch (_) {
      // 存储操作失败不影响主流程，静默处理
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _saveSelectedTab(_tabController.index);
  }

  void _onScroll() {
    _saveScrollOffset();
  }

  Future<void> _onRefresh() async {
    await ref.read(actorsProvider.notifier).loadActors(forceRefresh: true);
  }

  List<Person> _applySort(List<Person> list, Set<String> favIds) {
    if (_sortMode == kActorsSortDefault) {
      return list;
    }
    final indexed = List.generate(list.length, (i) => MapEntry(i, list[i]));
    if (_sortMode == kActorsSortName) {
      indexed.sort((a, b) {
        final cmp =
            a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase());
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    } else if (_sortMode == kActorsSortFavoritedAt) {
      indexed.sort((a, b) {
        final aFav = favIds.contains(a.value.id) ? 0 : 1;
        final bFav = favIds.contains(b.value.id) ? 0 : 1;
        final cmp = aFav.compareTo(bFav);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });
    }
    return indexed.map((e) => e.value).toList();
  }

  void _navigateToPersonDetail(Person actor) {
    // 确保 personId 不为空，否则路由匹配失败
    final personId = actor.id ?? '';
    if (personId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该演员缺少 ID，无法查看详情')),
      );
      return;
    }
    final mediaItem = MediaItem(
      id: personId,
      title: actor.name,
      type: 'Person',
      thumbnailUrl: actor.imageUrl,
      overview: actor.overview,
    );
    context.push('/person/$personId', extra: {
      'item': mediaItem,
      'personType': actor.type,
    });
  }
}
