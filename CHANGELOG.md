# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范。

---

## [1.4.0] - 2026-06-15

### 新增

- **三栏收藏页面**：按类型展示「收藏影片」「收藏合集」「收藏人物」三个横向滚动卡片列表，与 Emby 官方 App 风格一致
- **合集详情页**：海报 + 简介 + 包含的影片列表，点击跳转到播放页
- **人员作品页**：头像 + 简介 + 出演作品列表，点击跳转到播放页

### 改进

- `EmbytokService` 新增 `getFavoriteMovies` / `getFavoriteBoxSets` / `getFavoritePeople` 三个方法，按 `IncludeItemTypes` 精准过滤收藏数据
- `favorites_provider.dart` 重构：`FavoritesState` 支持三组独立列表，`Future.wait` 并行加载；合并的 `favoriteIds` Set 供视频页快速判断收藏状态
- 保留双击切换收藏 + 红心动画交互，乐观更新 UI + 失败回滚

### 修复

- 收藏状态跨账号隔离：登出时清空缓存，新账号登录后自动拉取自己的收藏数据

---

## [1.3.3] - 2026-06-15

### 新增

- **收藏功能**：双击视频画面即可收藏/取消收藏，伴随红心动画（放大淡出 700ms）
- **我的收藏页**：独立的收藏列表视图，显示收藏的视频卡片、类型标签、时长、简介
- **右侧操作按钮**：点赞（心形图标）+ 收藏（星形图标）按钮，点击有缩放动画，状态与 `favoritesProvider` 响应式同步
- **手势交互层**：单击播放/暂停、双击收藏、长按 2x 倍速、水平拖动快进/快退（300ms 区分单/双击，400ms 双击防抖防重复请求）

### 改进

- `favorites_provider.dart`：重构为完整的 `StateNotifier` 状态管理器
  - 自动监听 `authProvider`：登录后自动拉取收藏，登出/切换账号自动清理缓存
  - `_pendingToggles` 去重：同一 item 并发点击只发送一次网络请求
  - 乐观更新 + 失败回滚：UI 即时反馈 + 数据最终一致
  - `ensureLoaded()` / `reset()` 幂等辅助方法
- `video_page_item.dart`：`favorited` 状态改为 `ref.watch(favoritesProvider)` 响应式读取，任何来源的状态变化都立即反映到 UI

### 修复

- **CI - 导入路径错误**：`favorites_view.dart` 中 `import 'video_page_item.dart'` → `import '../widgets/video_page_item.dart'`（`uri_does_not_exist` / `undefined_method: VideoPageItem`）
- **CI - API 名称**：`gesture_overlay.dart` 中 `setPlaybackRate` 改为 `video_player` 包正确方法 `setPlaybackSpeed`（2 处 `undefined_method`）

---

## [1.3.2] - 2026-06-15

### 修复

- `Color.withValues` 兼容性问题：Flutter 3.22+ 特有 API 在 CI 环境中导致 `undefined_method` 编译错误，已替换为稳定的 `Color.withOpacity()` API
- `_parsePaginatedResponse` 方法类型安全增强：空列表字面量 `const []` 改为 `const <MediaItem>[]`，明确泛型类型避免类型推断歧义
- `library_provider.dart` Provider 声明顺序优化：将 `libraryListProvider` 移到文件顶部，`selectedLibraryIdProvider` / `selectedLibraryProvider` 放在底部，使依赖声明顺序更清晰

### 改进

- `top_tool_bar.dart` 移除未使用的 `import 'package:flutter_riverpod/flutter_riverpod.dart'`（如适用）
- `embbytok_service.dart` 添加显式泛型类型参数，提升强类型一致性

---

## [1.3.1] - 2026-06-15

### 修复

