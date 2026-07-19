# 视频降级手动控制设计文档

**状态**: Draft  
**创建日期**: 2026-07-20  
**目标版本**: 1.x  
**范围**: 播放模块

## 背景

当前视频播放有三级自动降级链（Direct Play → Direct Stream → HLS），播放失败时自动降级。但用户无法主动控制画质，只能被动等待自动降级。需要增加：
1. 用户可手动切换画质（已有基础功能，需完善）
2. 自动降级可开关（默认关闭）
3. 默认画质可设置
4. 小屏也能快速切换画质

## 目标

1. 用户可在设置中开启/关闭自动降级（默认关闭）
2. 用户可设置默认画质（原画/高清Remux/流畅转码）
3. 新视频用默认画质初始化
4. 小屏右侧按钮列加画质切换入口
5. 切换画质保留播放进度（已有）

## 非目标

- 不做按视频记住用户选择（全局默认即可，每个视频单独存太复杂）
- 不做更细的分辨率档位（保持 3 级）
- 不做预加载画质差异化（预加载也用默认画质）

## 设计

### 架构图

```
┌─────────────────────────────────────────────────────┐
│  设置页 SettingsView                                 │
│  - 自动降级开关 开关                                │
│  - 默认画质 选择（原画/高清/流畅）                │
│  → 写入 AppPreferences / UserPreferencesNotifier  │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│  user_preferences_provider.dart                   │
│  - autoFallbackEnabled: bool (默认 false)        │
│  - defaultPlaybackLevel: int (默认 0=原画)       │
└─────────────────────────────────────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
┌──────────────────────┐        ┌──────────────────────┐
│ VideoPlayerWidget   │        │ VideoPageItem    │
│ - 初始化时用默认画质│        │ - 右侧按钮列加  │
│ - 自动降级开关控制 │        │   画质按钮      │
│   _triggerRuntime   │        │ - 点击弹出画质  │
│   Fallback 是否执行│        │   选择面板      │
└──────────────────────┘        └──────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ FullscreenVideoPage     │
│ - 设置面板已有画质切换   │
│ - 保持不变              │
└──────────────────────────────┘
```

### 数据模型

#### AppPreferences 新增字段

```dart
class AppPreferences {
  // ... 现有字段 ...
  
  // 新增：是否启用自动降级（默认 false）
  final bool autoFallbackEnabled;
  
  // 新增：默认播放画质（0=原画, 1=高清Remux, 2=流畅转码）
  final int defaultPlaybackLevel;
}
```

#### user_preferences_provider.dart 新增 Notifier

```dart
/// 是否启用自动降级
class AutoFallbackNotifier extends StateNotifier<bool> {
  // 默认 false
}

/// 默认播放画质
class DefaultPlaybackLevelNotifier extends StateNotifier<int> {
  // 默认 0（原画）
}
```

### 核心改动清单

#### 1. AppPreferencesService
- 新增 `autoFallbackEnabled` 字段（默认 false）
- 新增 `defaultPlaybackLevel` 字段（默认 0）
- `fromJson / toJson / copyWith 同步更新

#### 2. user_preferences_provider.dart
- 新增 `autoFallbackEnabledProvider`（StateNotifierProvider）
- 新增 `defaultPlaybackLevelProvider`（StateNotifierProvider）
- 从 AppPreferences 加载，变更后持久化

#### 3. video_player_widget.dart + video_pool_service.dart
- `VideoPlayerWidget._initVideo` 时读取 `defaultPlaybackLevelProvider` 的值作为 `_fallbackLevel` 初始值
- `VideoPoolService` 预加载时也用 `defaultPlaybackLevel` 作为初始等级
- `_triggerRuntimeFallback` 和初始化失败降级时检查 `autoFallbackEnabled`
  - 若关闭：直接显示错误，不降级
  - 若开启：执行现有降级逻辑
- `_userInitiatedReinit` 保持不变（手动切换不受影响）

#### 4. video_page_item.dart
- 右侧按钮列加一个 `QualityButton`（和倍速/字幕按钮同风格）
- 点击弹出底部面板，3 个选项：原画/高清Remux/流畅转码
- 当前选中项高亮
- 切换后立即生效（复用 `VideoPlayerWidget` 的外部方法或通过 `playbackLevelProvider` 触发）

#### 5. settings_view.dart
- "播放设置"分组加两项：
  1. 自动降级（Switch，默认关）
  2. 默认画质（选择项，原画/高清Remux/流畅转码）

### 小屏画质按钮设计

**位置**：右侧按钮列，倍速按钮和字幕按钮之间（或之后）

**样式**：和现有 `SpeedControlButton` 风格一致
- 图标：`Icons.hd` 或 `Icons.settings_rounded`
- 文字：当前画质简称（"原画"/"高清"/"流畅"）
- 点击弹出底部选择面板（和倍速面板类似）

**面板内容**：
- 原画（Direct Play）
- 高清 Remux（Direct Stream）
- 流畅转码（HLS）
- 当前选中项打钩

### 错误处理

- 切换画质失败：
  - 保持当前画质不变
  - 显示 Snackbar 提示"切换失败"
  - （现有逻辑已包含，复用即可）

- 自动降级关闭时播放失败：
  - 显示错误占位（现有）
  - 错误按钮改为"切换画质"而不是"重试"
  - 用户手动选择其他画质

### 向后兼容

- 老用户升级后默认画质 = 原画（和现有行为一致，原来就是从原画开始）
- 老用户升级后自动降级 = 关闭（行为变更，但原来默认是开的，现在默认关）

## 实施计划

| 阶段 | 内容 | 预估工作量 |
|------|------|-----------|
| 1 | 数据层：AppPreferences + Provider | 小 |
| 2 | 设置页：自动降级开关 + 默认画质选择 | 小 |
| 3 | VideoPlayerWidget：接入默认画质 + 自动降级开关 | 中 |
| 4 | VideoPageItem：小屏画质按钮 + 面板 | 中 |
| 5 | 测试 + 修复 | 小 |

## 测试清单

- [ ] 设置页能开关自动降级
- [ ] 设置页能选默认画质
- [ ] 新视频用默认画质播放
- [ ] 关闭自动降级时，播放失败不自动降级
- [ ] 开启自动降级时，播放失败自动降级
- [ ] 小屏右侧有画质按钮
- [ ] 点击能切换画质
- [ ] 切换画质保留进度
- [ ] 切换失败有错误提示
- [ ] 全屏页画质切换正常工作
- [ ] 设置持久化（重启后保留）
