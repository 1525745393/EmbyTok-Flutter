# 移除画质偏好和自动降级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除视频画质偏好设置和自动降级功能，简化播放流程，固定使用 Direct Play

**Architecture:** 移除所有画质选择相关的 UI、Provider、偏好存储和降级逻辑，视频播放固定使用 Direct Play（level 0），Emby 上报固定使用 'DirectPlay'

**Tech Stack:** Flutter, Riverpod, SharedPreferences

---

## 文件结构

### 待修改文件

| 文件 | 职责 | 修改内容 |
|------|------|----------|
| `lib/providers/user_preferences_provider.dart` | 用户偏好 Provider | 删除 `VideoQualityNotifier`、`videoQualityProvider`、`AutoFallbackEnabledNotifier`、`autoFallbackEnabledProvider` |
| `lib/providers/video_playback_controller.dart` | 播放控制器 Provider | 删除 `PlaybackLevelNotifier`、`playbackLevelProvider`（或简化为常量） |
| `lib/utils/app_preferences.dart` | 偏好读写服务 | 删除 `videoQuality`、`autoFallbackEnabled` 字段及相关读写方法 |
| `lib/utils/constants.dart` | 全局常量 | 删除 `kStorageKeyVideoQuality`、`kStorageKeyAutoFallbackEnabled` |
| `lib/models/media_item.dart` | 媒体条目模型 | 删除 `playbackLevel` 字段 |
| `lib/views/settings_view.dart` | 设置页面 | 删除画质偏好 Tile 和对话框、自动降级开关 |
| `lib/views/fullscreen_video_page.dart` | 全屏播放页 | 删除画质设置面板 |
| `lib/widgets/video/video_control_buttons.dart` | 视频控制按钮 | 删除画质选择按钮 |
| `lib/widgets/video/video_sheet_utils.dart` | 视频弹窗工具 | 删除画质选择面板 |
| `lib/widgets/video_player_widget.dart` | 视频播放器组件 | 删除降级链逻辑、fallbackLevel、自动降级触发 |
| `lib/widgets/video_page_item.dart` | 视频页项 | 删除画质相关逻辑、preload startLevel |
| `lib/services/video_pool_service.dart` | 视频池服务 | 删除 startLevel 参数，固定使用 level 0 |

---

## Task 1: 删除 UserPreferences 中的画质偏好和自动降级 Provider

**Files:**
- Modify: `lib/providers/user_preferences_provider.dart`

- [ ] **Step 1: 删除 VideoQualityNotifier 和 videoQualityProvider**

```dart
// 删除以下代码块（第 57-79 行）：
// ---------------- 视频画质 ----------------

/// 视频画质：'original' / 'directStream' / 'hls'
class VideoQualityNotifier extends StateNotifier<String> {
  VideoQualityNotifier() : super('original') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.videoQuality;
  }

  Future<void> set(String quality) async {
    state = quality;
    await const AppPreferencesService().setVideoQuality(quality);
  }
}

/// 顶层视频画质 Provider
final videoQualityProvider =
    StateNotifierProvider<VideoQualityNotifier, String>(
        (ref) => VideoQualityNotifier());
```

- [ ] **Step 2: 删除 AutoFallbackEnabledNotifier 和 autoFallbackEnabledProvider**

```dart
// 删除以下代码块（第 81-102 行）：
// ---------------- 自动降级开关 ----------------

/// 是否启用自动降级（默认关闭）
class AutoFallbackEnabledNotifier extends StateNotifier<bool> {
  AutoFallbackEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await const AppPreferencesService().load();
    state = prefs.autoFallbackEnabled;
  }

  Future<void> set(bool value) async {
    state = value;
    await const AppPreferencesService().setAutoFallbackEnabled(value);
  }
}

final autoFallbackEnabledProvider =
    StateNotifierProvider<AutoFallbackEnabledNotifier, bool>(
        (ref) => AutoFallbackEnabledNotifier());
```

- [ ] **Step 3: 验证文件语法**

检查文件是否还有未使用的 import（`AppPreferencesService` 可能仍被其他 Notifier 使用），确认没有编译错误。

- [ ] **Step 4: Commit**

```bash
git add lib/providers/user_preferences_provider.dart
git commit -m "refactor: remove video quality and auto fallback providers"
```

---

## Task 2: 删除 PlaybackLevelNotifier

**Files:**
- Modify: `lib/providers/video_playback_controller.dart`

- [ ] **Step 1: 删除 PlaybackLevelNotifier 和 playbackLevelProvider**

