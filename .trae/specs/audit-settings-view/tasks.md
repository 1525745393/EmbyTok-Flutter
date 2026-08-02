# 设置页面审查与修复 - 任务清单

## [x] Task 1: 修复 3 个 RadioListTile 对话框选中无视觉反馈

- **Priority**: high
- **Depends On**: None
- **Description**:
  修改以下 3 个对话框，使其在用户点击选项后更新 `current` 局部变量并 `setState`，而非立即 `Navigator.pop`：
  - `_showRecommendHalfLifeDaysDialog` (L574-624)
  - `_showAntiFatigueDaysDialog` (L660-708)
  - `_showUserRatingMinDialog` (L746-794)

  具体修改：
  - 将 `AlertDialog` 内容包入 `StatefulBuilder`
  - `onChanged` 回调中：先 `await provider.setX(v)`，再 `setDialogState(() => current = v)` 更新 UI，**不立即 pop**
  - 保留底部"完成"按钮关闭对话框；将现有"取消"改为"完成"以符合"可继续切换"语义
  - 对于 `_showUserRatingMinDialog` 中 `selected = (current - d).abs() < 0.01` 的浮点比较逻辑保持不变

- **Acceptance Criteria Addressed**: Requirement: 对话框选中即时反馈
- **Test Requirements**:
  - `programmatic` TR-1.1: 点击选项后 RadioListTile 的 `groupValue` 更新为新值，选中项显示 check 图标
  - `programmatic` TR-1.2: 对话框保持打开，用户可继续切换其他选项
  - `human-judgement` TR-1.3: 视觉上选中项立即高亮

## [x] Task 2: 优化 2 个 Slider 对话框的写入时机

- **Priority**: high
- **Depends On**: None
- **Description**:
  修改以下 2 个对话框，将 provider 写入从 `onChanged` 移到 `onChangeEnd`：
  - `_showRecommendRatingDialog` (L372-416)
  - `_showRecommendRuntimeDialog` (L419-463)

  具体修改：
  - `onChanged`: 仅调用 `setDialogState(() => current = v)` 更新 UI 显示值
  - `onChangeEnd`: 调用 `provider.setX(v)` 写入持久化
  - 保留现有 `setDialogState` 的实时预览显示（如 "≥ 7.5"）

- **Acceptance Criteria Addressed**: Requirement: Slider 拖动写入时机优化
- **Test Requirements**:
  - `programmatic` TR-2.1: 拖动过程中 UI 显示值实时更新，但 provider 未被调用
  - `programmatic` TR-2.2: 拖动结束（松手）时 provider 被调用一次且仅一次
  - `programmatic` TR-2.3: 拖动结束后再次打开对话框，显示值为上次 `onChangeEnd` 写入的值

## [x] Task 3: 消除硬编码颜色违规

- **Priority**: medium
- **Depends On**: None
- **Description**:
  处理以下硬编码颜色：
  - `_showDonateDialog` (L2552-2668): `Color(0xFF07C160)`（微信绿）、`Color(0xFF1677FF)`（支付宝蓝）、`Colors.red.withOpacity(0.12)`、`Colors.red`
  - `_showAboutDialog` (L2704): `Colors.white`

  方案选择（需用户决策后执行）：
  - **方案 A**：将微信绿、支付宝蓝加入 `frontend/tool/lints/hardcoded_color_allowlist.json` 白名单（理由：品牌色，与主题无关）
  - **方案 B**：在 `app_theme.dart` 中扩展 `DonateColors` 主题扩展，通过 `Theme.of(context).extension<DonateColors>()` 访问

  对于 `Colors.red`（打赏对话框图标）和 `Colors.white`（关于页图标），改用 `scheme.error` 和 `scheme.onPrimary` 替代。

- **Acceptance Criteria Addressed**: Requirement: 颜色规范合规
- **Test Requirements**:
  - `programmatic` TR-3.1: `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/settings_view.dart` 退出码为 0
  - `human-judgement` TR-3.2: 视觉上品牌色保持原样（微信绿、支付宝蓝不变）

