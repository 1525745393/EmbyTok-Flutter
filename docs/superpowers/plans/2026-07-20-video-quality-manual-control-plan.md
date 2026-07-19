# 视频降级手动控制 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现视频画质手动控制：设置页可开关自动降级、设置默认画质，小屏可快速切换画质

**Architecture:** 
- 复用现有的 `videoQuality` 字段（改值为 original/directStream/hls）+ `videoQualityProvider`
- 新增 `autoFallbackEnabled` 字段 + provider 控制自动降级开关
- `VideoPlayerWidget` / `VideoPoolService` 初始化时读取默认画质
- 小屏右侧按钮列加画质按钮，点击弹出选择面板

**Tech Stack:** Flutter, Riverpod, shared_preferences, video_player (media_kit)

---

## 文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/utils/constants.dart` | 修改 | 新增 storage key 常量 |
| `lib/utils/app_preferences.dart` | 修改 | 新增 `autoFallbackEnabled` 字段 + 改 `videoQuality` 默认值 |
| `lib/providers/user_preferences_provider.dart` | 修改 | 新增 `autoFallbackEnabledProvider` + 改 `videoQualityProvider` 默认值 |
| `lib/views/settings_view.dart` | 修改 | 更新画质偏好选项 + 新增自动降级开关 |
| `lib/widgets/video_player_widget.dart` | 修改 | 初始化用默认画质 + 自动降级开关 |
| `lib/services/video_pool_service.dart` | 修改 | 预加载用默认画质 |
| `lib/widgets/video_page_item.dart` | 修改 | 右侧加画质按钮 |
| `lib/utils/sheet_utils.dart` | 修改 | 新增画质选择底部面板 |

---

### Task 1: 数据层 — 新增 autoFallbackEnabled + 调整 videoQuality

**Files:**
- Modify: `lib/utils/constants.dart`
- Modify: `lib/utils/app_preferences.dart`
- Modify: `lib/providers/user_preferences_provider.dart`

- [ ] **Step 1: 在 constants.dart 中新增 storage key 常量**

在现有 storage key 附近添加：
```dart
static const String kStorageKeyAutoFallbackEnabled = 'auto_fallback_enabled';
```

- [ ] **Step 2: 修改 AppPreferences，新增 autoFallbackEnabled 字段**

在 `AppPreferences` 类中：
1. 加字段：`final bool autoFallbackEnabled;`（放在 `videoQuality` 附近）
2. 构造函数加默认值：`this.autoFallbackEnabled = false,`
3. `copyWith` 加参数
4. `AppPreferencesService.load()` 中读取：`prefs.getBool(kStorageKeyAutoFallbackEnabled) ?? false`
5. `AppPreferencesService.save()` 中保存
6. `resetAllSettings()` 的 `keysToRemove` 列表中加入 `kStorageKeyAutoFallbackEnabled`

- [ ] **Step 3: 调整 videoQuality 默认值（从 auto 改为 original）**

`AppPreferences` 中：
- 默认值从 `'auto'` 改为 `'original'`
- `load()` 中 fallback 从 `'auto'` 改为 `'original'`

`VideoQualityNotifier` 中：
- 初始值从 `'auto'` 改为 `'original'`

> 注意：老用户升级后，SharedPreferences 里存的还是 `'auto'`，所以第一次读取到的是 `'auto'`。需要在加载时做一次迁移：如果读到的值不在新的有效值列表中（original/directStream/hls），就重置为 `'original'`。

- [ ] **Step 4: 新增 autoFallbackEnabledProvider**

在 `user_preferences_provider.dart` 中新增：
```dart
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
    // 单独保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStorageKeyAutoFallbackEnabled, value);
  }
}

final autoFallbackEnabledProvider =
    StateNotifierProvider<AutoFallbackEnabledNotifier, bool>(
        (ref) => AutoFallbackEnabledNotifier());
```
需要 import `package:shared_preferences/shared_preferences.dart` 和 `constants.dart`。

- [ ] **Step 5: 验证编译通过**

在 `frontend/` 目录运行：
```bash
flutter analyze lib/utils/ lib/providers/
```
预期：无新增错误

- [ ] **Step 6: 提交**

```bash
git add lib/utils/constants.dart lib/utils/app_preferences.dart lib/providers/user_preferences_provider.dart
git commit -m "feat: 新增自动降级开关 + 调整默认画质

- 新增 autoFallbackEnabled 字段及 Provider（默认关闭）
- videoQuality 默认值从 auto 改为 original
- 老用户值迁移：无效值重置为 original"
```

---

### Task 2: 设置页 — 更新画质选项 + 新增自动降级开关

**Files:**
- Modify: `lib/views/settings_view.dart`

- [ ] **Step 1: 更新 _videoQualityLabel**

将 `_videoQualityLabel` 方法改为：
```dart
String _videoQualityLabel(String quality) {
  switch (quality) {
    case 'original':
      return '原画（Direct Play）';
    case 'directStream':
      return '高清 Remux（Direct Stream）';
    case 'hls':
      return '流畅转码（HLS）';
    default:
      return '原画（Direct Play）';
  }
}
```

