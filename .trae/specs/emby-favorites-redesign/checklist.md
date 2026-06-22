# Emby 收藏分栏页面重构 - 验证清单

---

## 0. 设计审查

- [ ] **CI 确认所有改动的文件都被正确引用了现有模型
- [ ]**CI 确认不引入新的第三方依赖
- [ ]**代码风格与现有项目完全一致（Riverpod 2.x + Flutter 3.x**

---

## Task 1: EmbytokService 新增三个按类型获取收藏的方法

- [ ]**`getFavoriteMovies` 方法已新增，正确传入 `Filters: 'IsFavorite'` + `IncludeItemTypes: 'Movie,Series,MusicVideo,Episode'`
- [ ]**`getFavoriteBoxSets` 方法已新增，正确传入 `Filters: 'IsFavorite'` + `IncludeItemTypes: 'BoxSet'`
- [ ]**`getFavoritePeople` 方法已新增，正确传入 `Filters: 'IsFavorite'` + `IncludeItemTypes: 'Person'`
- [ ]**三个方法的 `Fields` 参数包含 `ImageTags`（用于海报/头像生成`
- [ ]**三个方法返回类型均为 `Future<List<MediaItem>>`
- [ ]**保留了原有 `getFavorites` 方法（不删除（向后兼容视频页收藏状态判断）
- [ ]**`flutter analyze --no-pub lib` 通过：`**无 error`

---

## Task 2: FavoritesNotifier 重构

- [ ]**`FavoritesState` 包含 `movies` / `boxSets` / `people` 三组独立列表
- [ ]**`FavoritesState` 保留 `isLoading` / `error` / `favoriteIds`
- [ ]**`favoriteIds` 是三组列表 id 的并集
- [ ]**`loadFavorites` 使用 `Future.wait` 并行请求三个接口
- [ ]**三个请求中任何一个失败不影响其他请求的结果展示
- [ ]**`toggleFavorite` 保留乐观更新 + 失败回滚逻辑
- [ ]**`toggleFavorite` 保留 `_pendingToggles` 去重机制
- [ ]**`isFavorite(String itemId)` 能正确判断任意类型条目的收藏状态
- [ ]**`reset()` 在登出/切换账号时正确清空所有三组数据
- [ ]**`FavoritesNotifier` 监听 `authProvider`，自动加载/清理
- [ ]**`flutter analyze --no-pub lib` 通过：无 error

---

## Task 3: 收藏页面 UI

- [ ]**页面主体为 `Scaffold` + `AppBar`（标题 + 刷新按钮）
- [ ]**三个分栏：收藏影片 / 收藏合集 / 收藏人物，每个分栏有标题 + 卡片列表
- [ ]**每个分栏内部为 `ListView.builder(scrollDirection: Axis.horizontal)`
- [ ]**卡片风格：圆角 12px，`white10` 背景，白色文字
- [ ]**卡片尺寸：影片/合集卡片 宽 ~120px，高 ~180px；人物卡片尺寸与其他一致
- [ ]**标题下显示年份或人名（最大 2 行，overflow）
- [ ]**点击影片卡片 → 播放页
- [ ]**点击合集卡片 → 合集详情页
- [ ]**点击人物卡片 → 人员作品页
- [ ]**空状态：某分栏为空时显示灰色占位文字，不影响其他分栏
- [ ]**加载状态：整页显示 `CircularProgressIndicator(color: Color(0xFFE91E63)`
- [ ]**主色 `Color(0xFFE91E63)` 与项目其他页面一致
- [ ]**`flutter analyze --no-pub lib` 通过

---

## Task 4: 合集详情 + 人员作品页

### 合集详情页
- [ ]**页面风格与收藏页一致（黑色背景、粉色主色、圆角）
- [ ]**顶部展示合集封面图（宽高比约 16:9）
- [ ]**展示合集标题 + 简介（`Overview`）
- [ ]**通过 `getChildren(boxSetId)` 获取包含的影片列表
- [ ]**影片列表样式与项目其他列表一致
- [ ]**点击影片 → 跳转到播放页
- [ ]**返回键正确回到收藏页

### 人员作品页
- [ ]**页面风格与收藏页一致
- [ ]**顶部展示人员头像（圆形或圆角矩形）+ 姓名 + 简介
- [ ]**通过 `getPersonItems(personId)` 获取出演作品列表
- [ ]**作品列表样式与项目其他列表一致
- [ ]**点击作品 → 跳转到播放页
- [ ]**返回键正确回到收藏页

### 代码质量
- [ ]**`flutter analyze --no-pub lib` 通过

---

## Task 5: 版本管理

- [ ]**`frontend/pubspec.yaml` 版本号更新为 `1.4.0`
- [ ]**`CHANGELOG.md` 新增 `[1.4.0]` 条目，清晰描述三栏收藏页面重构与新详情页

---

## 端到端（冒烟测试

- [ ]**登录用户 A：收藏影片，收藏 1~2 部影片
- [ ]**返回收藏页：刚收藏的影片出现在「收藏影片」分栏
- [ ]**收藏合集或人物（如有）
- [ ]**点击影片卡片进入播放页
- [ ]**双击视频画面切换收藏状态，返回列表，状态正确变化
- [ ]**切换到账号 B：A 的收藏不出现在 B 的页面中
- [ ]**登出状态下：不展示任何收藏数据
- [ ]**网络错误时，页面展示"加载失败，点击重试"提示而非崩溃
- [ ]**`flutter analyze --no-pub lib` 通过（0 errors, 0 warnings）

---

## 验收总结

| 阶段 | 完成标准 |
|---|---|
| 设计 | 需求 / 计划 / 清单 | 已交付 |
| Task 1 | Service 层 | 无编译错误，`flutter analyze` 通过 |
| Task 2 | Provider 层 | `favoriteIds` 正确、乐观更新正确、登出清理、登出清理、错误处理正确 |
| Task 3 | 收藏页 UI | 三栏布局正确，空/加载/错误三种状态展示正确 |
| Task 4 | 详情页 | 两个新页面样式一致 |
| Task 5 | 版本号 &gt; 与 pubspec.yaml 和 CHANGELOG 匹配 |
| 端到端测试 | 账号 A 收藏展示、切换账号隔离、`flutter analyze` 0 errors |

**通过标准：所有检查点 ✓
