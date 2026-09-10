# EmbyTok-Flutter 代码质量优化 PRD

> **文档版本**：v1.0
> **创建日期**：2026-09-10
> **基于审查**：全面代码审查（52,770 行 / 146 文件）
> **状态**：待评审

---

## 1. 背景与目标

### 1.1 背景

EmbyTok-Flutter 经过多轮功能迭代，代码量已达 52,770 行 / 146 个 Dart 文件。2026-09-10 完成全面代码审查，发现以下主要问题：

- **架构层面**：views 层过重（占 39% 代码量），单个文件最大 3100 行，build 方法最大 300+ 行
- **安全层面**：SSL 证书校验未启用，日志可能包含敏感信息
- **性能层面**：大 build 方法导致不必要重建，横向列表 coverUrl 重复计算
- **可维护性**：魔法数字、重复代码、空 catch 块较多
- **测试层面**：UI 交互和边界条件测试覆盖不足

### 1.2 目标

| 目标 | 衡量指标 | 目标值 |
|---|---|---|
| 降低崩溃率 | Android OOM / 崩溃率 | < 0.1% |
| 提升流畅度 | 页面滑动 FPS | ≥ 55fps |
| 减少构建时间 | `flutter analyze` error 数 | 0 |
| 提升可维护性 | 单文件最大行数 | < 1500 行 |
| 提升测试覆盖 | 测试用例总数 | ≥ 1000 |
| 安全合规 | 敏感信息明文存储 | 0 处 |

---

## 2. 范围与优先级

### 2.1 优先级定义

| 优先级 | 定义 | 交付时间 |
|---|---|---|
| **P0** | 阻塞性问题，影响核心功能或安全 | 1 周内 |
| **P1** | 重要改进，显著提升用户体验或性能 | 2 周内 |
| **P2** | 优化项，提升代码质量或可维护性 | 1 个月内 |
| **P3** | 长期改进，可逐步迭代 | 持续进行 |

### 2.2 需求总览

| 优先级 | 数量 | 主要内容 |
|---|---|---|
| P0 | 2 项 | SSL 证书校验、日志脱敏 |
| P1 | 4 项 | 大文件拆分、build 方法优化、空 catch 治理、通用状态组件 |
| P2 | 5 项 | 魔法常量提取、coverUrl 缓存、文件组织优化、错误处理统一、内存监控 |
| P3 | 3 项 | 测试覆盖提升、文档完善、CI/CD 优化 |

---

## 3. 需求详情

### 3.1 P0 - 安全加固

#### P0-1：SSL 证书校验开关

**问题描述**：
当前 Dio 配置未启用 SSL 证书校验（`validateCertificate`），用户连接自签名证书的内网 NAS 时存在中间人攻击风险。

**需求描述**：
1. 在设置页面新增"允许自签名证书"开关，默认关闭（启用校验）
2. 开启时，Dio 配置 `validateCertificate: false`，并弹出安全提示
3. 关闭时，Dio 配置 `validateCertificate: true`，证书无效时显示明确错误
4. 证书校验状态持久化存储（SharedPreferences）

**验收标准**：
- [ ] 设置页面存在"允许自签名证书"开关，默认关闭
- [ ] 开关关闭时，连接自签名证书服务器显示证书错误提示
- [ ] 开关开启时，可正常连接自签名证书服务器
- [ ] 开关状态持久化，App 重启后保持
- [ ] 开启时弹出安全风险提示对话框

**工作量估算**：3 人天

**涉及文件**：
- `lib/services/api_client.dart` — Dio 配置
- `lib/views/settings_view.dart` — 设置页面
- `lib/providers/settings_provider.dart` — 设置状态管理

---

#### P0-2：日志脱敏

**问题描述**：
`AppLogger` 输出请求/响应日志时，可能包含 Token、密码等敏感信息，写入日志文件后存在隐私泄露风险。

**需求描述**：
1. 在 `AppLogger` 中新增敏感字段过滤逻辑
2. 自动识别并脱敏以下字段：`token`、`password`、`Authorization`、`X-Emby-Token`、`access_token`
3. 脱敏规则：保留前 4 位 + `***` + 后 4 位（如 `abcd***wxyz`）
4. HTTP 请求头和响应体中的敏感字段均需过滤
5. 提供 `disableSensitiveLogging` 配置项，默认启用脱敏

