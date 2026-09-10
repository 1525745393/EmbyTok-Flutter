# EmbyTok - 性能优化指南

> 本文件目标：为开发者提供项目的性能优化指南，包括性能指标、优化策略、常用工具和最佳实践。
>
> **相关源码**：`frontend/lib/`

---

## 一、性能指标

### 1.1 核心性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| **启动时间** | < 2 秒 | 从点击图标到首页可交互 |
| **页面切换** | < 300ms | 页面路由切换动画流畅 |
| **列表滚动** | 60 FPS | 长列表滚动无卡顿 |
| **视频播放** | 60 FPS | 视频播放和控制条动画流畅 |
| **内存占用** | < 200MB | 正常使用时的内存峰值 |
| **API 响应** | < 500ms | 本地网络 API 响应时间 |
| **图片加载** | < 300ms | 封面图从缓存加载时间 |

### 1.2 性能预算

| 资源类型 | 预算 | 说明 |
|----------|------|------|
| 单页 Widget 数量 | < 100 | 避免 Widget 树过深 |
| 单文件行数 | < 500 | 超过则考虑拆分（P1-1） |
| 单 build 方法行数 | < 100 | 超过则考虑提取子组件（P1-2） |
| 图片缓存大小 | < 100MB | AppImageCacheManager 配置 |
| 单次 API 请求数据量 | < 1MB | 分页加载，避免一次性加载过多 |

---

## 二、已实施的性能优化

### 2.1 P2-2：coverUrl 缓存

**问题**：横向列表中每个专辑/歌手卡片都在 itemBuilder 中计算 coverUrl，导致重复计算。

**优化**：
- 在模型层（AudioAlbum/AudioArtist）新增 `coverUrl` 字段
- API 层（getAlbums/getArtists）返回前预计算 coverUrl
- UI 层直接使用 `item.coverUrl`，移除 itemBuilder 中的重复计算

**效果**：横向列表滚动时减少重复计算，提升滚动流畅度。

### 2.2 P1-1：大文件拆分

**问题**：`synology_music_view.dart` 达到 3166 行，build 方法过长，Widget 树复杂。

**优化**：
- 拆分为 6 个独立文件（equalizer_bars、artist_detail_sheet、music_cover_widgets、mini_player_bar、home_widgets、horizontal_lists）
- 主文件减少到约 1765 行（减少 44%）
- 私有类改为公开类，提升可复用性

**效果**：代码可维护性提升，热重载速度加快，Widget 重建范围缩小。

### 2.3 P2-3：文件组织优化

**问题**：视频相关组件散落在 widgets/ 根目录，与通用组件混合。

**优化**：
- 新增 `widgets/video/` 子目录，移动 11 个视频专用组件
- 新增 barrel 文件（widgets.dart、video/video.dart）
- 更新 50+ 处 import 路径

**效果**：项目结构更清晰，编译时依赖分析更高效。

### 2.4 OOM 修复：非当前页不创建视频控制器

**问题**：PageView 中所有页面都创建视频控制器，导致内存占用过高，低端设备 OOM。

**优化**：
- 只有当前可见页面才创建 VideoPlayerController
- 页面不可见时释放控制器资源
- 使用 `AutomaticKeepAliveClientMixin` 控制页面保活

**效果**：内存占用降低约 60%，OOM 崩溃率显著下降。

### 2.5 图片缓存优化

**问题**：封面图重复下载，占用网络带宽和内存。

**优化**：
- 使用 `AppImageCacheManager`（基于 flutter_cache_manager）
- 缩略图和原图使用不同的缓存目录
- 设置合理的缓存大小限制和过期策略
- 使用 `CachedNetworkImage` 的 `memCacheWidth`/`memCacheHeight` 减少内存占用

**效果**：图片加载速度提升，网络请求减少，内存占用可控。

---

## 三、性能优化策略

### 3.1 Widget 重建优化

**原则**：最小化 Widget 重建范围。

