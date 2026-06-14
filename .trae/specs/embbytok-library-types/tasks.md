# Emby媒体库类型识别 - 实施计划 (Decomposed and Prioritized Task List)

## [x] Task 1: 建立媒体库类型与Emby CollectionType映射常量
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `utils/` 或 `models/` 中创建集中的类型映射常量：
    - Emby CollectionType → 内部类型标识（string enum 映射）
    - Emby CollectionType → IncludeItemTypes （用于 API 查询参数）
    - 内部类型标识 → 中文标签（用于 UI 展示）
  - 在 `Library` 模型中增加计算属性：如 `isVideoLibrary`, `isPhotoLibrary`, `displayTypeName`
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-4
- **Test Requirements**:
  - `programmatic` TR-1.1: `libraryCollectionTypeMap` 覆盖 homevideos/photos/movies/tvshows/musicvideos/music/mixed
  - `programmatic` TR-1.2: `includeItemTypesForLibraryType(homevideos)` 返回包含 `Video,Movie,HomeVideo,Episode` 的字符串
  - `programmatic` TR-1.3: `includeItemTypesForLibraryType(photos)` 返回包含 `Photo` 的字符串
  - `programmatic` TR-1.4: `includeItemTypesForLibraryType(movies)` 返回包含 `Movie,Series,MusicVideo,Episode` 的字符串（向后兼容）
  - `programmatic` TR-1.5: `libraryDisplayTypeName(homevideos)` 返回 "家庭视频"，`photos` 返回 "照片"
- **Notes**: 新增文件推荐路径 `frontend/lib/utils/constants.dart`（如果已有该文件则补充其内容）

## [x] Task 2: 修改 getLibraryItems 支持动态 IncludeItemTypes
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 修改 `EmbytokService.getLibraryItems` 增加可选参数 `String? libraryType`
  - 当 `libraryType` 非空时，根据 Task 1 的映射表查询出正确的 `IncludeItemTypes` 值
  - 当 `libraryType` 为空时，保留当前的 `Movie,Series,MusicVideo,Episode` 默认值，确保向后兼容
  - 修改 `VideoListNotifier.refresh` 和 `VideoListNotifier.loadMore` 以传递媒体库类型
  - 需要能够从已缓存的 library 列表中查询 libraryId 对应 Library 的 type
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-5
- **Test Requirements**:
  - `programmatic` TR-2.1: 调用 `getLibraryItems(libId, libraryType: 'homevideos')` 时，请求 query 参数 `IncludeItemTypes` 包含视频类型（不含 Photo）
  - `programmatic` TR-2.2: 调用 `getLibraryItems(libId, libraryType: 'photos')` 时，请求 query 参数 `IncludeItemTypes` 等于 `Photo`
  - `programmatic` TR-2.3: 不传 `libraryType` 时，请求 query 参数 `IncludeItemTypes` 保持为 `Movie,Series,MusicVideo,Episode`
  - `programmatic` TR-2.4: `videoListProvider.refresh(libraryId)` 调用时会根据 libraryId 正确传递 libraryType 到服务层
- **Notes**: 不要破坏现有未传 libraryType 的调用路径；确保 search/searchHints 等其他 API 调用不受影响

## [x] Task 3: Library模型补充与正确解析 Emby CollectionType
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 强化 `Library.fromJson` 解析：确保同时支持 Emby 原生字段（Name, Id, CollectionType）和 snake_case（name, id, type）
  - `Library` 增加 `isVideoLibrary`, `isPhotoLibrary`, `displayTypeName` 等便捷属性
  - `getLibraries` 在获取 library 列表时，若某个 Library 没有 CollectionType，则用 `'mixed'` 作为回退值
- **Acceptance Criteria Addressed**: AC-1, AC-2, AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: `Library.fromJson({'Id': 'x', 'Name': 'Videos', 'CollectionType': 'homevideos'})` 返回的 `type == 'homevideos'`
  - `programmatic` TR-3.2: `Library.fromJson({'Id': 'x', 'Name': 'Photos', 'CollectionType': 'photos'})` 返回的 `type == 'photos'`
  - `programmatic` TR-3.3: 缺失 CollectionType 时，`type == 'mixed'` 或 `'movies'`（确保不会为空）
  - `programmatic` TR-3.4: `library.isPhotoLibrary == true` 当 type 为 photos
  - `programmatic` TR-3.5: `library.isVideoLibrary == true` 当 type 为 homevideos/movies/tvshows/musicvideos