**验收标准**：
- [ ] 日志中不出现完整的 Token 或密码
- [ ] 脱敏后的值可识别长度但不可还原
- [ ] 请求头和响应体中的敏感字段均被过滤
- [ ] 可通过配置关闭脱敏（调试用）
- [ ] 单元测试覆盖脱敏逻辑

**工作量估算**：2 人天

**涉及文件**：
- `lib/utils/logger.dart` — 日志工具
- `lib/services/api_client.dart` — 请求/响应日志

---

### 3.2 P1 - 核心改进

#### P1-1：大文件拆分（synology_music_view.dart）

**问题描述**：
`synology_music_view.dart` 约 3100 行，包含首页、歌曲、专辑、歌手、歌单 5 个 Tab 的完整 UI 逻辑，单文件职责过重，维护困难。

**需求描述**：
将 `synology_music_view.dart` 拆分为以下文件：

```
lib/views/music/
├── synology_music_view.dart          # 主框架（Tab 导航 + AppBar），约 300 行
├── music_home_tab.dart               # 首页 Tab，约 800 行
├── music_songs_tab.dart              # 歌曲 Tab，约 400 行
├── music_albums_tab.dart             # 专辑 Tab，约 400 行
├── music_artists_tab.dart            # 歌手 Tab，约 400 行
├── music_playlists_tab.dart          # 歌单 Tab，约 300 行
└── widgets/
    ├── music_section_header.dart     # 模块标题（更多按钮）
    ├── music_album_card.dart         # 专辑横向卡片
    ├── music_artist_card.dart        # 歌手横向卡片
    ├── music_song_list_tile.dart     # 歌曲列表项
    └── music_genre_grid.dart         # 流派网格
```

**拆分原则**：
1. 每个 Tab 独立为一个 `ConsumerWidget`
2. 通用组件提取到 `widgets/` 子目录
3. 保持原有功能和交互不变
4. 公共状态通过 Provider 共享，不通过参数传递

**验收标准**：
- [ ] `synology_music_view.dart` 行数 < 400 行
- [ ] 每个子文件职责单一，行数 < 800 行
- [ ] 所有原有功能正常（首页模块、歌曲列表、专辑网格、歌手列表、歌单）
- [ ] 所有原有交互正常（点击播放、长按菜单、更多按钮、下拉刷新）
- [ ] `flutter analyze` 无新增 error
- [ ] 全量测试通过（867+ 通过）

**工作量估算**：5 人天

**风险**：
- 拆分过程中可能引入状态管理 bug，需充分测试
- 公共组件提取可能影响其他页面引用

---

#### P1-2：build 方法优化（视频流页面）

**问题描述**：
`VideoPageItem.build` 约 300 行，`FullscreenVideoPage.build` 约 260 行，包含 10+ 层嵌套和大量闭包，每次状态变化都可能触发大量 widget 重建。

**需求描述**：
将两个 build 方法拆分为独立 widget：

**VideoPageItem 拆分**：
```
lib/widgets/video/
├── video_page_item.dart              # 主框架，约 150 行
├── video_playback_area.dart          # 视频播放区（VideoPlayer + 骨架占位）
├── video_control_overlay.dart        # 控制层（顶部栏 + 底部控制条）
├── video_bottom_info_bar.dart        # 底部信息栏（标题 + 类型标签）
├── video_right_action_bar.dart       # 右侧操作栏（10 个按钮）
└── video_clean_actions.dart          # 纯净模式可拖动按钮组
```

**FullscreenVideoPage 拆分**：
```
lib/views/
├── fullscreen_video_page.dart        # 主框架，约 150 行
├── fullscreen_top_bar.dart           # 顶部栏（返回 + 标题 + 投屏）
├── fullscreen_bottom_bar.dart        # 底部控制栏（进度条 + 按钮）
├── fullscreen_settings_panel.dart    # 设置面板（倍速 + 比例 + 字幕）
├── fullscreen_gesture_feedback.dart  # 手势反馈（亮度/音量/seek 预览）
└── fullscreen_lock_ui.dart           # 锁屏 UI
```

**优化原则**：
1. 每个独立 widget 使用 `const` 构造函数（如可能）
2. 状态变化仅重建受影响的 widget，不触发父级重建
3. 闭包回调通过参数传递，不捕获大量局部变量
4. 使用 `RepaintBoundary` 隔离重绘区域

