part of 'local_video_view.dart';

/// 单个文件源完整列表页（点"查看所有"进入）：对齐 Emby 资源库页
class _SourceFullListPage extends ConsumerStatefulWidget {
  const _SourceFullListPage({required this.sourceId, required this.sourceName});
  final String sourceId;
  final String sourceName;

  @override
  ConsumerState<_SourceFullListPage> createState() =>
      _SourceFullListPageState();
}

class _SourceFullListPageState extends ConsumerState<_SourceFullListPage> {
  int _tab = 0; // 电影/播放记录/分类/合集/文件夹
  int _viewMode = 0; // 0=竖版海报, 1=横版backdrop, 2=列表
  String _sortBy = 'name';
  bool _sortAscending = true;
  String? _genreFilter; // 分类 Tab 当前选中类型
  String? _scrapeStatusFilter; // 分类 Tab 刮削状态筛选：unscraped/incomplete/complete
  String _watchFilter = '全部'; // 全部/续看/未观看/已观看
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  /// 续播进度缓存：pathHash -> 毫秒（"续看/已观看"筛选需要区分未完成进度，batch 25 F3）
  final Map<String, int> _resumeMs = {};

  /// 最近播放时间戳缓存：pathHash -> epochMs（batch53-F1："播放日期"排序真实时间源）
  final Map<String, int> _resumeAtMs = {};

  static const _sortOptions = {
    'name': '按名称',
    'time': '按时间',
    'rating': '按评分',
    'added': '加入时间',
    'certification': '家长分级',
    'year': '年份',
    'criticRating': '影评人评分',
    'playDate': '播放日期',
    'duration': '播放时长',
    'lastAdded': '最后一集添加日期',
    'resolution': '分辨率',
    'size': '大小',
    'bitrate': '比特率',
    'random': '随机',
  };

  static const _watchFilters = ['全部', '续看', '未观看', '已观看'];

  List<LocalVideoItem> _applySort(
      List<LocalVideoItem> items, LocalVideoState state) {
    final list = [...items];
    double gR(String h) => state.scrapedMap[h]?.rating ?? 0;
    int gY(String h) => state.scrapedMap[h]?.year ?? 0;
    int cmp(dynamic a, dynamic b) =>
        Comparable.compare(a is Comparable ? a : 0, b is Comparable ? b : 0);
    void r() => list.sort((a, b) {
          int r;
          // 每个 case 必须 break：fallthrough 会把比较结果一路覆盖到 default r=0，全部排序失效（batch 30 F1）
          switch (_sortBy) {
            case 'name':
              r = (state.scrapedMap[a.pathHash]?.title ?? a.name)
                  .compareTo(state.scrapedMap[b.pathHash]?.title ?? b.name);
              break;
            case 'time':
              // 自然升序（旧在前）；方向由 _sortAscending 统一翻转，保证箭头与结果一致
              r = a.modifiedAt.compareTo(b.modifiedAt);
              break;
            case 'playDate':
              // batch53-F1：按最近播放时间戳排序（local_resume_time_ 键），未播放过（0）排前
              r = (_resumeAtMs[a.pathHash] ?? 0)
                  .compareTo(_resumeAtMs[b.pathHash] ?? 0);
              break;
            case 'added':
              r = a.modifiedAt.compareTo(b.modifiedAt);
              break;
            case 'lastAdded':
              // batch53-F1：按刮削加入时间（scrapedAt）排序，未刮削（0）排前
              r = (state.scrapedMap[a.pathHash]?.scrapedAt ?? 0)
                  .compareTo(state.scrapedMap[b.pathHash]?.scrapedAt ?? 0);
              break;
            case 'year':
              r = gY(a.pathHash).compareTo(gY(b.pathHash));
              break;
            case 'rating':
            case 'criticRating':
              r = gR(a.pathHash).compareTo(gR(b.pathHash));
              break;
            case 'certification':
              r = (state.scrapedMap[a.pathHash]?.certification ?? '')
                  .compareTo(state.scrapedMap[b.pathHash]?.certification ?? '');
              break;
            case 'duration':
              r = a.duration.inSeconds.compareTo(b.duration.inSeconds);
              break;
            case 'size':
              r = a.sizeBytes.compareTo(b.sizeBytes);
              break;
            case 'resolution':
              // 按像素总量（宽×高）排序；元数据缺失宽高时排最后
              int px(LocalVideoItem e) =>
                  (e.width > 0 && e.height > 0) ? e.width * e.height : -1;
              r = px(a).compareTo(px(b));
              break;
            case 'bitrate':
              int bps(LocalVideoItem e) => e.duration.inSeconds > 0
                  ? e.sizeBytes ~/ e.duration.inSeconds
                  : 0;
              r = bps(a).compareTo(bps(b));
              break;
            default:
              r = 0;
          }
          return _sortAscending ? r : -r;
        });
    if (_sortBy == 'random') {
      list.shuffle();
      return list;
    }
    r();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadResumeProgress();
  }

