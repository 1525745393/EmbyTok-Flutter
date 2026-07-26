import 'dart:async';

import 'logger.dart';

/// 安全的 fire-and-forget：包装 [unawaited] + 统一错误日志
///
/// 替代裸 [unawaited] 调用，确保异步异常被捕获并记录到 AppLogger，
/// 避免未处理异常进入全局错误处理而丢失上下文。
///
/// [context] 可选标注调用位置，便于日志排查。
void safeUnawaited(Future<void>? future, {String? context}) {
  if (future == null) return;
  unawaited(future.catchError((error, stackTrace) {
    AppLogger.error(
      'unawaited 异步操作失败${context != null ? " ($context)" : ""}',
      error: error,
      stackTrace: stackTrace,
    );
  }));
}
