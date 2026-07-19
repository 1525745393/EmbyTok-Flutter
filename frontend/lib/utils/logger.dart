// 结构化日志工具类：支持不同日志级别、模块标签和结构化数据
// Debug 模式记录所有级别，Release 模式仅记录 Warn 和 Error
//
// 持久化说明：
// - WARN 和 ERROR 级别日志会写入本地文件，方便用户导出排查
// - 采用环形缓冲：最多保留 500 条，超出后覆盖最旧记录
// - 日志文件路径：应用文档目录/logs/app.log
//
// 模块标签（tag）说明：
// - 所有 log 方法接受可选的 tag 参数，用于标识日志来源模块
// - 输出格式：[LEVEL][TAG] timestamp - message，无 tag 时格式同旧版

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
  String get label => switch (this) {
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
/// - 模块标签（tag）用于来源隔离
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

  // ============ 本地日志持久化 ============
  // 环形缓冲：最多保留 500 条 WARN/ERROR 日志
  static const int _maxPersistedLogs = 500;
  // 内存缓冲区（初始化时从文件加载，后续追加）
  static final List<String> _persistedBuffer = [];
  // 日志文件路径（首次写入时懒加载）
  static String? _logFilePath;
  // 是否已初始化（避免重复读文件）
  static bool _initialized = false;

  /// 预初始化日志系统（推荐在 main() 中尽早调用）
  ///
  /// 提前创建日志目录并加载已有历史日志到内存缓冲区，
  /// 避免首次 WARN/ERROR 日志触发惰性初始化时的 I/O 延迟。
  static Future<void> init() async {
    if (_initialized) return;
    await _ensureLogFilePath();
  }

  /// 设置最小日志级别
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// 获取当前最小日志级别
  static LogLevel get minLevel => _minLevel;

  /// 记录 DEBUG 级别日志
  ///
  /// 用于开发调试信息，仅在 Debug 模式下输出
  static void debug(String message, {
    Map<String, dynamic>? data,
    String? tag,
  }) {
    _log(LogLevel.debug, message, data: data, tag: tag);
  }

  /// 记录 INFO 级别日志
  ///
  /// 用于常规操作信息，如用户登录、API 请求等
  static void info(String message, {
    Map<String, dynamic>? data,
    String? tag,
  }) {
    _log(LogLevel.info, message, data: data, tag: tag);
  }

  /// 记录 WARN 级别日志
  ///
  /// 用于警告信息，如降级策略触发、超时等
  static void warn(String message, {
    Map<String, dynamic>? data,
    String? tag,
  }) {
    _log(LogLevel.warn, message, data: data, tag: tag);
  }

  /// 记录 ERROR 级别日志
  ///
  /// 用于错误信息，包含错误对象和堆栈跟踪
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
    String? tag,
  }) {
    _log(
      LogLevel.error,
      message,
      data: data,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// 内部日志记录方法
  static void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? data,
    String? tag,
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

    // 格式：[LEVEL][TAG] timestamp - message
    buffer.write('[$level');
    if (tag != null && tag.isNotEmpty) {
      buffer.write('][$tag');
    }
    buffer.write('] $timestamp - $message');

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

    if (kDebugMode) {
      developer.log(
        logOutput,
        level: _mapToDeveloperLevel(level),
        name: tag ?? 'EmbyTok',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // Release 模式：仅输出 Error 级别到控制台
      if (level == LogLevel.error) {
        // ignore: avoid_print
        print(logOutput);
      }
    }

    // 持久化 WARN 及以上级别日志到本地文件（便于用户导出排查）
    if (level.priority >= LogLevel.warn.priority) {
      _persistLog(logOutput);
    }
  }

  // ============ 本地日志持久化方法 ============

  /// 持久化单条日志到内存缓冲区，并异步写入文件
  ///
  /// 采用环形缓冲策略：超出 _maxPersistedLogs 时移除最旧记录
  static void _persistLog(String logLine) {
    _persistedBuffer.add(logLine);
    // 超出上限时移除最旧的记录（FIFO）
    while (_persistedBuffer.length > _maxPersistedLogs) {
      _persistedBuffer.removeAt(0);
    }
    // 异步写入文件，不阻塞调用方
    _flushToFile();
  }

  /// 将内存缓冲区写入日志文件
  ///
  /// 使用 IOSink 追加写入，避免每次重写整个文件
  static Future<void> _flushToFile() async {
    try {
      final path = await _ensureLogFilePath();
      final file = File(path);
      // 写入最新一条（追加模式）
      final lastLine = _persistedBuffer.last;
      await file.writeAsString('$lastLine\n', mode: FileMode.append);
    } catch (e) {
      // 持久化失败不影响主流程，仅开发时打印
      if (kDebugMode) {
        // ignore: avoid_print
        print('日志持久化失败: $e');
      }
    }
  }

  /// 懒加载日志文件路径，首次调用时创建文件并加载历史内容
  static Future<String> _ensureLogFilePath() async {
    if (_initialized && _logFilePath != null) return _logFilePath!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logFilePath = '${logDir.path}/app.log';
      // 首次初始化时加载已有日志到内存缓冲区
      final file = File(_logFilePath!);
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
        // 只保留最新的 _maxPersistedLogs 条
        if (lines.length > _maxPersistedLogs) {
          _persistedBuffer.clear();
          _persistedBuffer.addAll(lines.sublist(lines.length - _maxPersistedLogs));
        } else {
          _persistedBuffer.clear();
          _persistedBuffer.addAll(lines);
        }
      }
      _initialized = true;
    } catch (e) {
      // 路径获取失败时使用临时目录作为兜底
      if (kDebugMode) {
        // ignore: avoid_print
        print('日志路径初始化失败: $e');
      }
      _logFilePath = '/tmp/embbytok_app.log';
      _initialized = true;
    }
    return _logFilePath!;
  }

  /// 获取日志文件路径（供设置页导出使用）
  ///
  /// 返回 null 表示路径尚未初始化（可调用 ensureInitialized 先初始化）
  static Future<String?> getLogFilePath() async {
    if (!_initialized) {
      await _ensureLogFilePath();
    }
    return _logFilePath;
  }

  /// 获取所有已持久化的日志内容（供设置页预览或导出）
  static Future<String> exportLogs() async {
    if (!_initialized) {
      await _ensureLogFilePath();
    }
    return _persistedBuffer.join('\n');
  }

  /// 清除所有已持久化的日志（内存 + 文件）
  static Future<void> clearLogs() async {
    _persistedBuffer.clear();
    if (_logFilePath != null) {
      try {
        final file = File(_logFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 清除失败静默处理
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