## [x] Task 4: MediaItem类型识别与 Photo/HomeVideo 类型支持
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 确认 `MediaItem.fromJson` 对 `Type` 字段能正确解析 Photo/HomeVideo 类型（现在的默认值是 'Movie'，需要更合适的默认值或直接使用返回值）
  - `MediaItem` 增加 `isVideo` 和 `isPhoto` 的便捷判断属性
  - `computePlaybackUrl` 在 Photo 类型时返回 null，避免错误构造视频 URL
- **Acceptance Criteria Addressed**: AC-3, AC-5
- **Test Requirements**:
  - `programmatic` TR-4.1: `MediaItem.fromJson({'Id': 'x', 'Name': 'pic', 'Type': 'Photo'})` 的 `type == 'Photo'`
  - `programmatic` TR-4.2: `item.isPhoto == true` 当 type 为 Photo
  - `programmatic` TR-4.3: `item.isVideo == true` 当 type 为 Movie/Series/Episode/MusicVideo/HomeVideo/Video
  - `programmatic` TR-4.4: Photo 类型的 `computePlaybackUrl(url, token)` 返回 null
- **Notes**: 不要改变 video 类型解析，保持兼容

## [x] Task 5: VideoPageItem支持图片类型渲染分支
- **Priority**: P0
- **Depends On**: Task 4
- **Description**:
  - `VideoPageItem` 中在 build 前判断 `widget.item.type`：
    - 若是 Photo 类型 → 使用 `cached_network_image` 以全屏方式渲染图片，无视频播放逻辑
    - 若是其他（视频）类型 → 走原有 `VideoPlayerWidget` 逻辑
  - 图片页面支持单击/双击操作（手势复用 GestureOverlay 的一部分但只用于简单交互）
  - 右下角操作按钮简化：收藏、信息、静音按钮可保留但静音按钮对图片项隐藏
- **Acceptance Criteria Addressed**: AC-3, AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: Photo 类型 item 进入 VideoPageItem 时，不创建 VideoPlayerController
  - `programmatic` TR-5.2: Photo 类型 item 渲染的 Widget 中存在 Image/cached_network_image
  - `human-judgement` TR-5.3: 图片展示在设备上为全屏居中显示，无加载视频时的黑色空白页面
  - `programmatic` TR-5.4: Movie 类型 item 仍然走原有视频播放路径（通过代码审查验证）
- **Notes**: 可将图片渲染抽取为独立 `PhotoPageItem` Widget，便于维护

## [x] Task 6: 顶部媒体库切换器的中文标签与用户反馈
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - `FeedView` 的顶部 chip 或展示库名（默认行为已存在），补充库类型图标或小标记以表明该库的类型（可选）
  - 空状态文案适配：图片库显示"暂无图片"；视频库显示"暂无视频"
- **Acceptance Criteria Addressed**: AC-4, AC-5
- **Test Requirements**:
  - `programmatic` TR-6.1: FeedView 中 library 列表正确渲染，所选 library 的 type 正确传递给下层
  - `human-judgement` TR-6.2: 空状态文案根据 library 类型展示
- **Notes**: 主要确保类型数据能从 LibraryProvider 一路传递到 VideoPageItem/FeedView

## [x] Task 7: 全面代码审查与回归测试
- **Priority**: P1
- **Depends On**: Task 2, Task 3, Task 4, Task 5
- **Description**:
  - 检查 `getLibraries` 是否还有硬编码的类型名
  - 检查是否有其他地方对 `library.type` 做了不完整的判断
  - 确认 search 功能不被修改影响（搜索依然返回混合类型结果
  - 运行所有现有单元测试，确保无回归
- **Acceptance Criteria Addressed**: AC-5, AC-6
- **Test Requirements**:
  - `programmatic` TR-7.1: `flutter test` 全部通过
  - `programmatic` TR-7.2: 静态分析 `dart analyze` 无严重问题
  - `human-judgement` TR-7.3: 代码审查通过，无明显坏味道
