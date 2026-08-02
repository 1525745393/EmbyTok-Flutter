# 设置页面审查与修复 - 验证清单

> **验证环境限制说明**：当前沙箱环境未安装 Flutter/Dart SDK，无法运行 `flutter test`、`flutter analyze`、`dart run` 等命令。以下标注为 `[x]` 的项通过代码审查（人工阅读验证）或 Python 正则复现验证；标注为 `[~]` 的项因环境限制无法运行验证，需在 Flutter SDK 环境下补验。

## 对话框交互反馈

- [x] `_showRecommendHalfLifeDaysDialog` 点击选项后 RadioListTile 高亮显示，对话框保持打开
  - 验证：L590-633 使用 StatefulBuilder，onChanged 中 setLocalState 更新 current，不 pop
- [x] `_showAntiFatigueDaysDialog` 点击选项后 RadioListTile 高亮显示，对话框保持打开
  - 验证：L680-721 同上模式
- [x] `_showUserRatingMinDialog` 点击选项后 RadioListTile 高亮显示，对话框保持打开
  - 验证：L772-817 同上模式，保留浮点比较逻辑
- [x] 3 个对话框底部"完成"按钮可关闭对话框
  - 验证：L628-630、L716-718、L807-809 均有 TextButton('完成') 调用 Navigator.pop
- [x] 3 个对话框中可连续切换不同选项
  - 验证：onChanged 中 setLocalState 更新 current，RadioListTile 的 groupValue 随之变化

## Slider 写入时机

- [x] `_showRecommendRatingDialog` 拖动过程中 UI 显示值实时更新（如 "≥ 7.5"）
  - 验证：L397-399 onChanged 中 setDialogState(() => current = v)
- [x] `_showRecommendRatingDialog` 拖动过程中 `recommendMinRatingProvider.notifier.setRating` 未被调用
  - 验证：onChanged 中仅 setDialogState，无 provider 调用
- [x] `_showRecommendRatingDialog` 松手时 `setRating` 被调用一次且仅一次
  - 验证：L400-402 onChangeEnd 中调用 setRating(v)
- [x] `_showRecommendRuntimeDialog` 拖动过程中 UI 显示值实时更新（如 "120 秒以上"）
  - 验证：L449-451 onChanged 中 setDialogState(() => current = v.round())
- [x] `_showRecommendRuntimeDialog` 拖动过程中 `setMinRuntime` 未被调用
  - 验证：onChanged 中仅 setDialogState
- [x] `_showRecommendRuntimeDialog` 松手时 `setMinRuntime` 被调用一次且仅一次
  - 验证：L452-454 onChangeEnd 中调用 setMinRuntime(v.round())

## 颜色规范合规

- [~] `dart run tool/lints/hardcoded_color_lint.dart --path lib/views/settings_view.dart` 退出码为 0
  - 状态：无法运行（Flutter SDK 不可用）
  - 已通过 Python 正则复现验证：`_showDonateDialog`(L2575-2692) 和 `_showAboutDialog`(L2693-2845) 区域违规数 0 ✅
  - 注意：全文件存在 47 条**既有** `Colors.xxx` 违规（如 `Colors.deepPurple` 等图标色），这些不在本次 Task 3 范围内，需单独处理
- [x] 打赏对话框微信收款码图标仍为绿色（#07C160 视觉不变）
  - 验证：L2631 `color: DonateColors.wechat`，DonateColors.wechat = Color(0xFF07C160)
- [x] 打赏对话框支付宝收款码图标仍为蓝色（#1677FF 视觉不变）
  - 验证：L2648 `color: DonateColors.alipay`，DonateColors.alipay = Color(0xFF1677FF)
