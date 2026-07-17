// 统一错误模型：为全项目提供错误分类、用户提示和可重试判断
//
// 设计目标：
// - 替换各 Provider 中裸 String? error，提供类型化的错误信息
// - 区分错误类型，让 UI 层能做差异化处理（401 跳登录、网络错误重试等）
// - 同时携带用户可读提示和调试用原始信息
// - 支持日志上报和本地持久化

/// 错误类型枚举
///
/// 覆盖项目所有常见错误场景，UI 层可按类型展示不同提示和操作
enum ErrorType {
  /// 网络连接失败（DNS 解析失败、连接被拒绝等）
  network,

  /// 请求超时（连接超时、发送超时、接收超时）
  timeout,

  /// 401 未授权（token 失效或未登录）
  unauthorized,

  /// 403 禁止访问（权限不足）
  forbidden,

  /// 404 资源不存在
  notFound,

  /// 5xx 服务器错误
  serverError,

  /// 视频播放失败（解码错误、格式不支持、播放器初始化失败等）
  playback,

  /// 未登录或认证信息缺失
  notAuthenticated,

  /// 未知错误（兜底类型）
  unknown;

  /// 错误类型的中文标签（用于 UI 展示和日志）
  String get zhLabel => switch (this) {
        ErrorType.network => '网络错误',
        ErrorType.timeout => '请求超时',
        ErrorType.unauthorized => '未授权',
        ErrorType.forbidden => '访问被拒绝',
        ErrorType.notFound => '资源不存在',
        ErrorType.serverError => '服务器错误',
        ErrorType.playback => '播放错误',
        ErrorType.notAuthenticated => '未登录',
        ErrorType.unknown => '未知错误',
      };

  /// 该错误类型是否可重试
  ///
  /// 可重试：网络错误、超时、服务器错误（瞬时性故障）
  /// 不可重试：401/403/404（重试无意义）、播放错误（需用户介入）
  bool get isRetryable => switch (this) {
        ErrorType.network ||
        ErrorType.timeout ||
        ErrorType.serverError =>
          true,
        ErrorType.unauthorized ||
        ErrorType.forbidden ||
        ErrorType.notFound ||
        ErrorType.playback ||
        ErrorType.notAuthenticated ||
        ErrorType.unknown =>
          false,
      };
}

/// 统一错误模型
///
/// 全项目错误传递的标准载体，替代裸 String。
/// 示例：
/// ```dart
/// try {
///   await apiClient.get('/items');
/// } on AppError catch (e) {
///   if (e.type == ErrorType.unauthorized) {
///     // 跳转登录页
///   }
///   state = state.copyWith(error: e);
/// }
/// ```
class AppError implements Exception {
  /// 错误分类
  final ErrorType type;

  /// 用户可读的中文提示（UI 层直接展示）
  final String message;

  /// 调试用原始错误信息（不展示给用户，用于日志和排查）
  final String? debugMessage;

  /// HTTP 状态码（网络请求错误时有值）
  final int? statusCode;

  /// 原始堆栈（用于日志持久化和上报）
  final StackTrace? stackTrace;

  /// 错误发生时间戳
  final DateTime timestamp;

  const AppError({
    required this.type,
    required this.message,
    this.debugMessage,
    this.statusCode,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 是否可重试
  bool get isRetryable => type.isRetryable;

  /// 便捷构造：网络错误
  factory AppError.network({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.network,
        message: message ?? '网络连接失败，请检查网络设置',
        debugMessage: debugMessage,
        stackTrace: stackTrace,
      );

  /// 便捷构造：超时
  factory AppError.timeout({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.timeout,
        message: message ?? '请求超时，请检查网络连接',
        debugMessage: debugMessage,
        stackTrace: stackTrace,
      );

  /// 便捷构造：未授权（401）
  factory AppError.unauthorized({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.unauthorized,
        message: message ?? '登录已失效，请重新登录',
        debugMessage: debugMessage,
        statusCode: 401,
        stackTrace: stackTrace,
      );

  /// 便捷构造：禁止访问（403）
  factory AppError.forbidden({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.forbidden,
        message: message ?? '权限不足，无法访问该资源',
        debugMessage: debugMessage,
        statusCode: 403,
        stackTrace: stackTrace,
      );

  /// 便捷构造：资源不存在（404）
  factory AppError.notFound({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.notFound,
        message: message ?? '资源不存在',
        debugMessage: debugMessage,
        statusCode: 404,
        stackTrace: stackTrace,
      );

  /// 便捷构造：服务器错误（5xx）
  factory AppError.serverError({
    required int statusCode,
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.serverError,
        message: message ?? '服务器错误（$statusCode），请稍后重试',
        debugMessage: debugMessage,
        statusCode: statusCode,
        stackTrace: stackTrace,
      );

  /// 便捷构造：播放错误
  factory AppError.playback({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.playback,
        message: message ?? '视频播放失败',
        debugMessage: debugMessage,
        stackTrace: stackTrace,
      );

  /// 便捷构造：未登录
  factory AppError.notAuthenticated({
    String? message,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.notAuthenticated,
        message: message ?? '尚未登录',
        stackTrace: stackTrace,
      );

  /// 便捷构造：未知错误（兜底）
  factory AppError.unknown({
    String? message,
    String? debugMessage,
    StackTrace? stackTrace,
  }) =>
      AppError(
        type: ErrorType.unknown,
        message: message ?? '操作失败，请稍后重试',
        debugMessage: debugMessage,
        stackTrace: stackTrace,
      );

  /// 从 DioException 或其他原始错误转换
  ///
  /// 供 ApiClient 内部使用，将 DioException 分类为 AppError
  factory AppError.fromDioException(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    // 已经是 AppError 的直接返回
    if (error is AppError) return error;

    final debugMsg = error?.toString();
    final stack = stackTrace ?? (error is Error ? error.stackTrace : null);

    // 字符串错误（EmbytokService 中 throw 'xxx' 的情况）
    if (error is String) {
      if (error.contains('登录') || error.contains('服务器地址')) {
        return AppError.notAuthenticated(debugMessage: error, stackTrace: stack);
      }
      return AppError.unknown(message: error, debugMessage: debugMsg, stackTrace: stack);
    }

    // DioException 分类
    if (error.toString().contains('DioException') ||
        error.toString().contains('SocketException') ||
        error.toString().contains('HandshakeException')) {
      // 超时类
      if (error.toString().contains('Timeout') ||
          error.toString().contains('connectionTimeout') ||
          error.toString().contains('sendTimeout') ||
          error.toString().contains('receiveTimeout')) {
        return AppError.timeout(debugMessage: debugMsg, stackTrace: stack);
      }
      // 连接错误
      if (error.toString().contains('connectionError') ||
          error.toString().contains('SocketException') ||
          error.toString().contains('HandshakeException')) {
        return AppError.network(debugMessage: debugMsg, stackTrace: stack);
      }
    }

    return AppError.unknown(debugMessage: debugMsg, stackTrace: stack);
  }

  @override
  String toString() => 'AppError($type): $message';

  /// 转为可序列化的 Map（用于本地日志持久化）
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'message': message,
        'debugMessage': debugMessage,
        'statusCode': statusCode,
        'timestamp': timestamp.toIso8601String(),
      };
}
