# Commit 129f331 说明

**Commit**: `129f33169b99a76a9d38e52942dad2c4a9a1fa49`
**原始 message**: `feat: EmbyX 媒体库网格视图实现`
**实际改动**: 修复 MemoryPressureHandler 的 5 个编译错误

## 背景

commit `129f331` 的 message 与实际改动内容不符（message 由自动提交脚本生成时使用了错误模板）。
本文件用于补充说明该 commit 的实际改动内容，避免后续维护者产生误解。

## 实际改动内容

修复以下 5 个编译错误：

### 1. `app.dart:49` - WidgetRef 类型不匹配

**错误**: `The argument type 'WidgetRef' can't be assigned to the parameter type 'Ref<Object?>'`

**根因**: `MemoryPressureHandler.attach(Ref ref)` 参数类型是 `Ref`，但 `ConsumerState.ref` 返回 `WidgetRef`。

**修复**: 参数类型从 `Ref` 改为 `WidgetRef`。

### 2. `memory_pressure_handler.dart:46` - setMethodCallHandler 未定义

**错误**: `The method 'setMethodCallHandler' isn't defined for the type 'BasicMessageChannel'`

**根因**: `SystemChannels.system` 是 `BasicMessageChannel` 而非 `MethodChannel`，没有 `setMethodCallHandler` 方法。

**修复**: 改用 `WidgetsBindingObserver.didHaveMemoryPressure()` 标准 API。

### 3. `memory_pressure_handler.dart:55` - setMethodCallHandler 未定义

同错误 2，在同一文件的 `_stop()` 方法中。

### 4. `memory_pressure_handler.dart:66` - PaintingBinding 未定义

**错误**: `Undefined name 'PaintingBinding'`

**根因**: 缺少 `package:flutter/painting.dart` 导入。

**修复**: 添加 `import 'package:flutter/painting.dart';`。

### 5. `memory_pressure_handler.dart:70` - videoPoolProvider 未定义

**错误**: `Undefined name 'videoPoolProvider'`

**根因**: `providers.dart` 未导出 `videoPoolProvider`（它定义在 `services/video_pool_service.dart`）。

**修复**: 在 `providers.dart` 的 "列表与播放控制" 分组中添加 `export '../services/video_pool_service.dart';`。

## 涉及文件

- `frontend/lib/utils/memory_pressure_handler.dart`
- `frontend/lib/providers/providers.dart`

## 设计决策

从直接监听 `SystemChannels.system`（`BasicMessageChannel`）改为使用 Flutter 标准的 `WidgetsBindingObserver` mixin：

- 这是 Flutter 框架层提供的标准 API，官方文档有明确记载
- 不需要关心底层 channel 的消息格式（之前的 `BasicMessageChannel` 消息格式猜测有误）
- 语义更清晰，代码可读性更好
- `WidgetsBinding.instance.handleMemoryPressure()` 内部就是从 `SystemChannels.system` 接收消息后分发的