- [ ] **Step 2: 更新 _showVideoQualityDialog 选项**

将 `_showVideoQualityDialog` 中的 options 改为：
```dart
options: const [
  ('原画（Direct Play）', 'original'),
  ('高清 Remux（Direct Stream）', 'directStream'),
  ('流畅转码（HLS）', 'hls'),
],
```

- [ ] **Step 3: 在画质偏好下面加"自动降级"开关**

找到"画质偏好"那一项（ListTile），在它下面加一个 SwitchListTile：
```dart
SwitchListTile(
  title: Text('自动降级', style: TextStyle(color: scheme.onSurface)),
  subtitle: Text(
    '播放失败时自动降低画质',
    style: TextStyle(color: scheme.onSurfaceVariant),
  ),
  value: ref.watch(autoFallbackEnabledProvider),
  onChanged: (v) =>
      ref.read(autoFallbackEnabledProvider.notifier).set(v),
  activeColor: scheme.primary,
),
```

放在"画质偏好"和"字幕大小"之间。

- [ ] **Step 4: 验证编译通过**

```bash
flutter analyze lib/views/settings_view.dart
```
预期：无新增错误

- [ ] **Step 5: 提交**

```bash
git add lib/views/settings_view.dart
git commit -m "feat: 设置页更新画质选项 + 新增自动降级开关

- 画质选项改为 原画/高清Remux/流畅转码
- 新增自动降级开关（默认关闭）"
```

---

### Task 3: VideoPlayerWidget — 接入默认画质 + 自动降级开关

**Files:**
- Modify: `lib/widgets/video_player_widget.dart`

- [ ] **Step 1: _fallbackLevel 初始值改为读取默认画质设置**

在 `_VideoPlayerWidgetState` 中，`_fallbackLevel` 不再硬编码为 0，而是：
1. 加一个 late 初始化：`late int _fallbackLevel;`
2. 在 `initState` 中读取 `videoQualityProvider` 的值，映射为 level：
   - `'original'` → 0
   - `'directStream'` → 1
   - `'hls'` → 2
   - 默认 → 0

```dart
@override
void initState() {
  super.initState();
  // 读取默认画质
  final quality = ProviderContainer().read(videoQualityProvider);
  _fallbackLevel = _qualityToLevel(quality);
  // ... 原有代码
}

int _qualityToLevel(String quality) {
  switch (quality) {
    case 'directStream':
      return 1;
    case 'hls':
      return 2;
    case 'original':
    default:
      return 0;
  }
}
```

> 注意：Riverpod 在 StatefulWidget 中读 provider 不能直接用 ref，需要用 `WidgetsBinding.instance.addPostFrameCallback` 或者在 `initState` 中通过 context 读。更好的做法是用 ConsumerStatefulWidget。
> 
> 检查当前 VideoPlayerWidget 是 StatefulWidget 还是 ConsumerStatefulWidget。
> 如果是 ConsumerStatefulWidget，直接 `ref.read(videoQualityProvider)`。
> 如果是 StatefulWidget，保持 `_fallbackLevel = 0` 初始化，然后在 `didChangeDependencies` 中更新。

实际做法：
- VideoPlayerWidget 已经是 `ConsumerStatefulWidget`（用了 ref）
- 所以直接在 `initState` 中用 `ref.read(videoQualityProvider)` 读初始值

- [ ] **Step 2: 自动降级开关检查**

找到两处自动降级触发点：
1. 初始化失败时的降级（`_initVideo` 中的 catch）
2. 运行时降级（`_triggerRuntimeFallback`）

在降级前检查 `autoFallbackEnabledProvider`：
```dart
final autoFallback = ref.read(autoFallbackEnabledProvider);
if (!autoFallback) {
  // 不自动降级，直接显示错误
  if (mounted) {
    setState(() {
      _errorMessage = '播放失败，请手动切换画质';
      _isBuffering = false;
    });
  }
  return;
}
```

两处都要加这个检查。

- [ ] **Step 3: 验证编译通过**

```bash
flutter analyze lib/widgets/video_player_widget.dart
```
预期：无新增错误

- [ ] **Step 4: 提交**

```bash
git add lib/widgets/video_player_widget.dart
git commit -m "feat: VideoPlayerWidget 接入默认画质 + 自动降级开关

- 初始化时读取默认画质设置
- 关闭自动降级时播放失败不自动降级"
```

---

### Task 4: VideoPoolService — 预加载用默认画质

**Files:**
- Modify: `lib/services/video_pool_service.dart`

- [ ] **Step 1: 预加载初始 level 读取默认画质**

找到 `VideoPoolService` 中创建 controller / 预加载的地方，将初始 fallbackLevel 从硬编码 0 改为读取 `videoQualityProvider`。

VideoPoolService 可能用的是 `ProviderContainer` 或 `ref`，需要看具体实现。
如果是在 `StateNotifier` 里，用 `ref.read(videoQualityProvider)`。
如果是独立 service，可能需要传参或用静态方法读。

