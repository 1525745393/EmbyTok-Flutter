// 结构化日志工具类：支持不同日志级别和结构化数据
// Debug 模式记录所有级别，Release 模式仅记录 Warn 和 Error

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// 日志级别扩展：用于比较和显示
extension LogLevelExtension on LogLevel {
  /// 日志级别优先级（数值越大优先级越高）
  int get priority => switch (this) {
        LogLevel.debug => 0,
        LogLevel.info => 1,
        LogLevel.warn => 2,
        LogLevel.error => 3,
      };

  /// 日志级别标签
  String get tag => switch (this) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };
}

/// 应用日志工具类
///
/// 提供结构化日志记录功能，支持：
/// - 日志级别控制（Debug/Info/Warn/Error）
/// - 结构化数据附加
/// - 时间戳和调用位置信息
/// - Debug/Release 模式差异化输出
class AppLogger {
  AppLogger._();

  /// 最小日志级别（低于此级别的日志将被过滤）
  ///
  /// Debug 模式：记录 DEBUG 及以上
  /// Release 模式：仅记录 WARN 及以上
  static LogLevel _minLevel =
      kDebugMode ? LogLevel.debug : LogLevel.warn;

  /// 设置最小日志级别
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// 获取当前最小日志级别
  static LogLevel get minLevel => _minLevel;

  /// 记录 DEBUG 级别日志
  ///
  /// 用于开发调试信息，仅在 Debug 模式下输出
  static void debug(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.debug, message, data: data);
  }

  /// 记录 INFO 级别日志
  ///
  /// 用于常规操作信息，如用户登录、API 请求等
  static void info(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.info, message, data: data);
  }

  /// 记录 WARN 级别日志
  ///
  /// 用于警告信息，如降级策略触发、超时等
  static void warn(String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.warn, message, data: data);
  }

  /// 记录 ERROR 级别日志
  ///
  /// 用于错误信息，包含错误对象和堆栈跟踪
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogLevel.error,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 内部日志记录方法
  static void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // 检查日志级别是否满足最小级别要求
    if (level.priority < _minLevel.priority) {
      return;
    }

    // 构建日志内容
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();

    // 基础格式：[LEVEL] timestamp - message
    buffer.write('[$level] $timestamp - $message');

    // 添加结构化数据
    if (data != null && data.isNotEmpty) {
      buffer.write(' | ${_formatData(data)}');
    }

    // 添加错误信息
    if (error != null) {
      buffer.write(' | Error: $error');
    }

    // 添加堆栈跟踪
    if (stackTrace != null && kDebugMode) {
      buffer.write('\nStackTrace:\n$stackTrace');
    }

    // 输出日志
    final logOutput = buffer.toString();

    // Debug 模式：输出到控制台和开发者工具
    if (kDebugMode) {
      developer.log(
        logOutput,
        level: _mapToDeveloperLevel(level),
        name: 'EmbyTok',
        error: error,
        stackTrace: stackTrace,
      );
      // 同时输出到控制台便于查看
      // ignore: avoid_print
      print(logOutput);
    } else {
      // Release 模式：仅输出 Error 级别到控制台
      if (level == LogLevel.error) {
        // ignore: avoid_print
        print(logOutput);
      }
    }
  }

  /// 格式化结构化数据
  static String _formatData(Map<String, dynamic> data) {
    final entries = data.entries.map((e) {
      // 过滤敏感信息
      if (_isSensitiveKey(e.key)) {
        return '${e.key}: ***';
      }
      return '${e.key}: ${e.value}';
    });
    return '{${entries.join(', ')}}';
  }

  /// 检查是否为敏感键名
  static bool _isSensitiveKey(String key) {
    final lowerKey = key.toLowerCase();
    return lowerKey.contains('token') ||
        lowerKey.contains('password') ||
        lowerKey.contains('secret') ||
        lowerKey.contains('key') ||
        lowerKey.contains('auth');
  }

  /// 映射到 developer.log 级别
  static int _mapToDeveloperLevel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => 500, // FINE
      LogLevel.info => 800, // INFO
      LogLevel.warn => 900, // WARNING
      LogLevel.error => 1000, // SEVERE
    };
  }
}