## [x] Task 4: 完善 `_formatSize` 支持 GB 单位

- **Priority**: low
- **Depends On**: None
- **Description**:
  修改 `_formatSize` (L2882-2887)，增加 GB 分支：

  ```dart
  String _formatSize(int bytes) {
    if (bytes <= 0) return '暂无缓存';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  ```

- **Acceptance Criteria Addressed**: Requirement: 缓存大小格式化支持 GB
- **Test Requirements**:
  - `programmatic` TR-4.1: 输入 1073741824 (1GB) 输出 "1.00 GB"
  - `programmatic` TR-4.2: 输入 5368709120 (5GB) 输出 "5.00 GB"
  - `programmatic` TR-4.3: 输入 1048576 (1MB) 仍输出 "1.0 MB"

## [x] Task 5: 修正手势控制误导性文案

- **Priority**: low
- **Depends On**: None
- **Description**:
  修改 `_buildGestureControlTile` (L840-848)，将 subtitle 从"配置滑动和双击手势"改为"查看手势说明"。

- **Acceptance Criteria Addressed**: Requirement: 文案与实际功能一致
- **Test Requirements**:
  - `human-judgement` TR-5.1: 设置页中"手势控制"项 subtitle 显示"查看手势说明"

## [x] Task 6: 优化重置设置流程文案

- **Priority**: medium
- **Depends On**: None
- **Description**:
  修改 `_showResetSettingsDialog` (L1655-1706):
  - 对话框 content 中去除"重置后需要重启应用以完全生效"句子
  - SnackBar 内容从"设置已重置，请重启应用以完全生效"改为"设置已重置并立即生效"
  - 保留"不影响：登录信息、观看历史、搜索历史、收藏"的说明

- **Acceptance Criteria Addressed**: Requirement: 重置设置流程准确
- **Test Requirements**:
  - `human-judgement` TR-6.1: 重置对话框内容中无"重启应用"字样
  - `human-judgement` TR-6.2: 重置后 SnackBar 提示"设置已重置并立即生效"

## [x] Task 7: 重构 `_RecommendAdvancedTile` 分隔线实现

- **Priority**: low
- **Depends On**: None
- **Description**:
  修改 `_RecommendAdvancedTile` (L3286-3288)，将：
  ```dart
  ...widget.advancedTilesBuilder().expand((tile) => [tile, const Divider(height: 1, indent: 56)]).toList()..removeLast(),
  ```
  替换为更清晰的实现：
  ```dart
  ...[
    for (var i = 0; i < advancedTiles.length; i++) ...[
      if (i > 0) const Divider(height: 1, indent: 56),
      advancedTiles[i],
    ],
  ],
  ```

- **Acceptance Criteria Addressed**: Requirement: `_RecommendAdvancedTile` 分隔线实现
- **Test Requirements**:
  - `programmatic` TR-7.1: 展开后各项之间有分隔线，最后一项无分隔线（行为不变）
  - `human-judgement` TR-7.2: 折叠/展开视觉无变化

## [x] Task 8: 补充测试用例

- **Priority**: medium
- **Depends On**: Task 1, Task 2, Task 4
- **Description**:
  在 `frontend/test/views/` 下创建或补充 `settings_view_test.dart`，覆盖：
  - RadioListTile 对话框选中后 UI 更新（验证 `groupValue` 变化）
  - Slider 对话框 `onChanged` 不写 provider，`onChangeEnd` 写 provider（mock provider 验证调用次数）
  - `_formatSize` 各档单位（B/KB/MB/GB）

- **Test Requirements**:
  - `programmatic` TR-8.1: 所有新增测试通过
  - `programmatic` TR-8.2: `flutter test test/views/settings_view_test.dart` 退出码 0

# Task Dependencies

- Task 8 依赖 Task 1, Task 2, Task 4（验证已修复的行为）
- Task 1, 2, 3, 4, 5, 6, 7 之间无依赖，可并行执行