- Flutter 静态分析错误：`VideoPlayerWidget.createState` 返回类型改为 `ConsumerState<VideoPlayerWidget>`
- `providers.dart` 添加 `app_preferences_providers` 导出，修复 `viewModeProvider` / `feedTypeProvider` / `orientationModeProvider` 未定义问题
- `FullscreenCallback` 类型匹配修复
- 移除 `feed_view.dart` 中未使用的 `_selectLibrary` 方法和 `_buildLibraryChips` 元素
- 移除 `top_tool_bar.dart` 中未使用的 `FeedType` 导入

---

## [1.3.0] - 2026-06-15

### 新增

- **视频流 / 网格视图切换**：顶部工具栏一键切换视频流与网格浏览模式
- **方向过滤**：支持只看竖屏 / 只看横屏 / 全部三种过滤模式
- **全屏播放模式**：横屏旋转 + 隐藏系统 UI 的沉浸式观看体验
- **视频方向自适应**：横屏视频以 `BoxFit.contain` + 海报背景显示，竖屏视频以 `BoxFit.cover` 全屏填充
- **网格视图卡片**：显示封面图、标题、时长和播放进度条

### 修改

- `TopToolBar` 顶部工具栏新增方向过滤、视图切换、全屏、静音按钮
- `VideoGridView` 网格视图支持 2 列（竖屏）/ 4 列（横屏）自适应布局
- `FeedView` 添加视图模式切换和 `filteredVideoListProvider` 过滤列表支持
- `MediaItem` / `MediaSource` 模型添加 `isLandscape` / `isPortrait` 方向判断属性
- `video_list_provider.dart` 新增 `filteredVideoListProvider` 派生 provider，基于 `OrientationMode` 对视频列表进行实时过滤
- `video_player_widget.dart` 实现 `_buildVideoWithAdaptiveFit()` 方向自适应显示逻辑

### 关联文件

- `frontend/lib/views/video_grid_view.dart`
- `frontend/lib/widgets/video_grid_card.dart`
- `frontend/lib/widgets/top_tool_bar.dart`
- `frontend/lib/views/feed_view.dart`
- `frontend/lib/providers/video_list_provider.dart`
- `frontend/lib/widgets/video_player_widget.dart`
- `frontend/lib/models/media_item.dart`
- `frontend/lib/models/media_source.dart`

---

## [1.2.8] - 2026-06-15

### 新增
- 结构化日志系统（AppLogger）：支持 INFO/DEBUG/WARN/ERROR 四个日志级别
- 视频流降级策略：主 URL 失败时自动切换到 Emby 原生 API
- 敏感信息过滤：日志自动过滤 token、password、secret 等敏感字段

### 功能
- 认证流程日志：登录/登出/Token 恢复全程可追踪
- 媒体库日志：视频列表加载状态实时记录
- 视频播放器日志：播放初始化、状态变化、错误信息完整记录
- 搜索收藏日志：搜索请求、收藏操作状态记录
- EmbytokService 日志：HTTP 请求/响应完整记录

---

## [1.2.7] - 2026-06-15

### 修复
- 视频播放认证问题：Emby API 不返回 playbackUrl，添加 `computePlaybackUrl()` 动态构造播放 URL
- 图片加载认证问题：所有图片加载组件添加 `api_key` 认证参数
- UI 缩略图修复：修复搜索/收藏/历史页面的缩略图加载问题

### 新增
- `VideoPlayerWidget` 支持 `embyServerUrl` 和 `token` 参数
- `MediaItem` 新增 `authHeaders()` 和 `thumbnailUrlWithAuth()` 方法

---

## [1.2.5] - 2026-06-15

### 新增
- 发布流程脚本系统（release.sh / verify-release.sh / rollback-release.sh）
- 版本号统一管理文件（version.dart / version.py）
- CI 构建安全增强（keystore 文件权限设置）

### 修复
- 发布脚本跨平台兼容性（macOS/Linux sed 语法差异）
- Git 提交安全性（精确文件列表替代 `git add -A`）
- 回滚脚本错误消息语义清晰化
- 后端 API 版本号动态导入（从 version.py 读取，而非硬编码）

