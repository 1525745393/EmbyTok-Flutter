# EmbyTok Flutter 测试指南

本文档描述了 EmbyTok Flutter 项目的测试结构、运行方法和覆盖率配置。

## 目录结构

```
test/
├── mocks/                    # Mock 对象
│   └── mock_services.dart    # 服务 Mock
├── models/                   # 模型测试
│   ├── library_test.dart
│   ├── media_item_test.dart
│   ├── paginated_response_test.dart
│   └── user_test.dart
├── providers/                # Provider 测试
│   ├── auth_provider_test.dart
│   ├── favorites_provider_test.dart
│   └── video_list_provider_test.dart
├── services/                 # 服务测试
│   ├── api_client_test.dart
│   └── embbytok_service_test.dart
├── utils/                    # 工具函数测试
│   └── formatters_test.dart
├── widgets/                  # Widget 测试
│   ├── heart_animation_test.dart
│   └── subtitle_renderer_test.dart
├── test_utils.dart           # 测试工具类
├── widget_test.dart          # 基础 widget 测试
├── run_all_tests.sh          # 测试运行脚本
└── README_TESTING.md         # 本文档
```

## 运行测试

### 运行所有测试

```bash
# 使用脚本（推荐）
./test/run_all_tests.sh

# 或直接使用 Flutter 命令
flutter test
```

### 运行特定测试文件

```bash
# 运行单个测试文件
flutter test test/widgets/heart_animation_test.dart

# 运行特定目录下的所有测试
flutter test test/models/
```

### 运行特定测试用例

```bash
# 按名称过滤测试
flutter test --name "HeartAnimation"

# 使用正则表达式过滤
flutter test --name "subtitle.*"
```

## 覆盖率报告

### 生成覆盖率报告

```bash
# 生成 lcov.info 文件
flutter test --coverage

# 生成的文件位于: coverage/lcov.info
```

### 生成 HTML 报告

需要安装 `lcov` 工具：

```bash
# macOS
brew install lcov

# Ubuntu/Debian
sudo apt-get install lcov

# 生成 HTML 报告
genhtml coverage/lcov.info -o coverage/html

# 在浏览器中查看
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

### 使用 coverage 包

项目已添加 `coverage` 依赖，可以使用更详细的功能：

```bash
# 安装依赖
flutter pub get

# 运行测试并生成覆盖率
flutter test --coverage

# 查看覆盖率摘要
dart run coverage:format_coverage
```

## 测试类型

### 1. 单元测试

测试独立的函数、类和方法。

```dart
test('函数返回正确结果', () {
  expect(add(2, 3), equals(5));
});
```

### 2. Widget 测试

测试 UI 组件的渲染和交互。

```dart
testWidgets('Widget 正确渲染', (WidgetTester tester) async {
  await tester.pumpWidget(MyWidget());
  expect(find.text('Hello'), findsOneWidget);
});
```

### 3. Provider 测试

测试 Riverpod Provider 的状态管理。

```dart
test('Provider 返回正确状态', () {
  final container = ProviderContainer();
  final state = container.read(myProvider);
  expect(state, equals(expectedValue));
});
```

## Widget 测试最佳实践

### 使用 pumpWidget 和 pump

```dart
// 初始渲染
await tester.pumpWidget(MyApp());

// 等待动画完成
await tester.pumpAndSettle();

// 推进特定时间
await tester.pump(Duration(milliseconds: 100));
```

### 查找 Widget

```dart
// 按类型查找
find.byType(Text);

// 按文本查找
find.text('Hello');

// 按 Key 查找
find.byKey(Key('my-key'));

// 按图标查找
find.byIcon(Icons.favorite);
```

### 验证 Widget 属性

```dart
// 获取 Widget 实例
final textWidget = tester.widget<Text>(find.text('Hello'));
expect(textWidget.style?.fontSize, equals(16.0));
```

## Mock 和依赖注入

### 使用 Provider Override

```dart
final container = ProviderContainer(
  overrides: [
    myProvider.overrideWith((ref) => mockValue),
  ],
);
```

### 创建测试专用 Notifier

```dart
class _TestNotifier extends MyNotifier {
  @override
  Future<void> _load() async {
    // 跳过 SharedPreferences 加载
  }
}
```

## 测试工具类

### TestFixtures

提供测试数据工厂方法：

```dart
TestFixtures.userJson(userId: '123');
TestFixtures.libraryJson(name: '电影');
TestFixtures.mediaItemJson(title: '测试视频');
```

### TestConstants

提供测试常量：

```dart
TestConstants.testBackendUrl;
TestConstants.testToken;
```

### MockDioAdapter

用于 Mock HTTP 请求：

```dart
final adapter = MockDioAdapter();
adapter.addResponse(MockResponse(data: '{"key": "value"}'));
```

## 持续集成

在 CI 环境中运行测试：

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: |
    flutter pub get
    flutter test --coverage
```

## 常见问题

### 测试失败：找不到 Widget

确保使用正确的 Finder，并检查 Widget 是否已渲染：

```dart
// 等待所有动画完成
await tester.pumpAndSettle();
```

### Provider 测试失败

确保正确设置 Provider Override，并使用 `UncontrolledProviderScope`：

```dart
await tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: MyApp(),
  ),
);
```

### 覆盖率报告不准确

确保运行所有测试文件，并检查是否有未测试的代码路径。

## 相关资源

- [Flutter 测试文档](https://docs.flutter.dev/testing)
- [Flutter Widget 测试](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Riverpod 测试指南](https://riverpod.dev/docs/essentials/testing)
- [Mockito 文档](https://pub.dev/packages/mockito)
