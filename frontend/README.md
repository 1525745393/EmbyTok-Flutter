# EmbyTok Flutter — 前端开发指南

> 本目录为 Flutter 客户端源码，负责 UI 层、状态管理与播放控制。

---

## Flutter SDK 版本要求

```yaml
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"
```

- **Dart 3.x**：启用 null safety / patterns / records
- **Flutter 3.x**：Material Design 3 + 全平台支持

---

## 安装依赖

```bash
cd frontend
flutter clean
flutter pub get
flutter analyze           # 静态检查
flutter test              # 运行单元测试
```

---

## pubspec.yaml 依赖说明

| 依赖 | 用途 |
| --- | --- |
| `flutter_riverpod: ^2.5.0` | 状态管理（ProviderScope + StateNotifier） |
| `go_router: ^13.0.0` | 声明式路由（可选项，便于后续扩展） |
| `dio: ^5.4.0` | 高性能 HTTP 客户端 |
| `shared_preferences: ^2.2.0` | 本地 K/V 持久化（历史、设置） |
| `cached_network_image: ^3.3.0` | 缩略图缓存与加载占位 |
| `intl: ^0.19.0` | 日期 / 数字格式化 |
| `connectivity_plus: ^5.0.0` | 网络状态监听 |
| `video_player: ^2.8.0` | 全平台视频播放器 |

---

## 架构设计原则

本项目遵循 **分层单一职责** 原则，目录组织为：

```
lib/
├── models/        ← 纯数据类（不可变 + fromJson / toJson）
├── services/      ← 外部服务（Embytok API）
├── providers/     ← 状态管理（Riverpod StateNotifier）
├── widgets/       ← 可复用 UI 组件
├── views/         ← 完整页面（组合 widget）
└── utils/         ← 工具：常量、格式化等
```

**依赖方向必须单向：**

```
views → widgets
  ↓     ↘
  └── providers → services → models
  ↓              ↑
utils ───────────┘
```

- 禁止 `widgets` 直接调用 `services`：必须通过 `providers` 中转
- `models` 为纯数据层，不得引用任何 Flutter / Riverpod API
- `utils` 禁止持有可变状态，仅提供纯函数与常量
- `views` / `widgets` 使用 `ConsumerWidget` 或 `Consumer` 订阅状态

---

## Riverpod Provider 依赖图

```
authProvider (根状态：用户 / 服务地址 / Token)
   │
   ├── library_provider ── 加载可用媒体库
   │
   ├── video_list_provider ── 当前选中库的分页视频流
   │
   ├── search_provider ── 搜索查询 & 结果分页
   │
   ├── favorites_provider ── 收藏集合 & isFavorite 查询
   │
   ├── watch_history_provider ── 本地历史（不依赖 auth）
   │
   ├── theme_provider ── 主题模式（system / dark / light）
   │
   ├── subtitle_settings_provider ── 字幕语言 / 字号 / 颜色 / 位置
   │
   ├── user_preferences_provider ── 默认倍速 / 默认字幕语言 / 缓存大小
   │
   └── search_history_provider ── 搜索关键词历史
```

> 每个 Provider 声明位置：`lib/providers/<name>_provider.dart`，统一通过 `providers/providers.dart` 导出。

**使用模式：**

```dart
// 读取（不订阅）
ref.read(favoritesProvider.notifier).toggleFavorite(item);

// 订阅（响应状态变化）
final state = ref.watch(favoritesProvider);

// 异步 Future 加载
load() async {
  try {
    await ref.read(favoritesProvider.notifier).loadFavorites();
  } catch (e) {
    if (mounted) showErrorSnackbar(context, '加载失败：$e');
  }
}
```

---

## 代码规范

### 命名约定

- **Widget / Class / Enum**：`UpperCamelCase`（`VideoPageItem`、`FavoritesNotifier`）
- **File / Directory**：`snake_case`（`search_view.dart`、`video_playback_controller.dart`）
- **Provider 名称**：`xxxProvider`（小写开头，驼峰）
- **常量**：`kCamelCase` 前缀（`kDefaultPageLimit`、`kDebounceMs`）

### Widget 拆分粒度

每个 Widget 文件中最多存在 **一个 Public Widget 类**，其余 UI 块以 `_PrivateClassName`（下划线前缀）形式内聚，避免单个文件过 500 行。

**一个好的 Widget 应该：**

- 仅接收必要的参数（通过构造函数注入，而非依赖全局变量）
- 在内部使用 `_buildXxx` 方法按语义切分 render 逻辑
- 不直接访问网络 / 后端 API

### 异步 & 错误处理

每个 `Future` 调用必须被 `try/catch` 包裹，失败时：

1. 更新 Provider 状态的 `error` 字段（供 UI 展示）
2. 中文错误提示（面向用户）
3. 不使用 `print`，生产环境下使用结构化日志

```dart
Future<void> load() async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final data = await _service.fetch();
    state = state.copyWith(items: data.items, hasMore: data.hasMore);
  } catch (e) {
    state = state.copyWith(error: '加载失败：${e is String ? e : e.runtimeType}');
  } finally {
    state = state.copyWith(isLoading: false);
  }
}
```

### UI 三态

每个数据页必须处理：

| 状态 | 视觉 |
| --- | --- |
| **Loading** | `CircularProgressIndicator(color: Color(0xFFE91E63))` |
| **Error** | 错误图标 + 中文提示 + 重试按钮 |
| **Data** | 列表 / 网格 / 卡片 |
| **Empty** | 提示图标 + 空态描述 |

### 主题统一

- 背景：`Colors.black` / `Colors.grey[900]`
- 强调色：`Color(0xFFE91E63)`（粉色）
- 次要文字：`Colors.white70` / `Colors.white54`
- 圆角：`BorderRadius.circular(12)` 或 `20`

---

## 常用命令速查

```bash
# 依赖管理
flutter pub get            # 安装依赖
flutter pub outdated       # 检查过时包
flutter pub upgrade        # 升级依赖

# 静态检查
flutter analyze            # 静态分析
dart format .              # 格式化

# 测试
flutter test               # 单元测试
flutter test --coverage   # 生成覆盖率

# 构建
flutter run                # 调试运行
flutter run --release      # 生产模式
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web
flutter build macos        # macOS 桌面
flutter build windows      # Windows 桌面
flutter build linux        # Linux 桌面
```

---

## 调试技巧

- `flutter_riverpod` 的 `debugPrint`：设置 `ProviderScope` 的 `observers` 即可追踪所有 Provider 状态变化
- 使用 **DevTools** 中的 **Flutter Inspector** 查看 Widget 树与渲染性能
- `print('...')` 仅在本地测试使用，提交前务必删除

---

## 下一步计划

- [ ] 引入 `auto_route` 或 `go_router` 做命名路由
- [ ] 为 `favorites / search` 提供单元测试
- [ ] 接入 `drift` 替换搜索历史 / 观看历史的 `shared_preferences`
- [ ] 集成 Crashlytics / Sentry 崩溃监控