**验收标准**：
- [ ] `VideoPageItem.build` 行数 < 80 行
- [ ] `FullscreenVideoPage.build` 行数 < 80 行
- [ ] 每个子 widget 职责单一，行数 < 200 行
- [ ] 所有原有功能正常（播放、暂停、seek、全屏、手势、设置）
- [ ] 滑动切换视频时 FPS ≥ 55
- [ ] `flutter analyze` 无新增 error
- [ ] 全量测试通过

**工作量估算**：5 人天

**风险**：
- 拆分过程中可能引入手势交互 bug
- 闭包回调传递可能导致上下文丢失

---

#### P1-3：空 catch 块治理

**问题描述**：
全项目约 30+ 处 `catch (_) {}` 空 catch 块，部分业务逻辑中的错误被静默吞掉，问题排查困难。

**需求描述**：
1. 对所有空 catch 块进行分类：
   - **资源释放类**（如 `controller.dispose()`）：保留空 catch，但添加注释说明原因
   - **业务逻辑类**：替换为 `AppLogger.warn` 或 `AppLogger.error` 记录错误
   - **UI 交互类**：替换为用户可见的错误提示（SnackBar / Dialog）
2. 新增 lint 规则：禁止业务逻辑代码中使用空 catch 块（`empty_catches`）
3. 资源释放类空 catch 必须添加 `// 资源释放，忽略异常` 注释

**验收标准**：
- [ ] 业务逻辑类空 catch 块数量为 0
- [ ] 资源释放类空 catch 块均有注释说明
- [ ] `empty_catches` lint 规则启用
- [ ] 所有错误均有日志记录或用户提示

**工作量估算**：2 人天

---

#### P1-4：通用状态组件提取

**问题描述**：
多个页面的错误状态、加载状态、空状态实现类似，存在重复代码约 500+ 行。

**需求描述**：
提取以下通用组件到 `lib/widgets/state/`：

```
lib/widgets/state/
├── error_state_widget.dart      # 错误状态（图标 + 消息 + 重试按钮）
├── loading_state_widget.dart    # 加载状态（CircularProgressIndicator + 文案）
├── empty_state_widget.dart      # 空状态（图标 + 标题 + 描述 + 操作按钮）
└── state_config.dart            # 配置（图标、颜色、文案）
```

**组件设计**：
- `ErrorStateWidget`：接收 `error`、`onRetry`、`title` 参数，支持自定义图标
- `LoadingStateWidget`：接收 `message` 参数，支持自定义指示器样式
- `EmptyStateWidget`：接收 `title`、`description`、`icon`、`action` 参数
- 所有组件支持 `const` 构造函数
- 统一使用主题颜色（`scheme.primary`、`scheme.onSurface`）

**迁移范围**：
- `video_grid_view.dart`
- `synology_music_view.dart`
- `search_view.dart`
- `favorites_view.dart`
- `history_view.dart`
- `recommend_view.dart`

**验收标准**：
- [ ] 通用组件覆盖所有页面的状态展示
- [ ] 重复代码减少 ≥ 400 行
- [ ] 所有页面的错误/加载/空状态视觉一致
- [ ] 组件支持自定义（图标、文案、操作按钮）
- [ ] 单元测试覆盖组件渲染

**工作量估算**：3 人天

---

### 3.3 P2 - 优化项

#### P2-1：魔法常量提取

**问题描述**：
UI 布局中存在大量未命名的魔法数字（padding、间距、尺寸、动画时长），可维护性差。

**需求描述**：
1. 提取以下常量到 `lib/utils/constants.dart`：
   - 间距常量：`kSpacingSmall=4`、`kSpacingMedium=8`、`kSpacingLarge=16`、`kSpacingXLarge=24`
   - 圆角常量：`kRadiusSmall=4`、`kRadiusMedium=8`、`kRadiusLarge=16`、`kRadiusXLarge=24`
   - 动画时长：`kAnimationFast=150ms`、`kAnimationNormal=300ms`、`kAnimationSlow=500ms`
   - 尺寸常量：`kIconSmall=16`、`kIconMedium=24`、`kIconLarge=32`
   - 控件高度：`kButtonHeight=44`、`kAppBarHeight=56`、`kBottomNavHeight=64`
2. 替换所有 UI 代码中的魔法数字为命名常量
3. 新增 lint 规则：禁止使用未命名的数字常量（`no_magic_number`，自定义）

**验收标准**：
- [ ] `constants.dart` 包含所有通用 UI 常量
- [ ] UI 代码中魔法数字减少 ≥ 80%
- [ ] 常量命名语义清晰
- [ ] `flutter analyze` 无新增 error

**工作量估算**：3 人天

