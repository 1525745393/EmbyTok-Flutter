# Emby媒体库类型识别 - Product Requirement Document

## Overview
- **Summary**: 让 Flutter APP 正确识别 Emby 服务器中「家庭视频（Home Videos）」和「照片（Photos）」类型的媒体库，并在视频流页面正确展示对应类型的媒体项（视频/图片）。修复当前无法浏览这些类型媒体库的问题。
- **Purpose**: 用户在 Emby 服务器中创建的家庭视频库和照片库，在 APP 中虽然显示为空白或无法加载内容，用户无法浏览和播放。
- **Target Users**: EmbyTok Flutter APP 使用者，拥有 Emby 服务器的用户

## Goals
- 目标 1：正确识别 Emby 服务器返回的所有 CollectionType 类型（包括 homevideos / photos / movies / tvshows / music / musicvideos 等）
- 目标 2：在视频流页面可正确加载「家庭视频」库中的视频内容
- 目标 3：在视频流页面可正确浏览和展示「照片」库中的图片（全屏图片浏览，取代视频播放器
- 目标 4：媒体库类型在顶部切换器中以中文展示不同类型标签

## Non-Goals (Out of Scope)
- 不开发独立的音乐播放（非目标：音乐库中的音频播放功能不在本次范围中
- 不构建完整的相册浏览（多图相册网格浏览
- 不改变现有的电影/剧集/音乐视频（Movie/Series/MusicVideo)

## Background & Context

### 问题根源
1. **API 层过滤问题：
   - 代码中 `embbytok_service.dart` 的 `getLibraryItems` 方法固定使用 `'IncludeItemTypes': 'Movie,Series,MusicVideo,Episode'`，这导致 `HomeVideo` 和 `Photo` 类型的媒体项被 API 过滤掉
2. **类型映射问题：
   - `Library` 模型的 `type` 字段正确获取 Emby `CollectionType`，但代码中没有使用该信息来选择不同的查询参数
3. **播放适配问题：
   - `VideoPageItem` 和 `VideoPlayerWidget` 均假设所有项都是视频，用 `video_player` 播放，无法处理图片类型项
4. **Emby CollectionType 枚举：
   - `movies` - 电影库，对应 ItemType = Movie
   - `tvshows` - 剧集库，对应 ItemType = Series, Episode
   - `homevideos` - 家庭视频，对应 ItemType = Video / HomeVideo
   - `photos` - 照片库，对应 ItemType = Photo
   - `music` - 音乐，对应 ItemType = Audio / MusicArtist / MusicAlbum
   - `musicvideos` - 音乐视频，对应 ItemType = MusicVideo
   - `mixed` - 混合，对应多种 ItemType
   - `books` - 书籍，对应 ItemType = Book
   - `BoxSets` - 合集

### 当前代码关键位置：
- [library/embbytok_service.dart#L105-L130)：`getLibraryItems` - 硬编码的 `IncludeItemTypes`
- [frontend/lib/models/media_item.dart#L9-L42)：`MediaItem` 模型 - 只处理视频类型，未覆盖 Photo/HomeVideo
- [frontend/lib/widgets/video_page_item.dart#L1-L283)：`VideoPageItem` - 单一视频播放逻辑，不适用于图片
- [frontend/lib/views/feed_view.dart#L77-L139)：`FeedView` - 视频流页面，需要在图片类型检测

## Functional Requirements
- **FR-1**：`Library模型与 Emby `CollectionType` 正确映射，包括 homevideos/photos/movies/tvshows/musicvideos 等
- **FR-2**：`getLibraryItems` 方法接受媒体库类型，动态选择正确的 `IncludeItemTypes` 查询参数
- **FR-3**：`VideoPageItem` 根据 `MediaItem.type` 动态选择渲染方式：视频/图片
- **FR-4**：`MediaItem` 支持 Photo/HomeVideo 类型的 imageTags/imageUrl 解析
- **FR-5**：图片类型媒体库在顶部切换器显示正确的中文标签"家庭视频"、"照片"

## Non-Functional Requirements
- **NFR-1**：性能：图片加载性能，不应出现明显的性能退化（对于视频
- **NFR-2**：可靠性：新图片项不应破坏现有视频播放流程
- **NFR-3**：可维护性：类型映射集中管理，避免硬编码分散在代码各处

## Constraints
- **技术栈**：Flutter (>=3.10.0)、Dart (>=3.0.0)、flutter_riverpod (^2.5.0)、cached_network_image (^3.3.0)、video_player (^2.8.0)
- **API**：直接对接 Emby 原生 `/Library/VirtualFolders` 与 `/Items`
- **依赖**：不引入新的第三方库（Image 类库继续使用现有`

## Assumptions
- 假设 Emby 中 HomeVideos 库中的项类型为 `Video` 或 `HomeVideo`
- 假设 Emby 中 Photos 库中的项类型为 `Photo`
- 假设 Emby `CollectionType` 字段值是小写（homevideos/photos）
- 假设所有媒体项都有 Primary 图片和/或 imageTags 字段

## Acceptance Criteria

### AC-1: 家庭视频库可加载
- **Given**: Emby 服务器中存在一个 CollectionType = "homevideos" 的库
- **When**: 用户在 APP 中选中该库
- **Then**: APP 正确加载该库中的视频项，数量与 Emby Web 客户端一致
- **Verification**: `programmatic`

### AC-2: 照片库可加载
- **Given**: Emby 服务器中存在一个 CollectionType = "photos" 的库
- **When**: 用户在 APP 中选中该库
- **Then**: APP 正确加载该库中的图片项，数量与 Emby Web 客户端一致
- **Verification**: `programmatic`

### AC-3: 照片项全屏展示图片
- **Given**: 用户滑动到一张图片类型的媒体项
- **When**: APP 渲染该图片项页面
- **Then**: 页面以全屏方式显示图片，而不是尝试播放视频
- **Verification**: `programmatic` | `human-judgment`
- **Notes**: 图片应使用 cached_network_image 显示，支持单击可缩放/点击查看
### AC-4: 顶部媒体库标签正确
- **Given**: APP 中显示顶部的媒体库标签
- **When**: 显示该库的类型标签
- **Then**:
  - movies 库显示「电影」
  - tvshows 库显示「剧集」
  - homevideos 库显示「家庭视频」
  - photos 库显示「照片」
  - musicvideos 库显示「音乐视频」
  - music 库显示「音乐」
  - mixed 库显示「混合」
  - 未知类型显示库名本身
- **Verification**: `programmatic` | `human-judgment`

### AC-5: 不破坏原有视频播放功能
- **Given**: 用户打开电影/剧集/音乐视频项
- **When**: APP 加载并播放这些视频项
- **Then**: 原有播放行为不变
- **Verification**: `programmatic`

### AC-6: 照片的收藏/静音/字幕交互项依然使用方法
- **Given**: 电影/剧集/音乐视频依然可以被加到收藏夹
- **When**: 图片项也能被标记为收藏，但由于 Emby 收藏 API 通用
- **Then**: 收藏功能对所有类型项都能正常工作
- **Verification**: `programmatic`

## Open Questions
- [ ] 家庭视频库中的项，Emby 返回的 `Type` 字段具体为何值？（Video 或 HomeVideo 或 Movie？）
- [ ] 照片库中的项在 `MediaSources` 字段是否为空？
- [ ] 图片项是否支持通过 `/Videos/{id}/stream` 播放路径？
