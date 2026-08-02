# Tasks

## 阶段一：严重问题修复（必须，阻塞后续）

- [x] Task 1: 修复 `person_detail_view.dart` 强制解包崩溃风险
  - [x] SubTask 1.1: 在 `_loadData` 中将 `auth.embyServerUrl!` / `auth.token!` 改为 null 检查
  - [x] SubTask 1.2: 在 `_loadMore` 中同样处理 null 场景
  - [x] SubTask 1.3: null 时设置 `_error = '登录已过期，请重新登录'` 并停止加载
  - [x] SubTask 1.4: 补充测试 `person_detail_view_test.dart` 覆盖 token 为 null 场景

- [x] Task 2: 修复 `fullscreen_video_page.dart` Slider 拖动高频 seek
  - [x] SubTask 2.1: 提取 Slider 拖动状态字段 `_draggingProgress`、`_previewPosition`
  - [x] SubTask 2.2: `onChangeStart` 记录起始 position
  - [x] SubTask 2.3: `onChanged` 仅更新预览时间文本，不调用 `seekTo`
  - [x] SubTask 2.4: `onChangeEnd` 调用一次 `controller.seekTo(target)`
  - [x] SubTask 2.5: 补充测试验证单次拖动只触发一次 seek

- [x] Task 3: 修复 `favorites_view.dart` 撤销操作状态不一致
  - [x] SubTask 3.1: 提取撤销逻辑为独立方法 `_undoUnfavorite(item)`
  - [x] SubTask 3.2: `toggleFavorite` 失败时回滚 UI 状态（再次 toggle 恢复"已收藏"）
  - [x] SubTask 3.3: 回滚失败时 SnackBar 提示"撤销失败，请重试"
  - [x] SubTask 3.4: 同步修复 L729-747 和 L1245-1259 两处重复逻辑
  - [x] SubTask 3.5: 补充测试覆盖撤销失败回滚场景

- [x] Task 4: 修复 `recommend_view.dart` build 中副作用
  - [x] SubTask 4.1: 移除 `_buildBody` 中 L145 的 `_maybeShowError(state.error)` 调用
  - [x] SubTask 4.2: 在 `initState` 中改用 `ref.listen<RecommendState>(recommendProvider, ...)` 监听 error 变化
  - [x] SubTask 4.3: error 非空时触发 `addPostFrameCallback` 弹 SnackBar + `clearError`
  - [x] SubTask 4.4: 验证 rebuild 不重复触发 SnackBar

- [x] Task 5: 修复 `video_grid_view.dart` 空状态无主动引导
  - [x] SubTask 5.1: 区分 `videoState.items.isEmpty`（未配置媒体库）和 `displayItems.isEmpty`（筛选无结果）
  - [x] SubTask 5.2: 未配置媒体库时空状态显示"选择媒体库" `OutlinedButton`
  - [x] SubTask 5.3: 点击按钮调用 `LibrarySelector.show(context, scope: LibraryScope.video)`
  - [x] SubTask 5.4: 筛选无结果时仅文字提示，不显示按钮
  - [x] SubTask 5.5: 补充测试覆盖两种空状态分支

## 阶段二：中等问题修复（独立可并行）

- [x] Task 6: 迁移 `withOpacity` 废弃 API
  - [x] SubTask 6.1: 全局搜索 `withOpacity` 使用位置
  - [x] SubTask 6.2: 替换为 `withValues(alpha: ...)`（Flutter 3.27+）
  - [x] SubTask 6.3: 验证编译无 deprecation 警告

- [x] Task 7: 长列表懒加载优化
  - [x] SubTask 7.1: 评估 `favorites_view.dart`、`history_view.dart`、`search_view.dart` 长列表实现
  - [x] SubTask 7.2: `Column` + `SingleChildScrollView` 改为 `ListView.builder` 或 `CustomScrollView`
  - [x] SubTask 7.3: 保留现有滚动位置恢复逻辑（如有）
  - [x] SubTask 7.4: 验证滚动流畅性（手动测试）

- [x] Task 8: 提取 magic number 为常量
  - [x] SubTask 8.1: 识别 `fullscreen_video_page.dart` 中手势阈值、200px 触底加载等数值
  - [x] SubTask 8.2: 在 `constants.dart` 中定义具名常量（如 `kFullscreenSeekDebounceMs`、`kScrollLoadMoreThresholdPx`）
  - [x] SubTask 8.3: 替换裸数值为常量引用

- [x] Task 9: 清理死代码
  - [x] SubTask 9.1: 识别审查中发现的未调用方法、不可达分支
  - [x] SubTask 9.2: 删除死代码（确保无引用）
  - [x] SubTask 9.3: 验证编译通过

## 阶段三：低级别问题与代码质量（可选）

- [x] Task 10: 注释与代码语义同步
  - [x] SubTask 10.1: 更新 `person_detail_view.dart` 中 fallback 行为注释
  - [x] SubTask 10.2: 同步其他审查发现的注释与代码不一致

- [x] Task 11: 代码风格统一
  - [x] SubTask 11.1: 运行 `dart format` 统一格式
  - [x] SubTask 11.2: 运行 `flutter analyze` 修复 lint 警告

## 阶段四：验证与回归

- [x] Task 12: 全量测试通过
  - [x] SubTask 12.1: 执行 `flutter test`，0 失败
  - [x] SubTask 12.2: 执行 `flutter analyze`，无错误
  - [x] SubTask 12.3: 执行 `dart run tool/lints/hardcoded_color_lint.dart`，退出码 0

# Task Dependencies

- Task 1-5（严重问题）互相独立，可并行
- Task 6-9（中等问题）互相独立，可并行
- Task 6（withOpacity 迁移）可能在 Task 1-5 修改的文件中产生冲突，建议 Task 1-5 完成后再做 Task 6
- Task 10-11（低级别）依赖 Task 1-9 完成
- Task 12（验证）依赖所有 Task 完成

# 并行执行建议

- 第一批：Task 1、Task 2、Task 3、Task 4、Task 5（5 个严重问题，独立可并行）
- 第二批：Task 6、Task 7、Task 8、Task 9（中等问题，独立可并行）
- 第三批：Task 10、Task 11（低级别，顺序执行）
- 最后：Task 12（全量验证）