---

#### P2-2：横向列表 coverUrl 缓存

**问题描述**：
音乐库横向卡片的 `coverUrl` 在 `itemBuilder` 中每次重新计算，包含字符串拼接和条件判断，造成不必要的性能损耗。

**需求描述**：
1. 在 `AudioAlbum`、`AudioArtist` 模型中新增 `coverUrl` getter，预计算封面 URL
2. 横向卡片直接使用 `item.coverUrl`，不在 `itemBuilder` 中计算
3. 封面 URL 计算逻辑统一到模型层，避免重复实现

**验收标准**：
- [ ] `itemBuilder` 中不再包含 coverUrl 计算逻辑
- [ ] 封面 URL 计算逻辑统一到模型层
- [ ] 横向列表滑动 FPS ≥ 55
- [ ] 所有封面显示正常

**工作量估算**：1 人天

---

#### P2-3：文件组织优化

**问题描述**：
`lib/widgets` 目录混合了通用组件和视频专用组件，查找困难。

**需求描述**：
1. 将视频相关组件移到 `lib/widgets/video/` 子目录
2. 将音乐相关组件移到 `lib/widgets/music/` 子目录
3. 通用组件保留在 `lib/widgets/` 根目录
4. 更新所有 import 路径
5. 新增 `lib/widgets/widgets.dart`  barrel 文件，统一导出

**目标结构**：
```
lib/widgets/
├── widgets.dart                 # barrel 导出
├── state/                       # 通用状态组件
│   ├── error_state_widget.dart
│   ├── loading_state_widget.dart
│   └── empty_state_widget.dart
├── video/                       # 视频专用组件
│   ├── video_page_item.dart
│   ├── video_player_widget.dart
│   ├── video_grid_card.dart
│   └── ...
├── music/                       # 音乐专用组件
│   ├── mini_player_bar.dart
│   └── ...
└── common/                      # 通用组件
    ├── pressable_action_button.dart
    └── ...
```

**验收标准**：
- [ ] 所有组件按功能分类到子目录
- [ ] import 路径全部更新
- [ ] `flutter analyze` 无 error
- [ ] 全量测试通过
- [ ] barrel 文件导出所有公共组件

**工作量估算**：2 人天

---

#### P2-4：错误处理统一

**问题描述**：
部分页面的错误处理不统一，有的显示 SnackBar，有的显示 Dialog，有的静默忽略。

**需求描述**：
1. 新增 `ErrorHandler` 工具类，统一错误处理逻辑：
   - 网络错误：显示 SnackBar + 重试按钮
   - 认证错误（401）：自动跳登录页
   - 服务器错误（500+）：显示错误页面
   - 超时错误：显示 SnackBar + 重试按钮
   - 未知错误：显示通用错误提示
2. 所有页面使用 `ErrorHandler.handle(context, error)` 统一处理
3. 错误信息包含用户友好提示和调试信息（开发模式）

**验收标准**：
- [ ] 所有错误处理通过 `ErrorHandler` 统一处理
- [ ] 错误提示视觉一致
- [ ] 401 错误自动跳登录页
- [ ] 网络错误提供重试功能
- [ ] 开发模式显示调试信息

**工作量估算**：2 人天

---

#### P2-5：内存监控面板

**问题描述**：
开发阶段无法实时查看应用内存使用情况，OOM 问题难以定位。

**需求描述**：
1. 新增开发模式性能监控面板（仅 debug 模式显示）
2. 实时显示：
   - 当前内存使用量（MB）/ 最大堆内存（MB）/ 内存占比
   - 帧率（FPS）/ 平均帧率
   - Widget 重建次数
   - API 请求统计（总数/失败数）
3. 内存超过阈值时高亮警告（正常绿色/警告橙色/危险红色）
4. 帧率低于阈值时高亮警告（高绿色/中橙色/低红色）
5. 悬浮面板可拖拽移动、可折叠/展开
6. 设置页开发者选项中开关控制（仅 kDebugMode 显示）

**验收标准**：
- [x] debug 模式可通过设置页开发者选项开启性能监控
- [x] 内存面板实时显示内存使用情况（当前/最大/占比/进度条）
- [x] 超过阈值时高亮警告（75% 橙色/90% 红色）
- [x] 帧率实时显示（当前/平均），低于阈值时高亮警告
- [x] Widget 重建次数和 API 请求统计实时显示
- [x] 悬浮面板可拖拽移动、可折叠/展开
- [x] release 模式不包含此功能（kDebugMode 自动禁用）