实际处理方式：
- 在 `_createControllerForItem` 或类似方法中，加一个 `initialLevel` 参数
- 调用方传入默认画质对应的 level

- [ ] **Step 2: 验证编译通过**

```bash
flutter analyze lib/services/video_pool_service.dart
```
预期：无新增错误

- [ ] **Step 3: 提交**

```bash
git add lib/services/video_pool_service.dart
git commit -m "feat: VideoPoolService 预加载用默认画质"
```

---

### Task 5: sheet_utils — 新增画质选择面板

**Files:**
- Modify: `lib/utils/sheet_utils.dart`

- [ ] **Step 1: 新增 showQualitySelector 方法**

在 `sheet_utils.dart` 中新增底部弹出面板方法：
```dart
/// 显示画质选择面板
void showQualitySelector(
  BuildContext context,
  String currentQuality, {
  required void Function(String quality) onSelect,
}) {
  final scheme = Theme.of(context).colorScheme;

  final options = const [
    ('原画（Direct Play）', 'original'),
    ('高清 Remux（Direct Stream）', 'directStream'),
    ('流畅转码（HLS）', 'hls'),
  ];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '画质选择',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 1),
            // 选项列表
            ...options.map((opt) {
              final isSelected = opt.$2 == currentQuality;
              return ListTile(
                title: Text(
                  opt.$1,
                  style: TextStyle(
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(opt.$2);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
```

- [ ] **Step 2: 验证编译通过**

```bash
flutter analyze lib/utils/sheet_utils.dart
```
预期：无新增错误

- [ ] **Step 3: 提交**

```bash
git add lib/utils/sheet_utils.dart
git commit -m "feat: 新增画质选择底部面板"
```

---

### Task 6: VideoPageItem — 右侧加画质按钮

**Files:**
- Modify: `lib/widgets/video_page_item.dart`

- [ ] **Step 1: 右侧按钮列加画质按钮**

找到右侧按钮列（`PressableActionButton` 列表，大概在 930-990 行之间），
在倍速按钮（`SpeedControlButton`）附近加一个画质按钮。

按钮样式用 `PressableActionButton`，和其他按钮风格一致：
```dart
PressableActionButton(
  icon: Icons.hd,
  label: _qualityLabel(ref.watch(videoQualityProvider)),
  color: scheme.onSurface,
  onTap: () {
    sheet_utils.showQualitySelector(
      context,
      ref.read(videoQualityProvider),
      onSelect: (quality) {
        ref.read(videoQualityProvider.notifier).set(quality);
        // 切换当前视频画质
        // 需要通过 VideoPlayerWidget 的外部方法或 playbackLevelProvider
      },
    );
  },
),
```

加一个 helper 方法：
```dart
String _qualityLabel(String quality) {
  switch (quality) {
    case 'directStream':
      return '高清';
    case 'hls':
      return '流畅';
    case 'original':
    default:
      return '原画';
  }
}
```

- [ ] **Step 2: 实现画质切换到当前视频**

用户选择画质后，需要立即切换当前正在播放的视频，而不只是改全局设置。

方案：通过 `playbackLevelProvider` 触发，或者给 `VideoPlayerWidget` 加一个外部切换方法。

检查当前 `playbackLevelProvider` 的实现 — 它是 `StateProvider<int>`，
`VideoPlayerWidget` 内部是否监听了这个 provider 的变化来切换画质？

如果 `playbackLevelProvider` 已经能触发切换（通过 `_userInitiatedReinit`），
那就直接：
```dart
final level = _qualityToLevel(quality);
ref.read(playbackLevelProvider.notifier).state = level;
```

如果不能，需要：
1. 给 `VideoPlayerWidget` 加一个 `GlobalKey`
2. 或者用 `ValueNotifier` 方式
3. 或者在 `didUpdateWidget` 中监听

> 实际做法：检查现有 `playbackLevelProvider` 是否被 VideoPlayerWidget 监听。
> 如果 FullscreenVideoPage 能通过 playbackLevelProvider 触发切换，
> 那小屏应该也能用同样的方式。

- [ ] **Step 3: 验证编译通过**

```bash
flutter analyze lib/widgets/video_page_item.dart
```
预期：无新增错误

- [ ] **Step 4: 提交**

```bash
git add lib/widgets/video_page_item.dart
git commit -m "feat: 小屏右侧加画质切换按钮"
```

---

### Task 7: 集成测试 + 修复

- [ ] **Step 1: 全量 analyze**

```bash
cd frontend
flutter analyze
```
预期：无错误

- [ ] **Step 2: 手动测试清单**
  - [ ] 设置页能开关自动降级
  - [ ] 设置页能选默认画质
  - [ ] 重启应用后设置保留
  - [ ] 新视频用默认画质播放
  - [ ] 关闭自动降级时，播放失败不自动降级
  - [ ] 小屏右侧有画质按钮
  - [ ] 点击能切换画质
  - [ ] 切换画质保留进度
  - [ ] 全屏页画质切换正常工作

- [ ] **Step 3: 修复发现的问题**

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "fix: 修复集成测试发现的问题"
```