```dart
// 删除以下代码块（第 60-78 行）：
/// 播放降级等级 Notifier：0=DirectPlay，1=DirectStream，2=HLS 转码
///
/// 等级越高代表越保守的播放策略，用于不同网速下的自适应降级。
class PlaybackLevelNotifier extends StateNotifier<int> {
  PlaybackLevelNotifier() : super(0);

  void setLevel(int level) {
    if (level >= 0 && level <= 2) state = level;
  }

  void reset() {
    state = 0;
  }
}

final playbackLevelProvider =
    StateNotifierProvider<PlaybackLevelNotifier, int>(
  (ref) => PlaybackLevelNotifier(),
);
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/video_playback_controller.dart
git commit -m "refactor: remove playbackLevelProvider"
```

---

## Task 3: 删除 AppPreferences 中的画质偏好和自动降级字段

**Files:**
- Modify: `lib/utils/app_preferences.dart`

- [ ] **Step 1: 删除 AppPreferences 构造函数中的 videoQuality 和 autoFallbackEnabled**

```dart
// 修改构造函数（约第 173-203 行）：
const AppPreferences({
  required this.forceDeviceMode,
  required this.feedType,
  required this.viewMode,
  required this.orientationMode,
  required this.isMuted,
  required this.isAutoPlay,
  required this.hiddenLibraryIds,
  required this.defaultPlaybackRate,
  required this.defaultSubtitleLanguage,
  // 删除以下两行：
  // required this.videoQuality,
  // required this.autoFallbackEnabled,
  required this.subtitleSize,
  ...
});
```

- [ ] **Step 2: 删除 videoQuality 和 autoFallbackEnabled 默认值**

```dart
// 修改默认构造函数（约第 180 行附近）：
// 删除：
// this.videoQuality = 'original',
// this.autoFallbackEnabled = false,
```

- [ ] **Step 3: 删除 copyWith 中的 videoQuality 和 autoFallbackEnabled**

```dart
// 修改 copyWith 方法（约第 205-261 行）：
// 删除以下参数：
// String? videoQuality,
// bool? autoFallbackEnabled,
// 删除以下赋值：
// videoQuality: videoQuality ?? this.videoQuality,
// autoFallbackEnabled: autoFallbackEnabled ?? this.autoFallbackEnabled,
```

- [ ] **Step 4: 删除 load() 中的 videoQuality 和 autoFallbackEnabled 读取**

```dart
// 修改 load() 方法（约第 308-314 行）：
// 删除：
// const validQualities = {'original', 'directStream', 'hls'};
// final rawQuality = prefs.getString(kStorageKeyVideoQuality) ?? 'original';
// final videoQuality = validQualities.contains(rawQuality) ? rawQuality : 'original';
// if (rawQuality != videoQuality) {
//   prefs.setString(kStorageKeyVideoQuality, videoQuality);
// }
// final autoFallbackEnabled = prefs.getBool(kStorageKeyAutoFallbackEnabled) ?? false;
```

- [ ] **Step 5: 删除 save() 中的 videoQuality 和 autoFallbackEnabled 写入**

```dart
// 修改 save() 方法：
// 删除：
// await prefs.setString(kStorageKeyVideoQuality, preferences.videoQuality);
// await prefs.setBool(kStorageKeyAutoFallbackEnabled, preferences.autoFallbackEnabled);
```

- [ ] **Step 6: 删除 setVideoQuality 和 setAutoFallbackEnabled 方法**

```dart
// 删除以下方法（约第 517-530 行）：
/// 单独更新视频画质
Future<void> setVideoQuality(String quality) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kStorageKeyVideoQuality, quality);
}

/// 单独更新自动降级开关
Future<void> setAutoFallbackEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kStorageKeyAutoFallbackEnabled, enabled);
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/utils/app_preferences.dart
git commit -m "refactor: remove video quality and auto fallback from AppPreferences"
```

---

## Task 4: 删除常量定义

**Files:**
- Modify: `lib/utils/constants.dart`

- [ ] **Step 1: 删除 kStorageKeyVideoQuality 和 kStorageKeyAutoFallbackEnabled**

```dart
// 删除以下两行（第 41-42 行）：
const String kStorageKeyVideoQuality = 'embbytok_video_quality';
const String kStorageKeyAutoFallbackEnabled = 'auto_fallback_enabled';
```

- [ ] **Step 2: Commit**

```bash
git add lib/utils/constants.dart
git commit -m "refactor: remove video quality and auto fallback constants"
```

---

## Task 5: 删除 MediaItem 中的 playbackLevel 字段

