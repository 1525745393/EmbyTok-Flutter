# EmbyTok-Flutter 代码规范

本文档定义 EmbyTok-Flutter 项目的代码规范，所有贡献者必须遵循。

---

## 1. 项目结构

```
frontend/
├── lib/                          # 源代码
│   ├── main.dart                 # 应用入口
│   ├── app.dart                   # 应用主框架
│   ├── models/                    # 数据模型（每个模型一个文件）
│   │   ├── models.dart            # 统一导出
│   │   └── media_item.dart
│   ├── providers/                 # Riverpod 状态管理
│   │   ├── providers.dart         # 统一导出
│   │   └── favorites_provider.dart
│   ├── services/                  # 服务层（API 客户端、业务服务）
│   │   ├── api_client.dart        # Dio HTTP 客户端封装
│   │   └── embytok_service.dart   # 核心业务服务
│   ├── views/                     # 页面/视图
│   │   └── favorites_view.dart
│   ├── widgets/                   # 可复用组件
│   │   └── video_grid_card.dart
│   └── utils/                    # 工具函数
│       └── formatters.dart
├── test/                         # 测试文件（与 lib 一一对应）
│   ├── services/
│   ├── providers/
│   └── mocks/
│       └── mock_services.dart     # Mock 实现
└── .github/workflows/             # CI/CD 工作流
```

---

## 2. 文件命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| Dart 源文件 | `snake_case.dart` | `video_grid_card.dart` |
| 数据模型 | `snake_case.dart` | `media_item.dart` |
| Provider | `snake_case.dart` | `favorites_provider.dart` |
| View/Page | `snake_case_view.dart` | `favorites_view.dart` |
| Widget | `snake_case.dart` 或 `snake_case_widget.dart` | `video_grid_card.dart` |
| 测试文件 | `xxx_test.dart`（单元测试） | `embbytok_service_test.dart` |

---

## 3. 代码风格

### 3.1 命名约定

| 元素 | 规范 | 示例 |
|------|------|------|
| 类名 | PascalCase | `class MediaItem` |
| Widget 组件 | PascalCase | `class VideoGridCard extends ConsumerWidget` |
| 文件名 | snake_case | `video_grid_card.dart` |
| 变量名 | camelCase | `final mediaItemList` |
| 方法名 | camelCase | `void loadFavorites()` |
| 常量 | k + PascalCase（Riverpod provider 常量）或 SCREAMING_SNAKE_CASE | `const kFavoriteProvider` / `static const _clientAuthorization` |
| Provider | `xxxProvider`（变量）或 `xxxNotifier`（StateNotifier） | `favoritesProvider` / `FavoritesNotifier` |
| State 类 | `XxxState` | `class FavoritesState` |
| Private 成员 | `_` 前缀 | `final _dio` |
| 测试方法 | 描述性中文 | `test('登录成功返回 User 对象', ...)` |

### 3.2 Import 顺序

```dart
// 1. Flutter/Dart 官方库
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// 2. 第三方库
import 'package:cached_network_image/cached_network_image.dart';

// 3. 本项目 models（统一导出）
import '../models/models.dart';

// 4. 本项目 providers（统一导出）
import '../providers/providers.dart';

// 5. 本项目 services
import '../services/embbytok_service.dart';

// 6. 本项目 widgets（相对路径）
import '../widgets/video_page_item.dart';

// 7. 本项目 utils
import '../utils/logger.dart';

// 8. 本项目 views（相对路径）
import 'boxset_detail_view.dart';
```

**注意**：`video_page_item.dart` 位于 `lib/widgets/`，从 `lib/views/` 导入时路径为 `../widgets/video_page_item.dart`，而非 `video_page_item.dart`。

### 3.3 注释规范

```dart
// 文件头部注释：描述文件职责（中文）
// 收藏列表与状态管理（三栏：影片 / 合集 / 人物）

// 类注释：描述类的作用（中文）
/// 收藏状态：三组独立列表 + 合并的 favoriteIds 提供 O(1) 快速查询
class FavoritesState { ... }

/// 收藏 Notifier：管理整个 app 的三栏收藏状态
class FavoritesNotifier extends StateNotifier<FavoritesState> { ... }

// 方法注释：仅在逻辑复杂或关键处添加（中文）
// _hasLoaded + _isLoading 标志避免重复 loadFavorites 网络请求
bool _hasLoaded = false;
bool _isLoading = false;
```

---

## 4. Riverpod 状态管理规范

### 4.1 Provider 命名

```dart
// Provider 变量名：xxxProvider
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>(...);

// StateNotifier：XxxNotifier
class FavoritesNotifier extends StateNotifier<FavoritesState> { ... }

// State 类：XxxState
class FavoritesState { ... }
```

### 4.2 State 类设计

```dart
class FavoritesState {
  final List<MediaItem> movies;
  final List<MediaItem> boxSets;
  final List<MediaItem> people;
  final bool isLoading;
  final String? error;
  final Set<String> favoriteIds;  // 合并的 id 集合，O(1) 查询

  const FavoritesState({
    this.movies = const <MediaItem>[],
    this.boxSets = const <MediaItem>[],
    this.people = const <MediaItem>[],
    this.isLoading = false,
    this.error,
    this.favoriteIds = const <String>{},
  });

  // copyWith 提供不可变状态更新
  FavoritesState copyWith({...}) { ... }
}
```

