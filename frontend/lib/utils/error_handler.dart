// 统一错误处理工具类
//
// 实施 PRD P2-4 错误处理统一需求，解决部分页面错误处理不统一的问题。
//
// 错误分类与处理策略：
// - 网络错误（DioException type=connectionTimeout/receiveTimeout/sendTimeout/connectionError）：
//   显示 SnackBar + 重试按钮
// - 认证错误（HTTP 401）：自动跳登录页
// - 服务器错误（HTTP 500+）：显示错误页面
// - 超时错误：显示 SnackBar + 重试按钮
// - 未知错误：显示通用错误提示
//
// 使用方式：
//   ErrorHandler.handle(context, error, onRetry: () => fetchData());
//   ErrorHandler.handleWithSnackBar(context, '加载失败', onRetry: () => fetchData());

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'logger.dart';

/// 错误类型枚举
enum ErrorType {
  network, // 网络错误（连接失败、超时等）
  authentication, // 认证错误（401）
  server, // 服务器错误（500+）
  timeout, // 超时错误
  notFound, // 404 资源不存在
  unknown, // 未知错误
}

/// 统一错误处理工具类
class ErrorHandler {
  const ErrorHandler._();

  /// 分类错误类型
  static ErrorType classifyError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final type = error.type;

      // 认证错误
      if (statusCode == 401) return ErrorType.authentication;

      // 404 资源不存在
      if (statusCode == 404) return ErrorType.notFound;

      // 服务器错误
      if (statusCode != null && statusCode >= 500) return ErrorType.server;

      // 超时错误
      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.sendTimeout) {
        return ErrorType.timeout;
      }

      // 网络连接错误
      if (type == DioExceptionType.connectionError ||
          type == DioExceptionType.unknown) {
        return ErrorType.network;
      }

      return ErrorType.unknown;
    }

    return ErrorType.unknown;
  }

  /// 获取用户友好的错误提示
  static String userFriendlyMessage(Object error) {
    final type = classifyError(error);
    switch (type) {
      case ErrorType.network:
        return '网络连接失败，请检查网络设置';
      case ErrorType.authentication:
        return '登录已过期，请重新登录';
      case ErrorType.server:
        return '服务器暂时不可用，请稍后重试';
      case ErrorType.timeout:
        return '请求超时，请检查网络后重试';
      case ErrorType.notFound:
        return '请求的资源不存在';
      case ErrorType.unknown:
        return '操作失败，请稍后重试';
    }
  }

  /// 获取调试信息（仅开发模式显示）
  static String? debugInfo(Object error, StackTrace? stackTrace) {
    if (!kDebugMode) return null;
    final buffer = StringBuffer();
    buffer.writeln('错误类型: ${error.runtimeType}');
    buffer.writeln('错误分类: ${classifyError(error).name}');
    if (error is DioException) {
      buffer.writeln('Dio 类型: ${error.type.name}');
      if (error.response?.statusCode != null) {
        buffer.writeln('HTTP 状态码: ${error.response?.statusCode}');
      }
      if (error.requestOptions.uri.toString().isNotEmpty) {
        buffer.writeln('请求 URL: ${error.requestOptions.uri}');
      }
    }
    buffer.writeln('错误信息: $error');
    if (stackTrace != null) {
      buffer.writeln('堆栈跟踪:\n$stackTrace');
    }
    return buffer.toString();
  }

  /// 统一错误处理入口
  ///
  /// 根据错误类型自动选择处理方式：
  /// - 认证错误：自动跳登录页
  /// - 网络/超时错误：显示 SnackBar + 重试按钮
  /// - 服务器/未知错误：显示 SnackBar
  ///
  /// [onRetry] 可选的重试回调，提供时显示重试按钮
  /// [onLogin] 可选的登录跳转回调，用于 401 错误时跳登录页
  static void handle(
    BuildContext context,
    Object error, {
    StackTrace? stackTrace,
    VoidCallback? onRetry,
    VoidCallback? onLogin,
    String? customMessage,
  }) {
    // 记录错误日志
    AppLogger.error(
      '错误处理: ${userFriendlyMessage(error)}',
      error: error,
      stackTrace: stackTrace,
    );

    final type = classifyError(error);

    // 认证错误：自动跳登录页
    if (type == ErrorType.authentication) {
      if (onLogin != null) {
        onLogin();
      } else {
        _showSnackBar(
          context,
          customMessage ?? userFriendlyMessage(error),
          isError: true,
        );
      }
      return;
    }

    // 网络/超时错误：显示 SnackBar + 重试按钮
    if (type == ErrorType.network || type == ErrorType.timeout) {
      _showSnackBar(
        context,
        customMessage ?? userFriendlyMessage(error),
        isError: true,
        onRetry: onRetry,
      );
      return;
    }

    // 其他错误：显示 SnackBar
    _showSnackBar(
      context,
      customMessage ?? userFriendlyMessage(error),
      isError: true,
      onRetry: onRetry,
    );
  }

  /// 显示带自定义消息的 SnackBar
  static void handleWithSnackBar(
    BuildContext context,
    String message, {
    bool isError = true,
    VoidCallback? onRetry,
  }) {
    _showSnackBar(context, message, isError: isError, onRetry: onRetry);
  }

  /// 显示成功提示
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, isError: false);
  }

  /// 内部方法：显示 SnackBar
  static void _showSnackBar(
    BuildContext context,
    String message, {
    required bool isError,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    // 移除之前的 SnackBar，避免堆叠
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? scheme.error : scheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ],
        ),
        backgroundColor: scheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: onRetry != null ? 5 : 3),
        action: onRetry != null
            ? SnackBarAction(
                label: '重试',
                textColor: scheme.primary,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onRetry();
                },
              )
            : null,
      ),
    );
  }
}
