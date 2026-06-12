# 完善测试覆盖 - 任务列表

## [x] Task 1: 添加测试依赖与配置
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 在 `pubspec.yaml` 中添加 `mockito: ^5.4.0`、`build_runner: ^2.4.0`
  - 创建 `test/test_utils.dart`，包含通用 mock 工具函数
  - 创建 `test/mocks/` 目录，存放生成的 mock 文件
  - 配置 `build.yaml`（如需要）
- **Test Requirements**:
  - `programmatic` TR-1.1: `flutter pub get` 成功，无依赖冲突
  - `programmatic` TR-1.2: `flutter pub run build_runner build` 成功生成 mock 文件

## [x] Task 2: Model 层序列化测试
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 创建 `test/models/user_test.dart`：测试 `User.fromJson()` / `toJson()`
  - 创建 `test/models/media_item_test.dart`：测试 `MediaItem.fromJson()` / `toJson()`，覆盖可选字段
  - 创建 `test/models/library_test.dart`：测试 `Library.fromJson()`
  - 创建 `test/models/paginated_response_test.dart`：测试泛型解析
- **Test Requirements**:
  - `programmatic` TR-2.1: 所有模型测试通过 `flutter test test/models/`
  - `programmatic` TR-2.2: 测试覆盖空值、缺失字段、类型转换等边界情况

## [x] Task 3: ApiClient 单元测试
- **Priority**: P0
- **Depends On**: Task 1
- **Description**:
  - 创建 `test/services/api_client_test.dart`
  - 使用 Dio 的 `MockAdapter` 或自定义 `HttpClientAdapter` mock HTTP 响应
  - 测试场景：
    - GET 请求成功返回数据
    - POST 请求成功返回数据
    - Token 自动注入到请求头
    - 连接超时错误处理
    - 401/403/404/500 错误处理
    - 网络错误返回中文提示
- **Test Requirements**:
  - `programmatic` TR-3.1: 所有 ApiClient 测试通过
  - `programmatic` TR-3.2: 错误场景返回正确的中文错误信息

## [x] Task 4: EmbytokService 单元测试
- **Priority**: P0
- **Depends On**: Task 3
- **Description**:
  - 创建 `test/services/embbytok_service_test.dart`
  - Mock ApiClient 或使用 Dio mock adapter
  - 测试场景：
    - `login()` 成功返回 User
    - `login()` 失败抛出错误
    - `getLibraries()` 返回 Library 列表
    - `getLibraryItems()` 返回分页结果
    - `search()` 返回搜索结果
    - `toggleFavorite()` 正确调用 POST/DELETE
    - `getFavorites()` 返回收藏列表
    - `saveProgress()` / `getProgress()` 进度保存与读取
- **Test Requirements**:
  - `programmatic` TR-4.1: 所有 EmbytokService 测试通过
  - `programmatic` TR-4.2: 每个方法至少覆盖成功和失败两种场景

## [x] Task 5: AuthNotifier 状态机测试
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 创建 `test/providers/auth_provider_test.dart`
  - Mock EmbytokService 和 SharedPreferences
  - 测试场景：
    - 初始状态：`isAuthenticated = false`，`user = null`
    - 登录成功：状态正确更新，token 持久化
    - 登录失败：状态保持未认证，`error` 包含错误信息
    - `logout()`：清除状态和本地存储
    - `_loadFromStorage()`：应用启动时恢复登录状态
- **Test Requirements**:
  - `programmatic` TR-5.1: 所有 AuthNotifier 测试通过
  - `programmatic` TR-5.2: 状态流转符合预期（使用 `stateMatcher` 验证）

## [x] Task 6: VideoListNotifier 状态机测试
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 创建 `test/providers/video_list_provider_test.dart`
  - Mock EmbytokService
  - 测试场景：
    - 初始状态：`items = []`，`isLoading = false`
    - `loadItems()` 成功：`items` 填充，`hasMore` 正确
    - `loadMore()` 分页追加
    - 加载失败：`error` 包含错误信息
    - 切换媒体库：清空列表并重新加载
- **Test Requirements**:
  - `programmatic` TR-6.1: 所有 VideoListNotifier 测试通过
  - `programmatic` TR-6.2: 分页逻辑正确（不重复、不遗漏）

## [x] Task 7: FavoritesNotifier 状态机测试
- **Priority**: P1
- **Depends On**: Task 4
- **Description**:
  - 创建 `test/providers/favorites_provider_test.dart`
  - Mock EmbytokService
  - 测试场景：
    - `loadFavorites()` 成功加载收藏列表
    - `toggleFavorite()` 添加收藏
    - `toggleFavorite()` 取消收藏
    - 操作失败时 `error` 正确设置
- **Test Requirements**:
  - `programmatic` TR-7.1: 所有 FavoritesNotifier 测试通过

## [x] Task 8: 工具函数测试
- **Priority**: P2
- **Depends On**: Task 1
- **Description**:
  - 创建 `test/utils/formatters_test.dart`
  - 测试 `formatDuration()`、`formatFileSize()` 等工具函数
  - 测试边界情况（0、负数、极大值）
- **Test Requirements**:
  - `programmatic` TR-8.1: 所有工具函数测试通过

## [x] Task 9: Widget 测试（可选扩展）
- **Priority**: P2
- **Depends On**: Task 5, Task 6, Task 7
- **Description**:
  - 扩展 `test/widget_test.dart` 或创建 `test/widgets/` 目录
  - 测试关键 Widget：
    - `VideoControls`：播放/暂停按钮状态
    - `HeartAnimation`：动画触发与隐藏
    - `SubtitleRenderer`：字幕显示逻辑
  - 使用 `WidgetTester` 和 `pumpWidget()`
- **Test Requirements**:
  - `human-judgement` TR-9.1: Widget 测试覆盖关键交互逻辑

## [x] Task 10: 测试覆盖率报告
- **Priority**: P2
- **Depends On**: Task 1-9
- **Description**:
  - 配置 `flutter test --coverage`
  - 生成 `coverage/lcov.info`
  - 使用 `lcov` 或在线工具生成覆盖率报告
  - 目标：核心业务逻辑（services/、providers/）覆盖率 > 70%
- **Test Requirements**:
  - `programmatic` TR-10.1: 覆盖率报告成功生成
  - `human-judgement` TR-10.2: 覆盖率报告显示关键模块覆盖充分

---

# Task Dependencies

```
Task 1 (依赖配置)
  ├── Task 2 (Model 测试) ─────┐
  ├── Task 3 (ApiClient 测试) ──┼──→ Task 4 (Service 测试)
  │                              │       │
  │                              │       ├──→ Task 5 (Auth Provider)
  │                              │       ├──→ Task 6 (VideoList Provider)
  │                              │       └──→ Task 7 (Favorites Provider)
  │                              │                │
  └── Task 8 (Utils 测试) ───────┘                │
                                                   ├──→ Task 9 (Widget 测试)
                                                   │
                                                   └──→ Task 10 (覆盖率报告)
```

**可并行执行的任务组**：
- Task 2、Task 3、Task 8 可并行（都只依赖 Task 1）
- Task 5、Task 6、Task 7 可并行（都只依赖 Task 4）