- [x] 打赏对话框标题图标颜色与主题 error 色一致（替代 `Colors.red`）
  - 验证：L2593 `DonateColors.donateAccent.withOpacity(0.12)`，L2597 `DonateColors.donateAccent`
  - 注意：实际使用 DonateColors.donateAccent(#F44336) 而非 scheme.error，因打赏图标是支持性图标非错误状态
- [x] 关于页应用图标内的 play 图标使用 `scheme.onPrimary`（替代 `Colors.white`）
  - 验证：L2726 `color: scheme.onPrimary`，并正确移除了 const 关键字

## 缓存大小格式化

- [x] `formatBytes(0)` 返回 "暂无缓存"
  - 验证：formatters.dart L36，测试 formatters_test.dart L101
- [x] `formatBytes(512)` 返回 "512 B"
  - 验证：测试 L107
- [x] `formatBytes(2048)` 返回 "2.0 KB"
  - 验证：测试 L114
- [x] `formatBytes(1048576)` 返回 "1.0 MB"
  - 验证：测试 L119
- [x] `formatBytes(1073741824)` 返回 "1.00 GB"
  - 验证：测试 L125
- [x] `formatBytes(5368709120)` 返回 "5.00 GB"
  - 验证：测试 L126
- [x] 原 `_formatSize` 方法已删除，调用点替换为 `formatBytes`
  - 验证：Grep 确认全项目无 `_formatSize` 残留引用

## 文案准确性

- [x] `_buildGestureControlTile` subtitle 显示"查看手势说明"（非"配置滑动和双击手势"）
  - 验证：L868 `subtitle: '查看手势说明'`
- [x] `_showResetSettingsDialog` 对话框 content 中无"重启应用"字样
  - 验证：L1685-1688 content 文本中无"重启"字样
- [x] 重置设置后 SnackBar 提示"设置已重置并立即生效"（非"请重启应用以完全生效"）
  - 验证：L1704 `content: const Text('设置已重置并立即生效')`

## 代码可读性

- [x] `_RecommendAdvancedTile` 不再使用 `..removeLast()` 处理分隔线
  - 验证：L3313 使用 `_buildAdvancedTilesWithDividers()` 辅助方法
- [x] 展开后各项之间有分隔线，最后一项无分隔线（行为不变）
  - 验证：L3320-3330 for 循环中 `if (i > 0) result.add(Divider)` 确保首项前无分隔线、末项后无分隔线
- [x] 折叠状态下不构建高级 tiles（避免不必要的 ref.watch）
  - 验证：L3311 `if (_expanded)` 条件判断

## 回归验证

- [~] 设置页所有 25+ 设置项可正常打开、修改、关闭
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 推荐高级选项折叠/展开功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 设置搜索功能正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] APK 在线更新流程不受影响
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 日志导出/清除功能不受影响
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 观看统计对话框正常
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 许可证页正常加载
  - 状态：需 Flutter SDK 环境下人工验证
- [~] 现有所有测试通过（`flutter test` 退出码 0）
  - 状态：无法运行（Flutter SDK 不可用）
- [~] `flutter analyze` 无新增 error 级别告警
  - 状态：无法运行（Flutter SDK 不可用）

## 文档与提交

- [ ] 每个修复独立提交，提交信息准确描述变更
- [ ] 提交前执行 `git diff --cached --stat` 核对暂存内容
- [ ] 提交信息符合项目规范（中文，描述变更内容与原因）

## 验证状态总结

| 类别 | 已验证 [x] | 待验证 [~] | 未开始 [ ] |
|------|-----------|-----------|-----------|
| 对话框交互反馈 | 5 | 0 | 0 |
| Slider 写入时机 | 6 | 0 | 0 |
| 颜色规范合规 | 4 | 1 | 0 |
| 缓存大小格式化 | 7 | 0 | 0 |
| 文案准确性 | 3 | 0 | 0 |
| 代码可读性 | 3 | 0 | 0 |
| 回归验证 | 0 | 9 | 0 |
| 文档与提交 | 0 | 0 | 3 |

**待验证项说明**：9 项回归验证和 3 项提交项需在 Flutter SDK 环境下执行。1 项 lint 检查已通过 Python 正则复现验证修改区域合规，但全文件 lint 因 47 条既有违规无法通过。
