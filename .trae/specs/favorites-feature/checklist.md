# 收藏功能 - 验证检查清单

## 代码与静态分析
- [ ] `flutter analyze --no-pub lib` 在 `frontend/` 目录下输出 "No issues found!"
- [ ] 所有新增/修改文件使用项目已有代码风格：PascalCase 类名，camelCase 变量，2 空格缩进，使用 `const` 构造函数优先
- [ ] 未引入任何新依赖；`pubspec.yaml` 不变
- [ ] 未使用 `Color.withValues`（Flutter 3.22+ API），统一使用 `Color.withOpacity()`

## favorites_provider.dart 状态管理
- [ ] `FavoritesNotifier` 存在 `_hasLoaded` 标志或等效懒加载机制
- [ ] 首次读取 `favoritesProvider` 时自动触发 `loadFavorites`（通过 `ensureLoaded`），不会重复请求
- [ ] `isFavorite(String id)` 返回 `favoriteIds.contains(id)`，O(1) 查询
- [ ] `toggleFavorite` 对同一 id 并发调用仅发送 1 次请求（防重复机制）
- [ ] `toggleFavorite` 失败时回滚本地 `favoriteIds` 与 `items`

## gesture_overlay.dart 双击动效
- [ ] 双击视频画面触发红心动画（粉色 `Icons.favorite`，放大 2.8x + 渐隐 ~700ms）
- [ ] 300ms 内连续双击只调用 1 次 `toggleFavorite`
- [ ] 单击仍为播放/暂停，长按时仍为 2x 倍速，水平拖动仍为 seek，均未破坏
- [ ] `_FlyingHeart` 动画结束后自动从树中移除，避免内存泄漏

## video_page_item.dart 右侧按钮响应式状态
- [ ] `favorited` 状态通过 `ref.watch(favoritesProvider)` 响应式读取，点击后 UI 立即更新
- [ ] 点赞按钮（favorite）未收藏：`Icons.favorite_border` + 白色；已收藏：`Icons.favorite` + `Color(0xFFE91E63)`
- [ ] 收藏按钮（star）未收藏：`Icons.star_border` + 白色；已收藏：`Icons.star` + `Colors.amber`
- [ ] 点击按钮有 `AnimatedScale` 缩放动画（~120ms，0.8x 按下）
- [ ] 双击画面后，右侧按钮图标同步切换（共享同一个 `favoritesProvider` 状态）

## favorites_view.dart 列表页
- [ ] 进入页面自动调用 `loadFavorites`
- [ ] 加载中显示粉色 `CircularProgressIndicator`
- [ ] 无收藏时显示空状态：`Icons.favorite_border`（80px，`Colors.white30`）+ "还没有收藏" + "双击视频即可收藏 💖"
- [ ] 错误时显示 `Icons.error_outline` + 错误消息 + "重试"按钮（点击再次 `loadFavorites`）
- [ ] 每条 `_FavoriteTile` 展示海报、标题、类型标签、时长、简介（1 行）
- [ ] 左滑条目可取消收藏

## 功能 / 交互验收
- [ ] 未登录时，双击画面 / 点击按钮不会发送网络请求，且不崩溃
- [ ] 切换账号后重新登录时，旧账号收藏不会残留（provider 随 authProvider 重新初始化或显式清理）
- [ ] 在视频播放页双击 → 切换收藏 → 返回收藏列表页可见新增条目
- [ ] 所有页面在浅色/深色主题下都正常（当前项目为深色主题）
- [ ] Android 物理返回键 / iOS 侧滑返回均不打断动画或崩溃

## 测试
- [ ] 若存在 `test/providers/favorites_provider_test.dart`，运行 `flutter test` 全部通过
- [ ] widget 测试覆盖"点击按钮 → 调用 toggleFavorite → state 变化"流程
- [ ] 测试中 mock `EmbytokService`，避免真实网络请求
