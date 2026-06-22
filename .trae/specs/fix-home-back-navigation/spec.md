# 修复顶/底部操作区返回逻辑问题 - PRD

## Overview

当前应用中有两套导航系统互相冲突：HomeScaffold 内部使用 `Stack` 和 `IndexedStack` 进行页面切换（搜索/历史作为覆盖层），而 GoRouter 使用路由栈。这导致点击顶部/底部按钮打开的页面按系统返回键直接退出应用。

## Problem Analysis

**根本原因：**

1. **SearchView / HistoryView 被渲染为 HomeScaffold 内部的 Stack 覆盖层**，但它们内部仍然使用 `Scaffold` + `AppBar`，造成 Scaffold 嵌套问题
2. **SearchView / HistoryView 使用 `Navigator.pop(context)`**，当它们在 HomeScaffold Stack 内（不是独立 GoRouter 路由）时，`Navigator.pop` 尝试弹出 HomeScaffold 所在的根路由，导致应用直接退出
3. **系统返回键逻辑依赖 HomeScaffold PopScope**，但嵌套的 Scaffold 可能干扰 PopScope 的状态捕获

**具体问题场景：**

| 场景 | 期望行为 | 实际行为 |
|------|---------|---------|
| 首页 → 点击顶部搜索按钮 → 按返回键 | 回到首页 Feed | 可能直接退出应用 |
| 首页 → 点击顶部历史按钮 → 按返回键 | 回到首页 Feed | 可能直接退出应用 |
| 首页 → 点击搜索/历史 → 点击视频 → 按返回键 | 回到搜索/历史页 → 再按回到 Feed | 可能直接退出 |
| 首页 → 点击底部"收藏" → 按返回键 | 回到首页 Feed | 正常工作 |

## Goals

1. 确保搜索/历史页面作为 HomeScaffold 覆盖层渲染时，按系统返回键正确回到 Feed 页面
2. 确保从搜索/历史页面内的视频播放页返回时，正确回到搜索/历史页面
3. 修复 SearchView/HistoryView 与 HomeScaffold 导航系统的集成问题
4. 保持代码简洁，避免嵌套 Scaffold 的问题

## Non-Goals

- 不改变 GoRouter 的整体路由结构
- 不改变底部导航栏的 3-tab 简化结构
- 不重写整个页面导航系统（保持 Provider 状态驱动的页面切换）

## 技术方案

### 方案 A：为 SearchView / HistoryView 增加"覆盖层模式"参数

在构造函数中增加 `useScaffold` 参数：
- `useScaffold=true`（默认）：独立路由模式，包含 Scaffold + AppBar
- `useScaffold=false`（HomeScaffold 内使用）：覆盖层模式，只渲染内容，使用 Provider 管理返回导航

**HomeScaffold 中的使用：**
```
// 在覆盖层 Stack 中使用无 Scaffold 模式
SearchView(useScaffold: false)  // 不渲染 Scaffold/AppBar
HistoryView(useScaffold: false)
```

**返回键处理：**
- 在覆盖层模式下，提供自己的顶部栏（含返回按钮）
- 点击返回按钮调用 `ref.read(pageNavigationNotifierProvider).backToFeed()`
- 系统返回键由 HomeScaffold PopScope 统一处理（现已有逻辑）

### 方案 B：统一使用 GoRouter 路由（不推荐）

将搜索/历史页面改为独立 GoRouter 路由，不在 HomeScaffold 内渲染。

缺点：破坏了覆盖层交互的简洁性，每次切换都走路由栈，不符合用户"覆盖层"体验的设计意图。

### 方案 C：修复 Navigator.pop 调用 + 简化 Scaffold

将 SearchView/HistoryView 中的 `Navigator.pop(context)` 改为 Provider 驱动的返回逻辑。
移除内部的 Scaffold 嵌套，改为更轻量的 Container + SafeArea 结构。

**结论：采用方案 A，即更完整的方案 C（两者在实现上几乎相同）。**

## Functional Requirements

**FR-1: SearchView 支持覆盖层模式**
- 构造函数增加 `useScaffold` 参数（默认 true）
- 当 `useScaffold=false` 时，不渲染 Scaffold 和 AppBar
- 覆盖层模式下渲染一个简化的顶部栏，含返回图标按钮
- 点击返回图标 → `backToFeed()`

**FR-2: HistoryView 支持覆盖层模式**
- 同上，与 SearchView 对称修改

**FR-3: HomeScaffold PopScope 逻辑保持不变**
- 保持现有的三层逻辑：overlay → tab → feed → exit confirmation
- 确保 state 读取正确，不被嵌套 Scaffold 干扰

**FR-4: 视频播放页返回逻辑保持不变**
- `context.push('/play/${item.id}')` 继续使用 GoRouter
- `/play` 路由返回时，正确回到 HomeScaffold（搜索/历史覆盖层仍保持原位）

## Acceptance Criteria

### AC-1: 搜索页面 → 返回键 → Feed
- **Given** 用户在首页点击顶部"搜索"按钮
- **When** 用户按系统返回键
- **Then** 回到首页 Feed 视图，不显示退出确认对话框
- **Verification**: 人工测试

### AC-2: 历史页面 → 返回键 → Feed
- **Given** 用户在首页点击顶部"历史"按钮
- **When** 用户按系统返回键
- **Then** 回到首页 Feed 视图，不显示退出确认对话框
- **Verification**: 人工测试

### AC-3: 搜索页面 → 视频播放页 → 返回键 → 搜索页 → 返回键 → Feed
- **Given** 用户在搜索页点击一个视频
- **And** 用户到达视频播放页
- **When** 用户按系统返回键（第一次）
- **Then** 回到搜索页面
- **When** 用户再按系统返回键（第二次）
- **Then** 回到首页 Feed 视图
- **Verification**: 人工测试

### AC-4: Feed → 返回键 → 退出确认
- **Given** 用户在首页 Feed（不在覆盖层页面）
- **When** 用户按系统返回键
- **Then** 显示"退出应用？"确认对话框
- **Verification**: 人工测试

### AC-5: 代码质量 - flutter analyze 通过
- **Given** 所有修改完成
- **When** 运行 `flutter analyze --no-pub lib`
- **Then** 无 error 级别问题
- **Verification**: CI/自动测试