### 4.3 StateNotifier 最佳实践

```dart
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final Ref _ref;
  final EmbytokService _service;

  // 防止重复加载
  bool _hasLoaded = false;
  bool _isLoading = false;

  // 乐观更新 + 失败回滚
  Future<void> toggleFavorite(MediaItem item) async {
    // 1. 乐观更新
    // 2. try-catch 回滚
  }
}
```

---

## 5. 服务层规范

### 5.1 API 客户端（ApiClient）

```dart
class ApiClient {
  final Dio _dio;

  ApiClient({String? baseUrl}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? '',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
  )) { _setupInterceptors(); }

  // 测试友好的构造函数
  ApiClient.withDio(this._dio, {String? baseUrl}) { ... }

  // Token 注入通过拦截器实现
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Emby-Authorization'] = _clientAuthorization;
        if (_token != null && _token!.isNotEmpty) {
          options.headers['X-Emby-Token'] = _token!;
        }
        return handler.next(options);
      },
    ));
  }
}
```

### 5.2 业务服务（EmbytokService）

```dart
class EmbytokService {
  final ApiClient _apiClient;

  EmbytokService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // 方法命名：动词 + 资源名
  Future<List<MediaItem>> getFavoriteMovies({int limit = 100, int offset = 0, ...}) async { ... }
  Future<User> login({required String embyServerUrl, required String username, required String password}) async { ... }
}
```

---

## 6. 数据模型规范

```dart
class MediaItem {
  final String id;
  final String title;
  final String type;
  // ... 字段

  const MediaItem({required this.id, required this.title, required this.type, ...});

  // factory fromJson：同时支持 Emby 原生 PascalCase 与简化 snake_case
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final id = (json['Id'] as String?) ?? (json['id'] as String?) ?? '';
    // ...
  }

  // toJson：转换回 JSON
  Map<String, dynamic> toJson() => {'id': id, 'title': title, ...};

  // 便捷方法
  String? thumbnailUrlWithAuth(String? serverUrl, String? token, {int maxWidth = 300}) { ... }
}
```

---

## 7. Widget 组件规范

### 7.1 Stateless vs Stateful

```dart
// 无状态：ConsumerWidget
class VideoGridCard extends ConsumerWidget {
  const VideoGridCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) { ... }
}

// 有状态：ConsumerStatefulWidget + ConsumerState
class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) { ... }
}
```

### 7.2 组件拆分原则

- 单一职责：每个组件只负责一个功能
- 视图 > 100 行应考虑拆分出子组件
- 私有子组件用 `_` 前缀：`class _SectionHeader extends StatelessWidget`

---

## 8. 测试规范

### 8.1 测试结构

```dart
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late ApiClient apiClient;
  late EmbytokService service;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    apiClient = ApiClient.withDio(dio);
    service = EmbytokService(apiClient: apiClient);
  });

  group('EmbytokService', () {
    group('login', () {
      test('登录成功返回 User 对象', () async { ... });
      test('登录失败抛出异常', () async { ... });
    });
  });
}
```

### 8.2 Mock 服务

```dart
class MockEmbytokService extends Mock implements EmbytokService {
  @override
  Future<User> login({...}) => super.noSuchMethod(
    Invocation.method(#login, [], {...}),
    returnValue: Future.value(User(id: 'test', name: 'test', accessToken: 'token')),
  ) as Future<User>;
}
```

### 8.3 http_mock_adapter 0.6.x 语法

```dart
// 正确
dioAdapter.onGet('/api/items', (request) => request.reply(200, data));

// 错误（0.4.x 语法，不再支持）
dioAdapter.onGet('/api/items').reply(200, data);
```

---

## 9. Git 提交规范

使用中文描述性提交信息：

```
fix: 修正 video_page_item.dart 相对路径，移除未使用 import
feat: 三栏收藏页面重构（v1.4.0）
chore(release): bump version to 1.4.0
refactor: 简化视频预加载逻辑
test: 添加收藏功能单元测试
docs: 更新 README
```

---

## 10. CI/CD 规范

- 静态分析：`flutter analyze --no-pub lib`（只分析 lib 目录，test 目录 mock 签名问题不影响发布）
- 构建：Android Release 通过 tag push 触发
- 测试：`flutter test`

---

## 11. 常见错误规避

1. **import 路径错误**：`video_page_item.dart` 在 `lib/widgets/`，从 `lib/views/` 导入必须用 `../widgets/video_page_item.dart`
2. **http_mock_adapter 语法**：必须用 `(request) => request.reply(status, data)` 格式
3. **StateNotifier 构造**：`FavoritesNotifier(this._ref, ...)` 不要忘记传 Ref
4. **Future 返回**：async 方法必须返回 `Future<T>`，stub 用 `Future.value(...)`
