import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'utils/logger.dart';

/// 应用启动入口
/// - 预初始化日志系统，避免首次 WARN/ERROR 日志触发惰性 I/O
/// - 设置 Flutter 内置图片缓存的最大容量，避免长时间浏览导致 OOM
/// - 初始化 Riverpod 状态管理
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
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
  runApp(const ProviderScope(child: EmbyTokApp()));
}
