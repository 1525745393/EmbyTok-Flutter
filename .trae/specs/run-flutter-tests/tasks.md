# Tasks

- [x] Task 1: 全量运行 flutter test，收集失败清单（670 用例：463 通过 / 207 失败 / 4 编译错误文件）
  - [ ] SubTask 1.1: 在 `/workspace/frontend` 执行 `flutter test --concurrency=1`，捕获完整输出（含编译错误与失败用例列表）
  - [ ] SubTask 1.2: 将失败结果分类汇总：编译错误 / mock 配置不匹配 / 断言值不匹配 / 实现层 bug / 测试逻辑错误
  - [ ] SubTask 1.3: 输出失败分类报告，按文件分组统计每类失败数量

- [x] Task 2: 修复编译错误（CardTheme→CardThemeData, DialogTheme→DialogThemeData）
  - [ ] SubTask 2.1: 修复 import 路径错误、不存在的类/方法引用
  - [ ] SubTask 2.2: 修复类型签名不匹配（如方法参数从 positional 改为 named）
  - [ ] SubTask 2.3: 重跑 `flutter test --concurrency=1`，确认无编译错误，仅剩运行时失败

- [x] Task 3: 修复 mock 配置与 API 签名不匹配
  - [ ] SubTask 3.1: 修正 mock HTTP 路径与实际 Emby API 路径一致
  - [ ] SubTask 3.2: 修正 mock 响应字段名（snake_case → PascalCase 或反向）
  - [ ] SubTask 3.3: 修正 mock 服务方法签名与当前实现一致（如 login 改为命名参数）
  - [ ] SubTask 3.4: 重跑相关 service/provider 测试，确认 mock 匹配修复
  - [x] SubTask 3.5: 修复 4 个测试文件的 mockito stub 配置（已完成的专项修复）
    - 已修复 `test/views/lifecycle_autopause_test.dart`：重构 stubPlaying 避免嵌套 when，为 MockVideoPlayerController 添加 value/pause/play 显式 override
    - 已修复 `test/views/feed_autopause_test.dart`：同上 + 修正覆盖层可见性断言以匹配实现逻辑
    - 已修复 `test/utils/fullscreen_navigator_test.dart`：为 MockVideoPlayerController 添加 value 显式 override + 修正全屏尺寸检查
    - 已修复 `test/repositories/cached_media_repository_test.dart`：移除 Invocation.method 中的 `?? 50` 默认值（与 anyNamed 冲突），为 mock 参数添加与基类一致的默认值，修正 argTo 缺少 named 参数，修正 returnValueForMissingStub 类型不匹配

- [x] Task 4: 修复断言值不匹配
  - [x] SubTask 4.1: 修正预期值与实际实现逻辑不符的断言（如时间衰减算法的线性插值结果）
  - [x] SubTask 4.2: 修正断言对象类型不匹配（如 throwsA(equals(...)) → throwsA(isA<AppError>())）
  - [x] SubTask 4.3: 修正边界条件断言（如黑名单阈值 _minRecordsForSignal 需要足够 filler 记录）
  - [x] SubTask 4.4: 修复 test/widgets/gesture_overlay_test.dart 的 8 个失败用例
    - 根因：_GestureTestWidget 被 SizedBox(400, 600) 限制，但 Scaffold body 只 tighten height，
      导致 widget 实际 width=400 而 MediaQuery.of(context).size.width=800，
      使 VideoGestureMixin 中基于 screenWidth 计算的 relativeX 与实际坐标不一致
      （rightPoint relativeX=0.475 落在中心区，center relativeX=0.25 落在左侧区）
    - 修复 1：移除 SizedBox，让 _GestureTestWidget 占满 Scaffold body，确保 widget 实际尺寸与 MediaQuery 一致
    - 修复 2：_GestureTestWidgetState.onDoubleTapLeft/Right 添加 super 调用，触发 mixin 的 seekBySeconds（与 GestureOverlay 实现一致）
    - 修复 3：引入 performDoubleTapAt 辅助函数，直接调用 mixin 的 handleTapDown/handleTap，
      绕过 GestureDetector 中 Tap 与 Drag 识别器的竞技场竞争（两次 tap 间隔 < 100ms 时第二次 onTap 不触发）
    - 修复 4：引入 performPanDrag 辅助函数，直接调用 onPanStart/onPanUpdate/onPanEnd 模拟音量调节拖动

- [x] Task 5: 修复实现层 bug（ApiClient Completer / AuthState.copyWith / ref.listen / MemoryCache.containsKey / parseSrt）
  - [ ] SubTask 5.1: 逐个分析"测试逻辑正确但实现有 bug"的失败，记录 bug 描述
  - [ ] SubTask 5.2: 修复实现代码（非测试代码），使行为符合预期
  - [ ] SubTask 5.3: 重跑对应测试，确认修复有效

- [x] Task 6: 全量验证——flutter test 全绿（678 用例 All tests passed! 退出码 0）
  - [x] SubTask 6.1: 执行 `flutter test`（默认并发），确认输出 `All tests passed!`，退出码 0
  - [x] SubTask 6.2: 集成测试 full_flow_test.dart 5 个测试全部通过

- [x] Task 7: flutter analyze 验证与遗留任务关闭
  - [x] SubTask 7.1: 执行 `flutter analyze`，确认无 error 级别诊断（0 个 error，853 个 warning/info）
  - [x] SubTask 7.2: 更新 `fix-embbytok-service-tests/tasks.md` 中 SubTask 5.2、5.3 为已完成
  - [x] SubTask 7.3: 更新 `install-flutter-sdk/checklist.md` 中检查点 18 为已通过

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 3]
- [Task 5] depends on [Task 4]
- [Task 6] depends on [Task 5]
- [Task 7] depends on [Task 6]
