import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/api_client.dart';
import 'utils/logger.dart';

/// 应用启动入口
/// - 预初始化日志系统，避免首次 WARN/ERROR 日志触发惰性 I/O
/// - 设置 Flutter 内置图片缓存的最大容量，避免长时间浏览导致 OOM
/// - 加载全局证书校验配置（P0-1）
/// - 初始化 Riverpod 状态管理
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  // P0-1：加载全局 SSL 证书校验配置（允许自签名证书）
  // 必须在任何 ApiClient 实例创建之前调用
  await ApiClient.loadGlobalSettings();
  // 限制 Flutter 内置图片缓存：最多 50 张，总大小不超过 30MB
  // 这是防止长时间滑动 feed 视图导致图片内存积累的关键优化
  // - 512MB heap 限制的设备需更保守，避免 OOM
  // - 配合各组件的 memCacheWidth 限制图片解码尺寸，进一步降低占用
  if (!kIsWeb) {
    PaintingBinding.instance.imageCache
      ..maximumSize = 50
      ..maximumSizeBytes = 30 * 1024 * 1024; // 30MB
  }
  // 全面屏手势适配：冷启动第一帧之前（AnnotatedRegion 还没挂上时），
  // 先把系统栏背景设为透明、状态栏图标设为 light，避免启动闪黑/白。
  // 真正的"跟随主题切换"由 app.dart 的 AnnotatedRegion 在首帧后接管。
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  // 全局异常兜底：release 模式下未捕获异常不再直接闪退。
  // 视频播放链路（ExoPlayer 平台通道、解码器错误等）存在少量
  // 未被 catch 的异步/平台异常路径，若无兜底会导致整个 App 闪退。
  // 兜底策略：记录日志 + 跳过该帧（build 异常用灰屏替代），App 继续运行。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('Flutter 未捕获异常', error: details.exception);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Platform 未捕获异常', error: error, stackTrace: stack);
    return true; // 已处理，不终止 App
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: EmbyTokApp())),
    (error, stackTrace) {
      AppLogger.error('Zone 未捕获异步异常',
          error: error, stackTrace: stackTrace);
    },
  );
}