**实施记录**：
- 2026-09-11：新增 `lib/utils/performance_monitor.dart`（280 行）和 `lib/widgets/performance_overlay.dart`（296 行），在设置页添加开发者选项和性能监控开关，在主应用 MaterialApp builder 中集成 PerformanceOverlay

**工作量估算**：2 人天（已完成）

---

### 3.4 P3 - 长期改进

#### P3-1：测试覆盖提升

**问题描述**：
当前 867 个测试用例，但 UI 交互和边界条件测试覆盖不足。

**需求描述**：
1. 新增以下测试：
   - 视频流页面手势交互测试（双击点赞、长按倍速、滑动 seek）
   - 音乐库页面交互测试（播放、暂停、切歌、收藏）
   - 登录流程测试（正常登录、错误密码、网络异常）
   - 边界条件测试（空数据、超大列表、网络超时）
   - 内存泄漏测试（页面进入退出后控制器释放）
2. 目标测试用例数 ≥ 1000
3. 新增测试覆盖率报告（`flutter test --coverage`）

**验收标准**：
- [ ] 测试用例总数 ≥ 1000
- [ ] UI 交互测试覆盖主要页面
- [ ] 边界条件测试覆盖关键场景
- [ ] 测试覆盖率 ≥ 60%
- [ ] CI 自动生成覆盖率报告

**工作量估算**：5 人天

---

#### P3-2：文档完善

**问题描述**：
部分模块缺少文档，新成员上手困难。

**需求描述**：
1. 完善以下文档：
   - `docs/architecture.md` — 更新架构图和模块说明
   - `docs/api-reference.md` — 补充群晖 Audio Station API 文档
   - `docs/developer-guide.md` — 补充开发环境搭建、代码规范、调试技巧
   - 新增 `docs/testing-guide.md` — 测试规范和最佳实践
   - 新增 `docs/performance-guide.md` — 性能优化指南
2. 代码注释覆盖率 ≥ 80%（公共 API 必须有文档注释）

**验收标准**：
- [x] 架构文档与实际代码一致（已更新 music/ 子目录、video/ 子目录、error_handler.dart 等）
- [x] API 文档覆盖所有外部接口（已补充群晖 Audio Station API 文档）
- [x] 新成员可通过文档在 1 天内搭建开发环境（已补充调试技巧、常见问题排查）
- [ ] 所有公共类和方法有文档注释（进行中）

**实施记录**：
- 2026-09-11（第一阶段）：更新 `docs/architecture.md`，补充 P1-1 大文件拆分后的 music/ 子目录（6 个组件）、P2-3 文件组织优化后的 video/ 子目录（18 个组件）、P2-4 新增 error_handler.dart、P1-4 新增 loading_state_card.dart 等
- 2026-09-11（第二阶段）：
  - 更新 `docs/api-reference.md`，新增第十一章"群晖 Audio Station API（前端直连）"，包含 17 个 API 接口、登录/歌曲列表示例、错误码、注意事项
  - 新增 `docs/testing-guide.md`（272 行）：测试架构、测试规范、常用测试模式、运行测试、CI 中的测试、测试最佳实践、新增测试清单
  - 新增 `docs/performance-guide.md`（367 行）：性能指标、已实施的性能优化、性能优化策略（Widget 重建/列表/内存/网络）、性能监控工具、性能优化检查清单、常见性能问题与解决方案
  - 更新 `docs/developer-guide.md`，新增第十四章"调试技巧"，包含 Flutter 调试、后端调试、常见问题排查、性能调试

**工作量估算**：3 人天（已完成架构文档、API 文档、测试指南、性能指南、开发指南更新，剩余代码注释补充中）

---

#### P3-3：CI/CD 优化

**问题描述**：
当前 CI/CD 流程较简单，缺少自动化检查。

**需求描述**：
1. CI 流程新增以下检查：
   - `flutter analyze` — 静态分析（必须 0 error）
   - `flutter test` — 全量测试（必须通过）
   - `dart format --set-exit-if-changed` — 代码格式检查
   - 自定义 lint 检查（空 catch、魔法数字等）
   - 测试覆盖率检查（≥ 60%）
2. CD 流程优化：
   - 自动生成 release notes
   - 自动上传到测试分发平台（如 Firebase App Distribution）
   - 版本号自动递增
3. PR 模板新增检查清单（测试、文档、兼容性）