**Files:**
- Modify: `lib/models/media_item.dart`

- [ ] **Step 1: 删除 playbackLevel 字段定义**

```dart
// 删除第 42 行：
// final int playbackLevel;              // 当前播放降级等级：0=DirectPlay,1=DirectStream,2=HLS（瞬时字段，不参与序列化）
```

- [ ] **Step 2: 删除构造函数中的 playbackLevel**

```dart
// 修改构造函数（约第 73 行）：
// 删除：
// this.playbackLevel = 0,
```

- [ ] **Step 3: 删除 copyWith 中的 playbackLevel**

```dart
// 修改 copyWith 方法（约第 579-608 行）：
// 删除：
// int? playbackLevel,
// playbackLevel: playbackLevel ?? this.playbackLevel,
```

- [ ] **Step 4: Commit**

```bash
git add lib/models/media_item.dart
git commit -m "refactor: remove playbackLevel from MediaItem"
```

---

## Task 6: 删除设置页面中的画质偏好和自动降级 UI

**Files:**
- Modify: `lib/views/settings_view.dart`

- [ ] **Step 1: 删除 _buildVideoQualityTile 方法**

```dart
// 删除以下方法（约第 818-828 行）：
// 播放 - 画质偏好
Widget _buildVideoQualityTile(BuildContext context, WidgetRef ref) {
  final quality = ref.watch(videoQualityProvider);
  return _TapTile(
    icon: Icons.high_quality_outlined,
    iconColor: Colors.blue,
    title: '画质偏好',
    subtitle: _videoQualityLabel(quality),
    onTap: () => _showVideoQualityDialog(context, ref, quality),
  );
}
```

- [ ] **Step 2: 删除 _buildAutoFallbackTile 方法**

```dart
// 删除以下方法（约第 830-845 行）：
// 播放 - 自动降级
Widget _buildAutoFallbackTile(BuildContext context, WidgetRef ref) {
  final enabled = ref.watch(autoFallbackEnabledProvider);
  return _SwitchTile(
    icon: Icons.auto_graph_outlined,
    iconColor: Colors.orange,
    title: '自动降级',
    subtitle: enabled
        ? '播放失败时自动降低画质重试'
        : '关闭：播放失败需手动切换画质',
    value: enabled,
    onChanged: (value) {
      ref.read(autoFallbackEnabledProvider.notifier).set(value);
    },
  );
}
```

- [ ] **Step 3: 删除 _showVideoQualityDialog 方法和 _videoQualityLabel 方法**

```dart
// 删除 _showVideoQualityDialog 方法及其相关代码
// 删除 _videoQualityLabel 方法（约第 2890-2891 行）：
String _videoQualityLabel(String quality) {
  switch (quality) {
    ...
  }
}
```

- [ ] **Step 4: 删除 videoQualityProvider 和 autoFallbackEnabledProvider 的 import**

```dart
// 检查文件顶部 import，删除：
// import '../providers/user_preferences_provider.dart' show videoQualityProvider, autoFallbackEnabledProvider;
```

- [ ] **Step 5: 删除 build 方法中对这些 Tile 的调用**

搜索 `_buildVideoQualityTile` 和 `_buildAutoFallbackTile` 在 build 中的调用位置并删除。

- [ ] **Step 6: Commit**

```bash
git add lib/views/settings_view.dart
git commit -m "refactor: remove video quality and auto fallback UI from settings"
```

---

## Task 7: 删除全屏播放页中的画质设置面板

**Files:**
- Modify: `lib/views/fullscreen_video_page.dart`

- [ ] **Step 1: 删除 _buildQualityList 方法**

```dart
// 删除以下方法（约第 1365-1386 行）：
Widget _buildQualityList() {
  final currentLevel = ref.watch(playbackLevelProvider);
  const qualities = [
    _QualityOption(0, '原画画质', 'Direct Play'),
    _QualityOption(1, '高清 Remux', 'Direct Stream'),
    _QualityOption(2, '流畅转码', 'HLS'),
  ];
  return Column(
    children: qualities.map((q) {
      final selected = q.level == currentLevel;
      return _SettingsListItem(
        label: q.label,
        subtitle: q.desc,
        selected: selected,
        onTap: () {
          ref.read(playbackLevelProvider.notifier).setLevel(q.level);
          _startHideTimer();
        },
      );
    }).toList(),
  );
}
```

- [ ] **Step 2: 删除 _QualityOption 类**

```dart
// 删除 _QualityOption 类定义（如果存在）
```

- [ ] **Step 3: 删除 settings panel 中对 _buildQualityList 的调用**

