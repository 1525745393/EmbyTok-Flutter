# Emby媒体库类型识别 - 验证清单

## 数据层验证
- [ ] Checkpoint 1: `Library.fromJson` 能够正确解析 Emby 原生 `CollectionType` 字段（homevideos/photos/movies/tvshows 等），并将其保存到 `type` 字段
- [ ] Checkpoint 2: 不存在 `CollectionType` 字段时，`Library.type` 回退为 `'mixed'` 或 `'movies'`，不为空字符串
- [ ] Checkpoint 3: `Library.isPhotoLibrary` / `Library.isVideoLibrary` 返回正确的 bool 值，且对 photos / homevideos / movies / tvshows / musicvideos 类型返回正确值
- [ ] Checkpoint 4: `libraryCollectionTypeToIncludeItemTypes` 映射表覆盖所有主要类型，其中 photos 返回 `"Photo"`，homevideos 返回 `"Video,Movie,HomeVideo,Episode"`
- [ ] Checkpoint 5: `libraryCollectionTypeDisplayLabel` 能正确返回中文标签：homevideos→"家庭视频"，photos→"照片"，movies→"电影"，tvshows→"剧集"，music→"音乐"，musicvideos→"音乐视频"，mixed→"混合"

## API 服务层验证
- [ ] Checkpoint 6: `getLibraryItems(libId, libraryType: 'homevideos')` 调用时，请求 `/Items` 的 `IncludeItemTypes` 参数包含视频类型（不包含 Photo）
- [ ] Checkpoint 7: `getLibraryItems(libId, libraryType: 'photos')` 调用时，请求 `/Items` 的 `IncludeItemTypes` 参数为 `"Photo"`
- [ ] Checkpoint 8: `getLibraryItems(libId)` 不带 libraryType 参数时，请求参数保持原有默认 `Movie,Series,MusicVideo,Episode`，向后兼容
- [ ] Checkpoint 9: `getLibraries` 返回的库列表中，每一个库的 type 字段都有有效值，没有因缺字段导致的 null 或空值

## 模型层验证
- [ ] Checkpoint 10: `MediaItem.fromJson` 对 `Type` 字段为 `"Photo"` / `"HomeVideo"` / `"Video"` 的项正确解析，`item.type` 等于对应值
- [ ] Checkpoint 11: `MediaItem.isPhoto == true` 当 `type` 为 `Photo`
- [ ] Checkpoint 12: `MediaItem.isVideo == true` 当 `type` 为 `Movie/Series/Episode/MusicVideo/HomeVideo/Video`
- [ ] Checkpoint 13: Photo 类型的 `MediaItem.computePlaybackUrl(serverUrl, token)` 返回 `null`（不构造视频流 URL）
- [ ] Checkpoint 14: Photo 类型的 `MediaItem.primaryUrl(...)` / `imageUrl(...)` 能正确构造图片 URL（包含 api_key 参数）

## UI 层验证
- [ ] Checkpoint 15: `VideoPageItem` 对 Photo 类型的 item 使用图片渲染（cached_network_image 或 Image.network），不创建 VideoPlayerController
- [ ] Checkpoint 16: `VideoPageItem` 对 Video 类型的 item 继续走原有视频播放路径，创建 VideoPlayerController
- [ ] Checkpoint 17: 顶部媒体库切换器正确显示各种类型库的名称，点击时正确更新 selectedLibraryIdProvider 并触发 videoListProvider refresh
- [ ] Checkpoint 18: 选择照片库后，FeedView 页面加载并展示图片项列表，不再显示"暂无视频"
- [ ] Checkpoint 19: 选择家庭视频库后，FeedView 页面加载并展示视频项列表

## Provider 层验证
- [ ] Checkpoint 20: `VideoListNotifier.refresh(libraryId)` 能根据 libraryId 在 libraries 列表中找到对应 library，并正确传递 libraryType
- [ ] Checkpoint 21: `VideoListNotifier.loadMore()` 同样使用正确的 libraryType
- [ ] Checkpoint 22: `selectedLibraryIdProvider` 在切换库时状态正确更新

## 回归验证
- [ ] Checkpoint 23: 原有的电影/剧集/音乐视频项的视频播放功能未受影响（VideoPlayerWidget 仍正常初始化、播放、停止）
- [ ] Checkpoint 24: 搜索功能（searchItems/searchHints）未受修改影响，返回结果与之前一致
- [ ] Checkpoint 25: 收藏功能（toggleFavorite）对照片类型也能正常工作
- [ ] Checkpoint 26: `flutter test` 现有测试全部通过

## 静态分析验证
- [ ] Checkpoint 27: `dart analyze` / `flutter analyze` 无严重错误或警告
- [ ] Checkpoint 28: 代码中不再有 `IncludeItemTypes: 'Movie,Series,MusicVideo,Episode'` 的硬编码（除默认值外），而是通过映射表动态生成
- [ ] Checkpoint 29: 所有新增代码均已添加简明的中文注释，说明关键逻辑

## 代码组织验证
- [ ] Checkpoint 30: 类型映射常量集中在 `constants.dart` 或 `models/library.dart` 的一个位置，没有在多处硬编码
- [ ] Checkpoint 31: Photo 类型的渲染逻辑通过独立的 Widget（如 `PhotoPageItem`）实现，不与 `VideoPageItem` 的视频逻辑重度耦合