**验收标准**：
- [ ] CI 包含所有自动化检查
- [ ] PR 必须通过所有检查才能合并
- [ ] 自动生成 release notes
- [ ] 自动上传测试包
- [ ] PR 模板包含检查清单

**工作量估算**：2 人天

---

## 4. 实施计划

### 4.1 里程碑

| 里程碑 | 时间 | 内容 | 交付物 |
|---|---|---|---|
| **M1** | 第 1 周 | P0 安全加固 | SSL 校验开关、日志脱敏 |
| **M2** | 第 2-3 周 | P1 核心改进 | 大文件拆分、build 优化、空 catch 治理、通用状态组件 |
| **M3** | 第 4-6 周 | P2 优化项 | 魔法常量、coverUrl 缓存、文件组织、错误处理、内存监控 |
| **M4** | 第 7-8 周 | P3 长期改进 | 测试覆盖、文档完善、CI/CD 优化 |

### 4.2 依赖关系

```
P0-1 SSL 校验 ──┐
                 ├──> P1-1 大文件拆分 ──> P2-3 文件组织优化 ──> P3-2 文档完善
P0-2 日志脱敏 ──┘                         │
                                           ├──> P2-1 魔法常量 ──> P3-1 测试覆盖
P1-3 空 catch 治理 ──────────────────────┤
                                           └──> P2-4 错误处理统一
P1-4 通用状态组件 ──> P1-1 大文件拆分

P2-5 内存监控 ──> P3-3 CI/CD 优化
```

### 4.3 人员需求

| 角色 | 人数 | 工作内容 |
|---|---|---|
| Flutter 开发 | 2 人 | 代码重构、功能实现 |
| 测试工程师 | 1 人 | 测试用例编写、回归测试 |
| 技术负责人 | 0.5 人 | 方案评审、代码审查 |

---

## 5. 风险与应对

| 风险 | 概率 | 影响 | 应对措施 |
|---|---|---|---|
| 大文件拆分引入 bug | 高 | 高 | 充分回归测试、分阶段拆分、每拆分一个 Tab 就测试 |
| build 优化影响手势交互 | 中 | 高 | 保留原有闭包逻辑、逐步提取、真机测试手势 |
| SSL 校验影响内网用户 | 中 | 中 | 提供开关选项、默认关闭校验、清晰的错误提示 |
| 测试覆盖提升耗时 | 中 | 低 | 优先覆盖核心流程、使用 Mock 减少依赖 |
| 性能优化效果不明显 | 低 | 中 | 使用性能 profiling 工具量化效果、A/B 对比 |

---

## 6. 验收标准总览

### 6.1 功能验收

- [ ] 所有原有功能正常，无回归
- [ ] P0 安全功能完整实现
- [ ] P1 核心改进全部交付
- [ ] P2 优化项按计划完成
- [ ] P3 长期改进持续推进

### 6.2 质量验收

- [ ] `flutter analyze` 0 error / 0 warning
- [ ] 全量测试通过（≥ 1000 用例）
- [ ] 测试覆盖率 ≥ 60%
- [ ] 单文件最大行数 < 1500 行
- [ ] build 方法最大行数 < 80 行
- [ ] 业务逻辑类空 catch 块数量为 0

### 6.3 性能验收

- [ ] 视频流滑动 FPS ≥ 55
- [ ] 音乐库横向列表滑动 FPS ≥ 55
- [ ] 冷启动时间 < 3 秒
- [ ] 页面切换时间 < 500ms
- [ ] 内存峰值 < 300MB（正常使用）

### 6.4 安全验收

- [ ] 无硬编码密钥或密码
- [ ] 敏感信息加密存储
- [ ] SSL 证书校验可配置
- [ ] 日志不包含完整敏感信息
- [ ] 输入验证覆盖所有用户输入

---

## 7. 附录

### 7.1 参考文档

- [架构文档](architecture.md)
- [API 参考](api-reference.md)
- [开发指南](developer-guide.md)
- [代码审查工作流](code-review-workflow-deploy.md)
- [提交规范](COMMIT_CONVENTION.md)

### 7.2 相关 PRD

- [群晖 Audio Station 适配音乐 APP 首页 PRD](https://feishu.doubao.com/docx/ASnKdA7f9oN0K4x5Y7oc9X0Gnzb)

### 7.3 变更记录

| 版本 | 日期 | 变更内容 | 作者 |
|---|---|---|---|
| v1.0 | 2026-09-10 | 初始版本，基于全面代码审查 | 代码审查助手 |