  /// 异步预读本源所有项的续播进度（SharedPreferences 内存缓存，全量读取开销低）
  Future<void> _loadResumeProgress() async {
    final state = ref.read(localVideoProvider);
    final items =
        state.items.where((e) => e.sourceId == widget.sourceId).toList();
    final map = <String, int>{};
    final sp = await SharedPreferences.getInstance();
    for (final it in items) {
      final ms = await LocalVideoService().readResumeMs(it.pathHash);
      if (ms != null && ms > 0) map[it.pathHash] = ms;
      // batch53-F1："播放日期"排序需要真实播放时间戳（写端 local_play_page._savePosition）
      final t = sp.getInt('local_resume_time_${it.pathHash}');
      if (t != null && t > 0) _resumeAtMs[it.pathHash] = t;
    }
    if (mounted) setState(() => _resumeMs.addAll(map));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localVideoProvider);
    final allItems =
        state.items.where((e) => e.sourceId == widget.sourceId).toList();

    // 查找当前源的媒体类型
    final sources = ref.watch(fileSourcesProvider);
    final src = sources
        .where((s) => s.id == widget.sourceId)
        .cast<FileSource?>()
        .firstWhere((_) => true, orElse: () => null);
    final isTv = src?.config['mediaType'] == 'tv';

    // TV 源按剧名分组
    List<LocalVideoItem> items;
    switch (_tab) {
      case 1: // 播放记录
        final played = state.recentHashes.toSet();
        items = allItems.where((e) => played.contains(e.pathHash)).toList();
        break;
      default:
        items = allItems;
    }
    // 观看状态筛选
    if (_watchFilter != '全部') {
      final played = state.recentHashes.toSet();
      items = items.where((e) {
        switch (_watchFilter) {
          // '续看' = 播放过且有未完成续播进度（剩余不足 30s 视为已看完，排除）
          case '续看':
            final ms = _resumeMs[e.pathHash];
            return played.contains(e.pathHash) &&
                ms != null &&
                ms < e.duration.inMilliseconds - 30000;
          case '未观看':
            return !played.contains(e.pathHash);
          // '已观看' = 播放过且无未完成续播进度（与 '续看' 互斥，batch 25 F3）
          case '已观看':
            final ms = _resumeMs[e.pathHash];
            return played.contains(e.pathHash) &&
                !(ms != null && ms < e.duration.inMilliseconds - 30000);
          default:
            return true;
        }
      }).toList();
    }
    // 搜索
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((e) {
        final s = state.scrapedMap[e.pathHash];
        final title = (s?.title ?? e.name).toLowerCase();
        return title.contains(q);
      }).toList();
    }
    items = _applySort(items, state);

    // TV 源默认 Tab（0）按剧名分组显示海报网格
    if (isTv && _tab == 0) {
      final groups = <String, List<LocalVideoItem>>{};
      for (final it in items) {
        final folder = ScrapeService.extractSeriesName(it.relativePath) ??
            (it.relativePath?.split('/').where((s) => s.isNotEmpty).last ??
                '未分组');
        groups.putIfAbsent(folder, () => []).add(it);
      }
      return Scaffold(
        appBar: _buildAppBar(allItems.length),
        body: Column(
          children: [
            _buildTabBar(isTv),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: groups.length,
                itemBuilder: (_, i) {
                  final entry = groups.entries.elementAt(i);
                  final eps = entry.value;
                  final s = state.scrapedMap[eps.first.pathHash];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<Widget>(
                        builder: (_) => _FolderEpisodePage(
                            folderName: entry.key, items: eps),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: s?.posterPath != null
                                    ? CachedNetworkImage(
                                        imageUrl: TmdbService.posterUrl(
                                            s!.posterPath!),
                                        fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.tv,
                                            size: 32, color: Colors.white24)),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.pinkAccent,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text('${eps.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(s?.title ?? entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            s?.year != null
                                ? '${s!.year}-现在'
                                : '${eps.length} 集',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(allItems.length),
      body: Column(
        children: [
          _buildTabBar(isTv),
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '在${widget.sourceName}中搜索…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _showSearch = false;
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }),
                    tooltip: '清除搜索',
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
          // 观看状态筛选
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _watchFilters.map((f) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    selected: _watchFilter == f,
                    onSelected: (_) => setState(() => _watchFilter = f),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(child: _buildTabBody(items, state)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int count) {
    return AppBar(
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.sourceName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text('当前项目数: $count',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
      actions: [
        // 视图切换：竖版海报→横版backdrop→列表
        IconButton(
          icon: Icon(
            _viewMode == 0
                ? Icons.grid_view
                : _viewMode == 1
                    ? Icons.rectangle
                    : Icons.view_list,
            size: 22,
          ),
          tooltip: _viewMode == 0
              ? '竖版海报'
              : _viewMode == 1
                  ? '横版海报'
                  : '列表',
          onPressed: () => setState(() => _viewMode = (_viewMode + 1) % 3),
        ),
        // 搜索
        IconButton(
          icon: Icon(_showSearch ? Icons.filter_alt : Icons.search, size: 22),
          onPressed: () => setState(() => _showSearch = !_showSearch),
        ),
        // 排序
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort, size: 22),
          tooltip: '排序',
          onSelected: (v) => setState(() => _sortBy = v),
          itemBuilder: (_) => _sortOptions.entries
              .map((e) => PopupMenuItem(
                  value: e.key,
                  child: Row(children: [
                    if (e.key == _sortBy)
                      const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ])))
              .toList(),
        ),
        // 升/降序
        IconButton(
          icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20),
          tooltip: _sortAscending ? '升序' : '降序',
          onPressed: () => setState(() => _sortAscending = !_sortAscending),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isTv) {
    final labels = isTv
        ? ['电视剧', '播放记录', '分类', '合集', '文件夹']
        : ['电影', '播放记录', '分类', '合集', '文件夹'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            _tab == i ? FontWeight.w700 : FontWeight.normal,
                        color: _tab == i
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 2,
                      width: 24,
                      color: _tab == i
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 按当前 Tab 渲染内容
  Widget _buildTabBody(List<LocalVideoItem> items, LocalVideoState state) {
    switch (_tab) {
      case 2: // 分类：顶部类型 chips + 网格
        final genres = <String>{};
        for (final it in items) {
          final s = state.scrapedMap[it.pathHash];
          if (s != null) genres.addAll(s.genres);
        }
        final filtered = _genreFilter == null
            ? items
            : items.where((it) {
                final s = state.scrapedMap[it.pathHash];
                return s?.genres.contains(_genreFilter) ?? false;
              }).toList();
        // 刮削状态筛选（P3）：未刮削/不完整/完整
        final statusFilter = _scrapeStatusFilter;
        final statusFiltered = statusFilter == null
            ? filtered
            : filtered.where((it) {
                final st =
                    ScrapeService.statusOf(state.scrapedMap[it.pathHash]);
                switch (statusFilter) {
                  case 'unscraped':
                    return st == ScrapeStatus.unscraped;
                  case 'incomplete':
                    return st == ScrapeStatus.incomplete;
                  case 'complete':
                    return st == ScrapeStatus.complete;
                  default:
                    return true;
                }
              }).toList();
        return Column(
          children: [
            // 刮削状态筛选 chips（P3）
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _scrapeStatusFilter == null,
                    onSelected: (_) =>
                        setState(() => _scrapeStatusFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('未刮削'),
                    selected: _scrapeStatusFilter == 'unscraped',
                    onSelected: (_) =>
                        setState(() => _scrapeStatusFilter = 'unscraped'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('不完整'),
                    selected: _scrapeStatusFilter == 'incomplete',
                    onSelected: (_) =>
                        setState(() => _scrapeStatusFilter = 'incomplete'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('完整'),
                    selected: _scrapeStatusFilter == 'complete',
                    onSelected: (_) =>
                        setState(() => _scrapeStatusFilter = 'complete'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _genreFilter == null,
                    onSelected: (_) => setState(() => _genreFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...genres.map((g) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: _genreFilter == g,
                          onSelected: (_) => setState(() => _genreFilter = g),
                        ),
                      )),
                ],
              ),
            ),
            Expanded(
              child: statusFiltered.isEmpty
                  ? const Center(child: Text('暂无内容'))
                  : _buildBody(statusFiltered, state),
            ),
          ],
        );
      case 3: // 合集：按 tvId / 标题分组
        final groups = <String, List<LocalVideoItem>>{};
        for (final it in items) {
          final s = state.scrapedMap[it.pathHash];
          final key = s?.tvId != null ? 'tv_${s!.tvId}' : (s?.title ?? it.name);
          groups.putIfAbsent(key, () => []).add(it);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: groups.entries.map((e) {
            final first = e.value.first;
            final s = state.scrapedMap[first.pathHash];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: s?.posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: TmdbService.posterUrl(s!.posterPath!),
                          fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, size: 20)),
                ),
              ),
              title: Text(s?.title ?? first.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${e.value.length} 个项目'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<Widget>(
                  builder: (_) => _GroupListPage(
                      title: s?.title ?? first.name,
                      items: e.value,
                      state: state),
                ),
              ),
            );
          }).toList(),
        );
      case 4: // 文件夹：按相对路径目录分组
        final folders = <String, List<LocalVideoItem>>{};
        for (final it in items) {
          final dir = (it.relativePath != null &&
                  it.relativePath!.contains('/'))
              ? it.relativePath!.substring(0, it.relativePath!.lastIndexOf('/'))
              : '根目录';
          folders.putIfAbsent(dir, () => []).add(it);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: folders.entries.map((e) {
            return ListTile(
              leading: const Icon(Icons.folder, color: Colors.amber),
              title: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${e.value.length} 个视频'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<Widget>(
                  builder: (_) => _GroupListPage(
                      title: e.key, items: e.value, state: state),
                ),
              ),
            );
          }).toList(),
        );
      default: // 0 电影 / 1 播放记录
        return items.isEmpty
            ? const Center(child: Text('暂无内容'))
            : _buildBody(items, state);
    }
  }

  /// 根据视图模式渲染
  Widget _buildBody(List<LocalVideoItem> items, LocalVideoState state) {
    switch (_viewMode) {
      case 1:
        return _buildBackdropList(items, state);
      case 2:
        return _buildListView(items, state);
      default:
        return _buildGrid(items, state);
    }
  }

  /// 单列列表视图
  Widget _buildListView(List<LocalVideoItem> items, LocalVideoState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final s = state.scrapedMap[it.pathHash];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 48,
              height: 72,
              child: s?.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.posterUrl(s!.posterPath!),
                      fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, size: 20)),
            ),
          ),
          title: Text(s?.title ?? it.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              [
                if (s?.year != null) '${s!.year}',
                if (it.duration.inMinutes > 0) '${it.duration.inMinutes}分钟',
              ].join(' · '),
              style: const TextStyle(fontSize: 12)),
          onTap: () => _openPlayer(items, i),
          onLongPress: () => _showCardMenu(context, ref, it, s,
              onPlay: () => _openPlayer(items, i)),
        );
      },
    );
  }

  /// 3列竖版海报网格
  Widget _buildGrid(List<LocalVideoItem> items, LocalVideoState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _GridPosterCard(
        item: items[i],
        state: state,
        onPlay: () => _openPlayer(items, i),
      ),
    );
  }

  /// 2列横版 backdrop 卡片
  Widget _buildBackdropList(List<LocalVideoItem> items, LocalVideoState state) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _BackdropCard(
        item: items[i],
        state: state,
        onPlay: () => _openPlayer(items, i),
      ),
    );
  }

  void _openPlayer(List<LocalVideoItem> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute<Widget>(
        builder: (_) => LocalPlayPage(
          items: items,
          initialIndex: index,
        ),
      ),
      // batch53-F2：播放返回后重读续播进度，让"续看/已观看"筛选立即反映最新观看状态
    ).then((_) {
      if (mounted) _loadResumeProgress();
    });
  }
}

