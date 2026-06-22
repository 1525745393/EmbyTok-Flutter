# 收藏功能 - 实施计划（Decomposed Task List）

## [ ] Task 1: 优化 `favorites_provider.dart` —— 自动懒加载 + 统一 `isFavorite` 查询
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `FavoritesNotifier` 中增加 `_hasLoaded` 标志，避免重复调用 `loadFavorites`
  - 暴露 `ensureLoaded()` 方法，在首次需要收藏状态时懒加载
  - 保持 `isFavorite(String id)` 基于 `favoriteIds` 的 O(1) 查询
  - `toggleFavorite` 的乐观更新 / 回滚逻辑保留，增加 `_pendingToggles` Set 避免并发切换同一 id
- **Acceptance Criteria Addressed**: AC-2, AC-4
- **Test Requirements**:
  - `programmatic` 连续调用 2 次 `ensureLoaded` 只触发 1 次 `getFavorites` API
  - `programmatic` 对同一 item 并发调用 `toggleFavorite` 只发送 1 次网络请求
  - `programmatic` 失败后回滚 `favoriteIds` 与 `items` 状态一致
- **Notes**: 不改变顶层 provider 名字，保持 `favoritesProvider` 全局唯一，避免 breaking change

## [ ] Task 2: 完善 `gesture_overlay.dart` 双击动效与防抖
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 将 `_pendingSingleTap` / `_singleTapTimer` 保留为当前单击/双击区分逻辑不变
  - 新增 `_lastDoubleTapAt`（DateTime）作为"300ms 内重复双击不发请求"的防抖
  - `_onDoubleTap` 中：先判定防抖，再调用 `favoritesProvider.notifier.toggleFavorite`，然后 setState `_showHeart = true`
  - `_showHeart` 为 true 时渲染 `_FlyingHeart`；动画结束后设回 false（在 `_FlyingHeartState.dispose` 之前通过回调）
  - `_FlyingHeart` 内部 `AnimationController` 必须在 700ms 内结束并调用 onComplete 回调；避免重复动画叠加
- **Acceptance Criteria Addressed**: AC-1, AC-4
- **Test Requirements**:
  - `programmatic` 1 秒内触发 3 次双击，仅产生 1 次 `toggleFavorite` 调用（通过 mock service 计数）
  - `human-judgment` 双击后红心动效流畅，放大+渐隐效果与 TikTok 类似
- **Notes**: 需确保长按时的 2x 倍速与水平拖动行为不受影响（仅影响双击路径）

## [ ] Task 3: 重构 `video_page_item.dart` 右侧按钮 —— 响应式状态 + 点击动画
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 将 `final favorited = ref.watch(favoritesProvider).favoriteIds.contains(item.id)` 改为在 `build` 方法中通过 `ref.watch` 获取，确保点击后状态切换立即反映到 UI
  - 点赞按钮包裹 `AnimatedScale`（scale: `_tapPressed ? 0.8 : 1.0`，duration: 120ms），`onTapDown` 设为 true，`onTapUp`/`onTapCancel` 恢复
  - 点击同时调用 `toggleFavorite(item)`；颜色 / 图标随 `isFavorite` 条件切换
  - 收藏（star）按钮类似，颜色从白色变为 `Colors.amber`
  - 按钮文案保持"点赞"和"收藏"，说明文档中注明两者映射同一 Emby 收藏状态
- **Acceptance Criteria Addressed**: AC-2, AC-4
- **Test Requirements**:
  - `programmatic` widget 测试：点击按钮后 `favoriteIds.contains(item.id)` 为 true，UI 图标从 `favorite_border` 变 `favorite`
  - `human-judgment` 按钮按下有轻微缩放回弹，视觉反馈明显
- **Notes**: `AnimatedScale` 需 Flutter 3.x 支持；若不可用可降级为 `AnimatedContainer` + `Transform.scale`

## [ ] Task 4: 完善 `favorites_view.dart` —— 错误重试 + 空状态优化
- **Priority**: P1
- **Depends On**: Task 1
- **Description**:
  - 空状态文案、图标居中对齐；图标 size 80px，颜色 `Colors.white30`
  - 错误状态下增加"重试"ElevatedButton，点击调用 `loadFavorites`
  - 进入页面后 `initState` 中 `addPostFrameCallback` 触发 `loadFavorites`；保留当前逻辑
- **Acceptance Criteria Addressed**: AC-3, AC-5
- **Test Requirements**:
  - `human-judgment` 空列表显示空状态提示；返回错误时显示重试按钮
  - `programmatic` 当 `items.isEmpty && error != null` 时渲染错误列

## [ ] Task 5: 静态分析与本地验证
- **Priority**: P0
- **Depends On**: Task 1, 2, 3, 4
- **Description**:
  - 在 `frontend/` 目录执行 `flutter analyze --no-pub lib`，确认 0 warning/error
  - 若存在 `prefer_const_constructors`, `unawaited_futures`, `prefer_const_declarations` 等提示，使用 `// ignore:` 或改写为 const
  - 本地 run 一次 `flutter test test/`（若有收藏相关测试）
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` `flutter analyze` 输出 "No issues found!"
  - `programmatic` 已有测试通过
- **Notes**: 若 CI 有其他脚本（如 `scripts/flutter-check.sh`）也需执行

## 依赖关系图（DAG）

```
Task 1 (favorites_provider)
   ├───> Task 2 (gesture_overlay 双击防抖)
   ├───> Task 3 (video_page_item 按钮响应式)
   └───> Task 4 (favorites_view 空状态/重试)
            └───────> Task 5 (lint & test)
```
