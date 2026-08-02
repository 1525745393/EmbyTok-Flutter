# UI 界面全量审查 - Verification Checklist

## 严重问题验证（5 项，必须）

- [x] **Checkpoint 1 - person_detail_view.dart null 安全**
  - [x] `_loadData` 中无 `auth.embyServerUrl!` / `auth.token!` 强制解包（person_detail_view.dart L83-93）
  - [x] `_loadMore` 中无强制解包（person_detail_view.dart L144-150）
  - [x] token 为 null 时 `_error` 设置为"登录已过期，请重新登录"
  - [x] token 为 null 时不调用 `getPersonItems` / `getPersonDetail`
  - [x] 详情区域 fallback 到 `widget.person`，不阻塞已加载内容
  - [x] `person_detail_view_test.dart` 新增 token 为 null 场景测试通过

- [x] **Checkpoint 2 - fullscreen_video_page.dart Slider 防抖**
  - [x] L1157-1165 Slider 不再在 `onChanged` 中调用 `controller.seekTo`
  - [x] `onChangeStart` 记录起始 position
  - [x] `onChanged` 仅更新预览时间文本
  - [x] `onChangeEnd` 调用一次 `controller.seekTo(target)`
  - [x] 测试验证：模拟拖动 0.0 → 0.5 → 1.0，只触发一次 `seekTo`
  - [x] 拖动过程中底部时间文本实时更新预览

- [x] **Checkpoint 3 - favorites_view.dart 撤销一致性**
  - [x] 撤销操作提取为独立方法（消除 L729-747 与 L1245-1259 重复）
  - [x] `toggleFavorite` 失败时 UI 回滚到"未收藏"状态
  - [x] 回滚失败时 SnackBar 提示"撤销失败，请重试"
  - [x] 测试覆盖：mock `toggleFavorite` 抛异常，验证 UI 状态回滚
  - [x] 测试覆盖：撤销成功时 UI 保持"已收藏"

- [x] **Checkpoint 4 - recommend_view.dart build 无副作用**
  - [x] `_buildBody` 中无 `_maybeShowError(state.error)` 调用（recommend_view.dart L145）
  - [x] `initState` 中使用 `ref.listen<RecommendState>` 监听 error 变化
  - [x] error 非空时通过 `addPostFrameCallback` 弹 SnackBar + `clearError`
  - [x] 测试验证：多次 rebuild 不重复触发 `addPostFrameCallback`
  - [x] 测试验证：error 从 null → 非空 → null 切换时正确弹/不弹 SnackBar

- [x] **Checkpoint 5 - video_grid_view.dart 空状态引导**
  - [x] 区分 `videoState.items.isEmpty`（未配置媒体库）与 `displayItems.isEmpty`（筛选无结果）
  - [x] 未配置媒体库时空状态显示"选择媒体库" `OutlinedButton`
  - [x] 点击按钮调用 `LibrarySelector.show`
  - [x] 筛选无结果时仅文字提示，无按钮
  - [x] 测试覆盖两种空状态分支渲染正确的 widget

## 中等问题验证

- [x] **Checkpoint 6 - withOpacity 废弃 API 迁移**
  - [x] `frontend/lib/views/` 与 `frontend/lib/widgets/` 下无 `withOpacity` 调用
  - [x] 编译无 `withOpacity` deprecation 警告（Flutter 3.27+）
  - [x] 迁移至 `withValues(alpha: ...)` 的语义等价（颜色透明度数值一致）

- [x] **Checkpoint 7 - 长列表懒加载**
  - [x] `favorites_view.dart` 长列表使用 `ListView.builder` 或 `CustomScrollView`
  - [x] `history_view.dart` 长列表使用 `ListView.builder`
  - [x] `search_view.dart` 长列表使用 `ListView.builder`
  - [x] 不存在 `Column` + `SingleChildScrollView` 嵌套长列表
  - [x] 滚动位置恢复逻辑（如有）保持工作

- [x] **Checkpoint 8 - Magic Number 提取**
  - [x] `fullscreen_video_page.dart` 中手势阈值、触底加载阈值等不再为裸数值
  - [x] `constants.dart` 新增对应具名常量
  - [x] 代码中引用常量而非 magic number

- [x] **Checkpoint 9 - 死代码清理**
  - [x] 审查中识别的未调用方法已删除
  - [x] 不可达分支已删除
  - [x] 删除后编译通过，无引用错误

## 低级别问题验证

- [x] **Checkpoint 10 - 注释与代码同步**
  - [x] `person_detail_view.dart` fallback 行为注释与代码一致
  - [x] 其他审查发现的注释不一致已修复

- [x] **Checkpoint 11 - 代码风格**
  - [x] `dart format` 已执行，格式统一
  - [x] `flutter analyze` 无 error / warning（除已知的 allowlist 项）

## 全量验证

- [x] **Checkpoint 12 - 测试套件全绿**
  - [x] `flutter test` 0 失败
  - [x] 新增测试覆盖 5 个严重问题的回归场景
  - [x] 无 compilation error

- [x] **Checkpoint 13 - 静态分析通过**
  - [x] `flutter analyze` 退出码 0
  - [x] `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/` 退出码 0
  - [x] `dart run tool/lints/hardcoded_color_lint.dart --path lib/widgets/` 退出码 0

- [x] **Checkpoint 14 - 不破坏现有功能**
  - [x] 演员详情页正常加载（已登录 / token 过期两种场景）
  - [x] 全屏播放器进度条拖动后正确跳转
  - [x] 收藏列表取消收藏 + 撤销正常工作
  - [x] 推荐页错误提示正常弹出（不重复）
  - [x] 视频网格空状态显示按钮并可打开选择器