搜索 `_SettingsTab.quality` 和 `_buildQualityList` 的使用位置并删除。

- [ ] **Step 4: 删除 playbackLevelProvider 的 import**

```dart
// 删除：
// import '../providers/video_playback_controller.dart' show playbackLevelProvider;
```

- [ ] **Step 5: 删除 ref.listen(playbackLevelProvider) 监听器**

搜索并删除：
```dart
ref.listen<int>(playbackLevelProvider, (previous, next) {
  ...
});
```

- [ ] **Step 6: Commit**

```bash
git add lib/views/fullscreen_video_page.dart
git commit -m "refactor: remove quality settings panel from fullscreen page"
```

---

## Task 8: 删除视频控制按钮中的画质选择按钮

**Files:**
- Modify: `lib/widgets/video/video_control_buttons.dart`

- [ ] **Step 1: 删除画质选择按钮相关代码**

搜索并删除 `playbackLevelProvider` 的使用、画质按钮 Widget、`showQualityPanel` 方法等。

- [ ] **Step 2: 删除 playbackLevelProvider 的 import**

```dart
// 删除：
// import '../../providers/video_playback_controller.dart' show playbackLevelProvider;
```

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/video/video_control_buttons.dart
git commit -m "refactor: remove quality selection button from video controls"
```

---

## Task 9: 删除视频弹窗工具中的画质选择面板

**Files:**
- Modify: `lib/widgets/video/video_sheet_utils.dart`

- [ ] **Step 1: 删除画质选择面板相关代码**

搜索并删除 `qualityOptions`、`showQualityPanel`、`playbackLevelProvider` 的使用。

- [ ] **Step 2: 删除 playbackLevelProvider 的 import**

```dart
// 删除：
// import '../../providers/video_playback_controller.dart' show playbackLevelProvider;
```

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/video/video_sheet_utils.dart
git commit -m "refactor: remove quality panel from video sheet utils"
```

---

## Task 10: 删除视频播放器组件中的降级逻辑

**Files:**
- Modify: `lib/widgets/video_player_widget.dart`

- [ ] **Step 1: 删除降级相关字段**

```dart
// 删除以下字段（约第 69-80 行）：
// 降级链等级：0=Direct Play, 1=Direct Stream, 2=HLS
// 仅在动态创建路径（路径2）使用降级，预加载路径不降级
int _fallbackLevel = 0;
int _initialFallbackLevel = 0;
// 标记当前正在执行降级（避免 listener 与 initVideo 递归调用导致的重复降级）
bool _isFallbackInProgress = false;
// 标记是否正在执行用户发起的播放模式切换（区别于自动降级）
bool _isUserSwitchInProgress = false;
// 降级延迟计时器（网络错误时延迟重试，避免资源风暴）
Timer? _fallbackTimer;
```

- [ ] **Step 2: 删除降级相关方法**

```dart
// 删除：_qualityToLevel(), _getInitialFallbackLevel(), _isAutoFallbackEnabled()
// 删除：_onControllerChanged() 中的降级逻辑
// 删除：_handlePlaybackFallback(), _handleRuntimeFallback()
```

- [ ] **Step 3: 简化 initVideo 方法，移除降级逻辑**

修改 `initVideo` 方法，固定使用 Direct Play URL，移除所有 fallback 相关代码。

- [ ] **Step 4: 删除 videoQualityProvider 和 autoFallbackEnabledProvider 的 import**

```dart
// 删除：
// import '../providers/user_preferences_provider.dart' show videoQualityProvider, autoFallbackEnabledProvider;
// import '../providers/video_playback_controller.dart' show playbackLevelProvider;
```

- [ ] **Step 5: 删除 ref.read(playbackLevelProvider.notifier).setLevel() 调用**

