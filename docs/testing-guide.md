# EmbyTok - 测试指南

> 本文件目标：为开发者提供项目的测试规范、最佳实践和常用测试模式。
>
> **相关源码**：`frontend/test/`

---

## 一、测试架构

### 1.1 测试分层

| 层级 | 说明 | 工具 | 占比目标 |
|------|------|------|---------|
| **单元测试** | 测试单个函数、类、组件的逻辑 | `flutter test` | 70% |
| **组件测试** | 测试 Widget 的渲染和交互 | `flutter test` + `WidgetTester` | 20% |
| **集成测试** | 测试完整流程（登录→播放→退出） | `flutter integration_test` | 10% |

### 1.2 测试目录结构

```
frontend/test/
├── utils/                    # 工具函数测试
│   ├── logger_test.dart      #   日志工具测试
│   ├── logger_redaction_test.dart # 日志脱敏测试
│   ├── constants_test.dart   #   常量测试
│   ├── version_test.dart     #   版本信息测试
│   ├── colors_test.dart      #   颜色工具测试
│   ├── donate_colors_test.dart #  捐赠颜色测试
│   ├── keyboard_shortcuts_test.dart # 键盘快捷键测试
│   ├── safe_insets_test.dart #   安全边距测试
│   ├── safe_unawaited_test.dart # 安全异步测试
│   └── formatters_test.dart  #   格式化工具测试
├── widgets/                  # 组件测试
│   ├── loading_state_card_test.dart # 加载状态组件测试
│   ├── error_state_card_test.dart   # 错误状态组件测试
│   └── empty_state_card_test.dart   # 空状态组件测试
├── models/                   # 数据模型测试
│   └── audio_models_test.dart #   音频模型测试
├── providers/                # 状态管理测试
│   └── auth_provider_test.dart #   认证 Provider 测试
└── integration_test/         # 集成测试
    └── app_test.dart         #   应用流程测试
```

---

## 二、测试规范

### 2.1 命名规范

- 测试文件：`<被测试文件>_test.dart`
- 测试函数：`test('<描述>', () { ... })`
- 测试组：`group('<模块名>', () { ... })`

**示例**：
```dart
group('Logger', () {
  test('should redact password field', () {
    // 测试逻辑
  });
});
```

### 2.2 测试结构（AAA 模式）

每个测试应遵循 **Arrange-Act-Assert** 模式：

```dart
test('should return correct formatted duration', () {
  // Arrange
  const duration = Duration(minutes: 3, seconds: 45);
  
  // Act
  final result = formatDuration(duration);
  
  // Assert
  expect(result, '3:45');
});
```

### 2.3 测试覆盖率要求

| 模块 | 最低覆盖率 | 说明 |
|------|-----------|------|
| utils/ | 80% | 工具函数必须有充分测试 |
| models/ | 90% | 数据模型必须有完整测试 |
| widgets/ | 60% | 组件测试覆盖主要交互 |
| providers/ | 50% | 状态管理测试覆盖核心逻辑 |
| 整体 | 60% | 项目整体覆盖率目标 |

---

## 三、常用测试模式

### 3.1 单元测试示例

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('should format minutes and seconds', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 45)), '3:45');
    });

    test('should pad seconds with leading zero', () {
      expect(formatDuration(const Duration(minutes: 1, seconds: 5)), '1:05');
    });

    test('should handle zero duration', () {
      expect(formatDuration(Duration.zero), '0:00');
    });
  });
}
```

### 3.2 组件测试示例

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok/widgets/loading_state_card.dart';

void main() {
  testWidgets('LoadingStateCard should show loading indicator and message', 
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingStateCard(message: '加载中...'),
        ),
      ),
    );

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('加载中...'), findsOneWidget);
  });
}
```

### 3.3 Mock 测试示例

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
  });

  test('should return songs on successful API call', () async {
    // Arrange
    when(mockApi.getSongs()).thenAnswer((_) async => [AudioSong(...)]);

    // Act
    final result = await mockApi.getSongs();

    // Assert
    expect(result.length, 1);
    verify(mockApi.getSongs()).called(1);
  });
}
```

---

## 四、运行测试

### 4.1 运行所有测试

```bash
cd frontend
flutter test
```

### 4.2 运行指定测试文件

```bash
flutter test test/utils/logger_test.dart
```

### 4.3 运行带覆盖率的测试

```bash
flutter test --coverage
```

### 4.4 查看覆盖率报告

```bash
# 生成 HTML 覆盖率报告
genhtml coverage/lcov.info -o coverage/html

# 打开报告
open coverage/html/index.html
```

### 4.5 运行集成测试

```bash
flutter test integration_test/app_test.dart
```

---

## 五、CI 中的测试

### 5.1 CI 测试流程

项目 CI（`.github/workflows/ci.yml`）会自动运行：

1. `flutter analyze` — 静态分析（必须 0 error）
2. `flutter test --coverage` — 全量测试（必须通过）
3. 上传覆盖率报告为 artifact

### 5.2 已知测试失败

Flutter 3.47.2 存在已知的 shader 编译缺陷，导致以下 3 个测试固定失败：

- `test/widgets/video_player_widget_test.dart` 中的 shader 相关测试
- 这些是 Flutter SDK 的已知问题，不是项目代码缺陷
- README 中已标注，CI 中已排除

---

## 六、测试最佳实践

### 6.1 应该做的

- ✅ 每个公共函数/类都有对应的测试
- ✅ 测试命名清晰，描述测试意图
- ✅ 使用 AAA 模式组织测试代码
- ✅ 测试之间相互独立，不依赖执行顺序
- ✅ Mock 外部依赖（API、数据库、文件系统）
- ✅ 测试边界条件（空值、最大值、异常输入）
- ✅ 测试错误处理路径

### 6.2 不应该做的

- ❌ 测试实现细节而不是行为
- ❌ 在测试中使用真实的网络请求
- ❌ 测试之间共享可变状态
- ❌ 跳过失败的测试而不修复
- ❌ 在测试中使用 `print` 调试（使用 `debugPrint`）
- ❌ 编写超过 50 行的测试函数（拆分为多个小测试）

---

## 七、新增测试清单

新增功能时，请确保：

- [ ] 新增的公共函数有单元测试
- [ ] 新增的 Widget 有组件测试
- [ ] 测试覆盖正常路径和错误路径
- [ ] 测试覆盖边界条件
- [ ] 所有测试在本地运行通过
- [ ] CI 测试通过
- [ ] 测试覆盖率不降低

---

*文档版本：v1.0 | 最后更新：2026-09-11*