**策略**：
1. **使用 Consumer/Selector**：Riverpod 中使用 `Selector` 只监听需要的状态
2. **提取子组件**：将 build 方法中的复杂部分提取为独立 Widget
3. **使用 const 构造函数**：无状态变化的 Widget 使用 const
4. **避免在 build 中创建对象**：将对象创建移到 initState 或外部
5. **使用 RepaintBoundary**：独立重绘的区域使用 RepaintBoundary 隔离

**示例**：
```dart
// ❌ 不好：整个页面重建
class MusicPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicProvider);
    return Column(
      children: [
        Header(state: state),  // 每次 state 变化都重建
        Playlist(state: state),
        PlayerBar(state: state),
      ],
    );
  }
}

// ✅ 好：使用 Selector 精确监听
class MusicPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Header(),  // 内部使用 Selector 只监听需要的状态
        Playlist(),
        PlayerBar(),
      ],
    );
  }
}
```

### 3.2 列表优化

**原则**：长列表使用懒加载，避免一次性渲染所有项。

**策略**：
1. **使用 ListView.builder**：自动懒加载，只渲染可见区域
2. **设置 itemExtent**：固定高度的列表使用 itemExtent 提升性能
3. **使用 AutomaticKeepAlive**：需要保活的页面使用 AutomaticKeepAliveClientMixin
4. **分页加载**：API 数据分页加载，配合 ScrollController 实现无限滚动
5. **缓存封面图**：使用 CachedNetworkImage 缓存图片
6. **避免在 itemBuilder 中做复杂计算**：预计算或使用 memoization

**示例**：
```dart
ListView.builder(
  controller: _scrollController,
  itemCount: songs.length + 1,  // +1 for loading indicator
  itemBuilder: (context, index) {
    if (index == songs.length) {
      return const LoadingIndicator();
    }
    final song = songs[index];
    return SongTile(song: song);  // 提取为独立 Widget
  },
)
```

### 3.3 内存优化

**原则**：及时释放不再使用的资源，避免内存泄漏。

**策略**：
1. **dispose 中释放资源**：Controller、StreamSubscription、AnimationController 等
2. **避免全局单例持有大对象**：使用 Provider 管理生命周期
3. **图片缓存限制**：设置合理的缓存大小
4. **列表滚动时暂停非关键任务**：如图片预加载、数据同步
5. **使用 WeakReference**：不需要强引用的对象使用弱引用
6. **监控内存压力**：使用 memory_pressure_handler 响应系统内存警告

**示例**：
```dart
class _PlayerPageState extends State<PlayerPage> {
  late final VideoPlayerController _controller;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(url);
    _positionSubscription = _controller.position.listen(_onPosition);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();  // 取消订阅
    _controller.dispose();  // 释放控制器
    super.dispose();
  }
}
```

### 3.4 网络优化

**原则**：减少网络请求，提升响应速度。

**策略**：
1. **使用缓存**：GET 请求结果缓存，避免重复请求
2. **请求合并**：多个小请求合并为一个批量请求
3. **分页加载**：大数据量分页加载
4. **压缩传输**：启用 gzip 压缩
5. **预加载**：提前加载下一页数据
6. **超时控制**：设置合理的连接超时和读取超时
7. **重试机制**：网络错误时自动重试（指数退避）

**示例**：
```dart
class ApiClient {
  final Map<String, dynamic> _cache = {};

  Future<T> getWithCache<T>(String key, Future<T> Function() fetcher) async {
    if (_cache.containsKey(key)) {
      return _cache[key] as T;
    }
    final result = await fetcher();
    _cache[key] = result;
    return result;
  }
}
```

---

## 四、性能监控工具

### 4.1 Flutter 性能工具