搜索并删除所有对 `playbackLevelProvider` 的调用。

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/video_player_widget.dart
git commit -m "refactor: remove video fallback logic from VideoPlayerWidget"
```

---

## Task 11: 删除视频页项中的画质相关逻辑

**Files:**
- Modify: `lib/widgets/video_page_item.dart`

- [ ] **Step 1: 删除画质相关逻辑**

搜索并删除：
- `videoQualityProvider` 的使用
- `playbackLevelProvider` 的使用
- `preloadedPlaybackLevel` 的传递
- `startLevel` 的计算和传递

- [ ] **Step 2: 删除相关 import**

```dart
// 删除：
// import '../providers/user_preferences_provider.dart' show videoQualityProvider;
// import '../providers/video_playback_controller.dart' show playbackLevelProvider;
```

- [ ] **Step 3: 简化 preload 调用，移除 startLevel 参数**

```dart
// 修改：
// await pool.preload(item: it, serverUrl: serverUrl, token: token, startLevel: startLevel);
// 改为：
// await pool.preload(item: it, serverUrl: serverUrl, token: token);
```

- [ ] **Step 4: 删除 _playMethodFromLevel 方法**

```dart
// 删除：
String _playMethodFromLevel(int level) {
  switch (level) {
    case 0: return 'DirectPlay';
    case 1: return 'DirectStream';
    case 2: return 'Transcode';
  }
}
```

- [ ] **Step 5: 固定 PlayMethod 为 'DirectPlay'**

搜索 `_playMethodFromLevel` 或 `playbackLevel` 的使用位置，替换为固定的 `'DirectPlay'`。

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/video_page_item.dart
git commit -m "refactor: remove video quality logic from VideoPageItem"
```

---

## Task 12: 删除视频池服务中的 startLevel 参数

**Files:**
- Modify: `lib/services/video_pool_service.dart`

- [ ] **Step 1: 删除 preload 方法中的 startLevel 参数**

```dart
// 修改：
Future<PlaybackSession?> preload({
  required MediaItem item,
  required String serverUrl,
  required String token,
  int startLevel = 0,  // 删除此行
}) async {
```

- [ ] **Step 2: 简化降级链逻辑，固定使用 level 0**

修改预加载逻辑，移除两轮降级尝试，只使用 level 0（Direct Play）。

- [ ] **Step 3: Commit**

```bash
git add lib/services/video_pool_service.dart
git commit -m "refactor: remove startLevel from VideoPoolService preload"
```

---

## Task 13: 更新 PlaybackSession 相关代码

**Files:**
- Modify: `lib/services/video_pool_service.dart`
- Modify: `lib/widgets/video_page_item.dart`

- [ ] **Step 1: 删除 PlaybackSession 中的 playbackLevel 字段**

```dart
// 修改 PlaybackSession 类定义，删除 playbackLevel 字段
```

- [ ] **Step 2: 更新所有使用 playbackLevel 的位置**

搜索 `playbackLevel` 的使用，删除或替换为固定值 0。

- [ ] **Step 3: Commit**

```bash
git add lib/services/video_pool_service.dart lib/widgets/video_page_item.dart
git commit -m "refactor: remove playbackLevel from PlaybackSession"
```

---

## Task 14: 全局搜索并清理残留引用

**Files:**
- Search: `playbackLevelProvider`, `videoQualityProvider`, `autoFallbackEnabledProvider`, `kStorageKeyVideoQuality`, `kStorageKeyAutoFallbackEnabled`, `startLevel`, `fallbackLevel`, `_playMethodFromLevel`

- [ ] **Step 1: 全局搜索残留引用**

```bash
grep -r "playbackLevelProvider\|videoQualityProvider\|autoFallbackEnabledProvider\|kStorageKeyVideoQuality\|kStorageKeyAutoFallbackEnabled\|startLevel\|fallbackLevel\|_playMethodFromLevel" lib/ --include="*.dart"
```

- [ ] **Step 2: 清理所有残留引用**

根据搜索结果，逐一清理所有未删除的引用。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: cleanup remaining quality/fallback references"
```

---

## Task 15: 运行测试验证

**Files:**
- Test: `test/`

- [ ] **Step 1: 运行单元测试**

```bash
cd frontend
flutter test
```

- [ ] **Step 2: 修复测试失败**

如果有测试失败，根据错误信息修复代码。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: fix tests after removing quality/fallback features"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ 删除画质偏好 Provider（videoQualityProvider）
- ✅ 删除自动降级 Provider（autoFallbackEnabledProvider）
- ✅ 删除 PlaybackLevelNotifier（playbackLevelProvider）
- ✅ 删除 AppPreferences 中的相关字段
- ✅ 删除 SharedPreferences 存储键
- ✅ 删除设置页面 UI
- ✅ 删除全屏页面画质面板
- ✅ 删除视频控制按钮中的画质按钮
- ✅ 删除视频弹窗工具中的画质面板
- ✅ 删除视频播放器组件中的降级逻辑
- ✅ 删除视频页项中的画质相关逻辑
- ✅ 删除视频池服务中的 startLevel 参数
- ✅ 固定 PlayMethod 为 DirectPlay

**2. Placeholder scan:**
- 无占位符，所有步骤包含具体代码

**3. Type consistency:**
- 所有删除的字段和方法在后续任务中不再引用

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-remove-quality-preferences-and-auto-fallback.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**