/// 竖版海报卡片
class _GridPosterCard extends ConsumerWidget {
  const _GridPosterCard({required this.item, required this.state, this.onPlay});
  final LocalVideoItem item;
  final LocalVideoState state;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<Widget>(
          builder: (_) => LocalDetailPage(item: item, onPlay: onPlay),
        ),
      ),
      onLongPress: () => _showCardMenu(context, ref, item, s, onPlay: onPlay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: s?.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.posterUrl(s!.posterPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(s?.title ?? item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          if (s?.year != null)
            Text('${s!.year}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

void _showCardMenu(
    BuildContext context, WidgetRef ref, LocalVideoItem item, ScrapedMedia? s,
    {VoidCallback? onPlay}) {
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('详情'),
            onTap: () {
              Navigator.pop(context);
              // 透传播放回调，详情页"立即播放/继续观看"才能正常拉起播放器
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          LocalDetailPage(item: item, onPlay: onPlay)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.search, color: Colors.green),
            title: const Text('手动匹配 TMDB 元数据'),
            subtitle: Text(s?.title ?? item.name, maxLines: 1),
            onTap: () async {
              Navigator.pop(context);
              final done = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TmdbSearchPage(
                            initialQuery: s?.title ?? item.name,
                            pathHash: item.pathHash,
                            filename: item.name,
                            videoItem: item,
                          )));
              if (done == true) {
                ref.read(localVideoProvider.notifier).refresh();
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// 横版 backdrop 卡片
class _BackdropCard extends ConsumerWidget {
  const _BackdropCard({required this.item, required this.state, this.onPlay});
  final LocalVideoItem item;
  final LocalVideoState state;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state.scrapedMap[item.pathHash];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<Widget>(
          builder: (_) => LocalDetailPage(item: item, onPlay: onPlay),
        ),
      ),
      onLongPress: () => _showCardMenu(context, ref, item, s, onPlay: onPlay),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: s?.backdropPath != null
                  ? CachedNetworkImage(
                      imageUrl: TmdbService.backdropUrl(s!.backdropPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie,
                          size: 40, color: Colors.white30),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(s?.title ?? item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// 合集/文件夹分组下的视频列表页
class _GroupListPage extends StatelessWidget {
  const _GroupListPage(
      {required this.title, required this.items, required this.state});
  final String title;
  final List<LocalVideoItem> items;
  final LocalVideoState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            Text('${items.length} 个项目',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _GridPosterCard(
          item: items[i],
          state: state,
          onPlay: () => Navigator.push(
            context,
            MaterialPageRoute<Widget>(
              builder: (_) => LocalPlayPage(items: items, initialIndex: i),
            ),
          ),
        ),
      ),
    );
  }
}