| 工具 | 用途 | 命令 |
|------|------|------|
| **Flutter DevTools** | 性能分析、内存分析、Widget 检查 | `flutter pub global run devtools` |
| **flutter performance** | 性能监控 | `flutter run --profile` |
| **flutter trace** | 方法追踪 | `flutter run --trace-startup` |
| **Memory View** | 内存分析 | DevTools → Memory |
| **CPU Profiler** | CPU 分析 | DevTools → CPU Profiler |
| **Network View** | 网络请求分析 | DevTools → Network |

### 4.2 常用命令

```bash
# 运行性能模式（关闭调试断言，接近发布性能）
flutter run --profile

# 启动性能追踪
flutter run --trace-startup --profile

# 分析应用大小
flutter build apk --analyze-size

# 查看内存使用
flutter pub global run devtools

# 代码尺寸分析
flutter build apk --release --extra-gen-snapshot-options=--print_instructions_sizes_to=output.json
```

### 4.3 自定义性能监控

项目中可添加自定义性能监控：

```dart
class PerformanceMonitor {
  static final List<PerformanceMetric> _metrics = [];

  static void track(String name, Duration duration) {
    _metrics.add(PerformanceMetric(name: name, duration: duration));
    if (kDebugMode) {
      debugPrint('[$name] ${duration.inMilliseconds}ms');
    }
  }

  static void trackBuild(String widgetName) {
    // 监控 Widget build 耗时
  }

  static void trackFrame() {
    // 监控帧率
  }
}
```

---

## 五、性能优化检查清单

### 5.1 代码审查时检查

- [ ] build 方法中是否有复杂计算？
- [ ] 是否在 build 中创建了不需要每次重建的对象？
- [ ] 长列表是否使用了 ListView.builder？
- [ ] 图片是否使用了缓存？
- [ ] Controller/Subscription 是否在 dispose 中释放？
- [ ] 是否有不必要的 setState 调用？
- [ ] 是否使用了 const 构造函数？
- [ ] API 请求是否有缓存？
- [ ] 大数据量是否分页加载？

### 5.2 发布前检查

- [ ] 启动时间 < 2 秒
- [ ] 列表滚动 60 FPS
- [ ] 视频播放 60 FPS
- [ ] 内存占用 < 200MB
- [ ] 无内存泄漏（DevTools Memory 检查）
- [ ] 无过度重建（DevTools Widget Inspector 检查）
- [ ] API 响应时间 < 500ms
- [ ] 图片加载 < 300ms
- [ ] 低端设备无 OOM 崩溃

---

## 六、常见性能问题与解决方案

### 6.1 列表卡顿

**症状**：长列表滚动时掉帧。

**解决方案**：
1. 使用 `ListView.builder` 替代 `ListView(children: [...])`
2. 提取列表项为独立 Widget
3. 固定高度的列表使用 `itemExtent`
4. 图片使用 `CachedNetworkImage` 并设置 `memCacheWidth`
5. 避免在 `itemBuilder` 中做复杂计算

### 6.2 内存泄漏

**症状**：长时间使用后内存持续增长，应用卡顿或崩溃。

**解决方案**：
1. 检查 `dispose` 中是否释放了所有 Controller/Subscription
2. 使用 DevTools Memory 分析内存快照
3. 避免全局单例持有大对象
4. 图片缓存设置合理的大小限制
5. 使用 `WeakReference` 避免循环引用

### 6.3 启动慢

**症状**：从点击图标到首页可交互时间过长。

**解决方案**：
1. 延迟初始化非关键模块
2. 使用 `flutter_native_splash` 添加启动屏
3. 减少 main 函数中的同步操作
4. 预加载关键数据
5. 使用代码混淆和压缩（发布模式自动启用）

### 6.4 图片加载慢

**症状**：封面图显示空白或加载缓慢。

**解决方案**：
1. 使用 `CachedNetworkImage` 缓存图片
2. 缩略图和原图分开缓存
3. 设置合理的缓存大小和过期时间
4. 使用占位图和淡入动画
5. 预加载下一页的图片

---

*文档版本：v1.0 | 最后更新：2026-09-11*
