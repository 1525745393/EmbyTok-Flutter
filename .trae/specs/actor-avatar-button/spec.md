# 演员头像按钮（TikTok 风格） - Product Requirement Document

## Overview

- **Summary**: 将视频播放页右侧的"圆形海报头像"重构为演员头像按钮（类似 TikTok 的创作者头像），显示主要演员头像，点击头像进入该演员的全部影片页面，点击"+"按钮收藏/取消收藏演员。
- **Purpose**: 提供更强的内容发现体验，让用户可以通过演员发现更多相关视频，并通过收藏功能跟踪喜欢的演员。
- **Target Users**: EmbyTok Flutter 版用户，尤其是习惯 TikTok 风格交互的用户。

## Goals

- **Goal 1**: 显示主要演员头像，替代当前的视频海报封面
- **Goal 2**: 点击头像跳转到演员详情页（PersonDetailView），显示该演员的所有影片
- **Goal 3**: 添加 TikTok 风格的"+"按钮用于收藏/取消收藏演员
- **Goal 4**: 收藏后"+"按钮变为"✓"或消失，提供清晰的状态反馈

## Non-Goals (Out of Scope)

- 不修改播放/暂停功能（改由其他按钮或手势触发）
- 不实现演员滚动切换（只显示第一个/主要演员）
- 不修改视频播放核心逻辑
- 不修改底部信息面板

## Background & Context

### 当前实现
- `_buildPosterAvatar()` 位于 `video_page_item.dart` 第 965-999 行
- 显示视频封面图（`widget.item.imageUrl('Primary', ...)`）
- 点击触发 `_togglePlay()` 播放/暂停
- 大小 48x48 像素，圆形边框

### 现有基础设施
- `MediaItem.people` 字段：`List<Person>?` - 包含影片的演员/导演/编剧等
- `Person` 模型：`name`, `id`, `role`, `type`, `imageUrl`
- `PersonDetailView`：已存在，展示演员头像 + 出演作品列表
- `FavoritesState.people`：已存在的人物收藏列表
- `FavoritesNotifier`：已有 `toggleFavorite(MediaItem)` 方法
- `EmbytokService.getFavoritePeople()`：已有服务方法

### TikTok 参考布局
```
[ 圆形演员头像 ]   ← 56px
    [ + ]          ← 悬浮在头像底部中心，青色圆形按钮
                     收藏后变为 ✓ 或隐藏（动画效果）
[演员名字]         ← 可选，显示在头像下方
```

## Functional Requirements

- **FR-1: 演员头像显示** - 在右侧操作栏顶部显示主要演员（Actor 类型）的头像。优先取 `people` 列表中 `type == 'Actor'` 的第一个。如果没有演员，回退显示视频封面图。
- **FR-2: 演员头像可点击** - 点击演员头像跳转到 `PersonDetailView`，显示该演员的详细信息和出演的所有影片。
- **FR-3: 收藏按钮（+）** - 在头像右下角添加 TikTok 风格的"+"圆形按钮。点击切换该演员的收藏状态。已收藏状态显示"✓"或动画缩小消失。
- **FR-4: 演员名字显示** - 在头像下方显示演员名字（可选，小字体）。如果没有演员信息，不显示名字。
- **FR-5: 状态同步** - 收藏状态与 `FavoritesProvider` 同步，确保在其他页面（如收藏页）也能看到更新后的状态。

## Non-Functional Requirements

- **NFR-1**: 头像大小约 56x56px，"+"按钮约 20-24px
- **NFR-2**: 不引入新的包或依赖
- **NFR-3**: 状态管理复用现有 `favoritesProvider`
- **NFR-4**: 交互响应迅速，点击反馈 < 100ms
- **NFR-5**: 纯净模式下右侧按钮区仍正常显示（不隐藏演员头像）

## Constraints

- **Technical**: Flutter / Dart，基于 Riverpod 状态管理
- **Data**: 依赖 `widget.item.people` 是否包含演员信息
- **Navigation**: 使用 `Navigator.push` 到 `PersonDetailView`
- **PersonDetailView 需要 MediaItem 类型**：需要将 Person 转换为 MediaItem 或修改 PersonDetailView

## Assumptions

- 至少有一个演员信息可用（`people` 列表非空）
- 如果没有演员信息，回退显示视频封面图，保留播放/暂停功能
- `Person` 对象的 `id` 字段非空，可用于导航和收藏
- 演员头像 URL 需要通过 Emby API 方式构建（类似 MediaItem）

## Acceptance Criteria

### AC-1: 演员头像显示
- **Given**: 用户正在观看视频，视频有演员信息
- **When**: 页面加载完成
- **Then**: 右侧操作栏顶部显示主要演员的头像（圆形）
- **Verification**: `human-judgment`
- **Notes**: 如果没有演员信息，回退显示视频封面图

### AC-2: 点击头像跳转演员详情页
- **Given**: 用户看到演员头像
- **When**: 用户点击头像
- **Then**: 导航到 `PersonDetailView`，显示该演员的所有影片
- **Verification**: `human-judgment`

### AC-3: 收藏按钮（+）
- **Given**: 用户看到演员头像
- **When**: 用户点击头像右下角的"+"按钮
- **Then**: 演员被添加到收藏，"+"按钮变为"✓"或动画消失
- **Verification**: `human-judgment`

### AC-4: 取消收藏
- **Given**: 演员已被收藏，显示"✓"
- **When**: 用户再次点击"✓"按钮
- **Then**: 演员从收藏中移除，按钮变回"+"
- **Verification**: `human-judgment`

### AC-5: 无演员信息的回退
- **Given**: 视频没有演员信息（`people` 为空或全为非 Actor 类型）
- **When**: 页面加载完成
- **Then**: 显示视频封面图，点击可播放/暂停（保留原有行为）
- **Verification**: `human-judgment`

### AC-6: 演员名字显示
- **Given**: 有演员信息
- **Then**: 在头像下方显示演员名字（可选小字体显示在按钮区外部或内部）
- **Verification**: `human-judgment`

### AC-7: 状态同步
- **Given**: 用户收藏了某个演员
- **When**: 用户导航到收藏页的"人物"标签
- **Then**: 能看到刚刚收藏的演员
- **Verification**: `human-judgment`

## Open Questions

- [ ] **Q1**: 演员名字显示位置？在头像下方还是作为 Tooltip 显示？（建议：头像下方显示 2-3 个字符的短名，或用 Tooltip 显示全名）
- [ ] **Q2**: 只显示第一个演员还是显示多个（可滚动）？（建议：只显示第一个主要演员，简单实现）
- [ ] **Q3**: Person 到 MediaItem 的转换：`PersonDetailView` 需要 `MediaItem`，但我们只有 `Person` 对象。需要添加转换逻辑或修改导航方式？
- [ ] **Q4**: 收藏演员时需要构造 `MediaItem` 用于 `toggleFavorite`，还是新增一个 `toggleFavoritePerson` 方法？
