# Emby 收藏/点赞功能修复 - Verification Checklist

## API 路径验证
- [ ] Checkpoint 1: `toggleFavorite` 调用时使用 `/Users/{userId}/FavoriteItems/{itemId}` 路径，不回退到 `/UserFavoriteItems/{itemId}`
- [ ] Checkpoint 2: `getFavoriteMovies` / `getFavoriteBoxSets` / `getFavoritePeople` 调用时使用带 userId 的路径
- [ ] Checkpoint 3: 所有收藏相关 API 调用的 `_defaultUserId` 与认证流程中的 userId 一致

## IncludeItemTypes 验证
- [ ] Checkpoint 4: `getLibraryItems` 的 `IncludeItemTypes` 包含 `'Video'`
- [ ] Checkpoint 5: `getFavoriteMovies` 的 `IncludeItemTypes` 包含 `'Video'`
- [ ] Checkpoint 6: `getRecentlyAdded` 的 `IncludeItemTypes` 包含 `'Video'`

## Service 实例共享验证
- [ ] Checkpoint 7: `FavoritesNotifier` 不再创建独立的 `EmbytokService()` 实例
- [ ] Checkpoint 8: `FavoritesService` (favorites_service_provider.dart) 也使用共享实例或正确传参

## FavoritesProvider 加载触发验证
- [ ] Checkpoint 9: `video_page_item.dart` 进入播放页时自动调用 `favoritesProvider.notifier.ensureLoaded()`
- [ ] Checkpoint 10: 不依赖 `FavoritesView` 的 `initState` — 用户可直接进入播放页仍能获取收藏列表

## UI 交互验证
- [ ] Checkpoint 11: 点击心形图标 — 图标立即由空心切换为实心，正确触发 API 调用
- [ ] Checkpoint 12: 点击星形图标 — 与心形图标响应同步，两个图标都正确切换
- [ ] Checkpoint 13: 双击视频画面 — 显示心形动画，同时触发 `toggleFavorite`
- [ ] Checkpoint 14: 再次点击/双击 — 正确取消收藏状态
- [ ] Checkpoint 15: 图标状态在切换视频后仍保持一致

## 内容类型覆盖验证
- [ ] Checkpoint 16: 电影（Movie）可正确收藏
- [ ] Checkpoint 17: 剧集（Episode）可正确收藏
- [ ] Checkpoint 18: 音乐视频（MusicVideo）可正确收藏
- [ ] Checkpoint 19: 普通视频/家庭视频（Video）可正确收藏
- [ ] Checkpoint 20: 合集（BoxSet）可正确收藏
- [ ] Checkpoint 21: 演员（Person）可正确收藏

## 错误处理验证
- [ ] Checkpoint 22: 网络失败时图标状态回滚到点击前状态
- [ ] Checkpoint 23: 网络失败时向用户显示错误信息
- [ ] Checkpoint 24: `_defaultUserId` 缺失时抛出清晰错误，而非静默使用回退路径

## 并发与去重验证
- [ ] Checkpoint 25: 快速连续点击同一图标只产生一次服务器 API 调用
- [ ] Checkpoint 26: `_pendingToggles` 去重机制正常工作

## 跨页面同步验证
- [ ] Checkpoint 27: 在播放页收藏视频后，进入 FavoritesView 页面可看到该视频
- [ ] Checkpoint 28: 切换视频后再返回，收藏状态保持

## 代码质量验证
- [ ] Checkpoint 29: `flutter analyze --no-pub lib/` 输出无 error
- [ ] Checkpoint 30: 代码可编译运行，无语法错误
- [ ] Checkpoint 31: 不破坏 feed_view / search_view 页面的正常功能