---

## [1.1.7] - 2026-06-15

### 新增
- 发布流程脚本系统（release.sh / verify-release.sh / rollback-release.sh）
- 版本号统一管理文件（version.dart / version.py）
- CI 构建安全增强（keystore 文件权限设置）

### 修复
- 发布脚本跨平台兼容性（macOS/Linux sed 语法差异）
- Git 提交安全性（精确文件列表替代 `git add -A`）
- 回滚脚本错误消息语义清晰化

---

## [1.1.3] - 2025-06-14

### 新增
- `scripts/release.sh` - 自动化版本发布脚本，支持 patch/minor/major 三种发布类型
- `scripts/rollback-release.sh` - 发布回滚脚本，支持 dry-run 预览模式
- `scripts/verify-release.sh` - 发布前版本一致性验证脚本
- `frontend/lib/utils/version.dart` - Flutter 版本信息常量文件
- `backend/core/version.py` - Python 后端版本信息常量文件

### 修复
- **跨平台兼容性**: `release.sh` 中实现 `sed_inplace()` 函数，根据 `uname -s` 自动检测操作系统，在 macOS (BSD sed) 和 Linux (GNU sed) 上正确执行就地编辑，之前硬编码的 `sed -i` 在 macOS 上会产生临时文件或错误
- **发布安全性**: `release.sh` 中将 `git add -A` 替换为精确文件列表 `git add frontend/pubspec.yaml frontend/android/app/build.gradle frontend/lib/utils/version.dart backend/core/version.py CHANGELOG.md`，防止意外提交未跟踪的敏感文件（如密钥、本地配置等）
- **命令健壮性**: `release.sh` 开头增加 `git`/`sed`/`grep`/`awk` 命令存在性预检查，缺失时输出中文错误消息并优雅退出，避免因命令不存在导致脚本中途失败
- **CI 构建安全**: GitHub Actions workflow 中 keystore 文件解码后立即设置 `chmod 600` 权限，仅允许拥有者读写，并在日志中输出权限验证结果
- **回滚消息修复**: `rollback-release.sh` 中将矛盾的"已存在或不存在"消息修正为清晰的"远程 tag 不存在，跳过"，使错误信息与实际分支判断逻辑一致

### 改进
- 同步 `frontend/android/app/build.gradle` 版本号（`versionName` 1.0.7 → 1.1.3，`versionCode` 7 → 13），与 `frontend/pubspec.yaml` 保持一致
- 所有发布脚本使用统一的颜色输出风格，增强可读性
- `release.sh` 支持 `--dry-run` 参数，在不实际修改任何文件的情况下预览发布流程
- `verify-release.sh` 检查项目中 4 个版本号位置（pubspec/build.gradle/version.dart/version.py）的一致性

---

## [1.1.2] - 历史版本

- EmbyTok Flutter 客户端基础架构
- 视频浏览、搜索、收藏功能实现

---

## [1.1.0] - 初始版本

- EmbyTok Flutter 应用首次发布
- 竖屏视频浏览体验
- 媒体库管理
- 用户偏好设置

---

## 版本号说明

- **MAJOR** 版本：API 不兼容的变更
- **MINOR** 版本：向下兼容的功能性新增
- **PATCH** 版本：向下兼容的问题修正

## 发布流程

1. 执行 `./scripts/verify-release.sh` 确认当前版本号一致
2. 执行 `./scripts/release.sh --dry-run patch|minor|major` 预览发布
3. 移除 `--dry-run` 正式执行发布
4. 推送标签：`git push origin vX.Y.Z`，自动触发 GitHub Actions 构建

## 回滚流程

1. 执行 `./scripts/rollback-release.sh --dry-run` 预览回滚
2. 移除 `--dry-run` 确认执行
3. 如需回滚远程提交，执行 `git push -f origin main`（请谨慎使用）
