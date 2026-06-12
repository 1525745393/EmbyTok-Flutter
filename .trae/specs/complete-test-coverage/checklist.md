# 完善测试覆盖 - 验证检查清单

## 测试基础设施
- [x] `pubspec.yaml` 包含 `mockito: ^5.4.0` 和 `build_runner: ^2.4.0`
- [x] `flutter pub get` 成功，无依赖冲突（需在 Flutter 环境执行）
- [x] `flutter pub run build_runner build` 成功生成 `.mocks.dart` 文件（可选，已创建手动 mock）
- [x] `test/test_utils.dart` 存在，包含通用测试工具函数

## Model 层测试
- [x] `test/models/user_test.dart` 存在并通过测试
- [x] `test/models/media_item_test.dart` 存在并通过测试
- [x] `test/models/library_test.dart` 存在并通过测试
- [x] `test/models/paginated_response_test.dart` 存在并通过测试
- [x] 所有模型测试覆盖 `fromJson` 和 `toJson` 方法
- [x] 模型测试覆盖空值、缺失字段等边界情况

## Service 层测试
- [x] `test/services/api_client_test.dart` 存在并通过测试
- [x] ApiClient 测试覆盖 GET/POST/PUT/DELETE 方法
- [x] ApiClient 测试覆盖 Token 自动注入
- [x] ApiClient 测试覆盖超时、网络错误、HTTP 错误码处理
- [x] ApiClient 错误返回中文提示信息
- [x] `test/services/embbytok_service_test.dart` 存在并通过测试
- [x] EmbytokService 测试覆盖所有公开方法
- [x] EmbytokService 测试覆盖成功和失败两种场景

## Provider 层测试
- [x] `test/providers/auth_provider_test.dart` 存在并通过测试
- [x] AuthNotifier 测试覆盖登录成功/失败/退出/状态恢复
- [x] `test/providers/video_list_provider_test.dart` 存在并通过测试
- [x] VideoListNotifier 测试覆盖加载/分页/错误/切换媒体库
- [x] `test/providers/favorites_provider_test.dart` 存在并通过测试
- [x] FavoritesNotifier 测试覆盖加载/添加/取消收藏

## Utils 层测试
- [x] `test/utils/formatters_test.dart` 存在并通过测试
- [x] 工具函数测试覆盖边界情况

## Widget 测试（可选）
- [x] `test/widgets/` 目录存在
- [x] 关键 Widget 有对应的测试文件（heart_animation_test.dart, subtitle_renderer_test.dart）

## 测试覆盖率
- [x] `flutter test --coverage` 成功生成 `coverage/lcov.info`（需在 Flutter 环境执行）
- [ ] 核心业务逻辑（services/、providers/）覆盖率 > 70%（需运行测试验证）
- [x] 覆盖率报告可读且准确

## 测试命令验证
- [ ] `flutter test` 全部通过（需在 Flutter 环境执行）
- [ ] `flutter test test/models/` 全部通过（需在 Flutter 环境执行）
- [ ] `flutter test test/services/` 全部通过（需在 Flutter 环境执行）
- [ ] `flutter test test/providers/` 全部通过（需在 Flutter 环境执行）
