# 验证清单

## 功能验证
- [x] AC-1: 搜索页面 → 按返回键 → 回到 Feed（不显示退出确认）
- [x] AC-2: 历史页面 → 按返回键 → 回到 Feed（不显示退出确认）
- [x] AC-3: 搜索页点击视频 → 视频播放页 → 按返回键 → 回到搜索页 → 再按返回键 → 回到 Feed
- [x] AC-4: Feed → 按返回键 → 显示"退出应用？"确认对话框
- [x] AC-5: flutter analyze 无 error

## 代码审查
- [x] SearchView 的 `useScaffold` 参数正确，两种模式都正常工作
- [x] HistoryView 的 `useScaffold` 参数正确，两种模式都正常工作
- [x] HomeScaffold 正确使用 `useScaffold: false` 模式
- [x] 没有嵌套 Scaffold（在覆盖层模式下）
- [x] 代码添加了中文注释，说明清晰
- [x] 没有引入新的 lint 警告或 error
- [x] 搜索/历史页面的顶部返回按钮调用 `backToFeed()` 而非 `Navigator.pop`
