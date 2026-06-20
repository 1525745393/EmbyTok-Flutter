import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

/// 应用启动入口
/// - 设置 Flutter 内置图片缓存的最大容量，避免长时间浏览导致 OOM
/// - 初始化 Riverpod 状态管理
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 限制 Flutter 内置图片缓存：最多 50 张，总大小不超过 30MB
  // 这是防止长时间滑动 feed 视图导致图片内存积累的关键优化
  // - 512MB heap 限制的设备需更保守，避免 OOM
  // - 配合各组件的 memCacheWidth 限制图片解码尺寸，进一步降低占用
  if (!kIsWeb) {
    PaintingBinding.instance.imageCache
      ..maximumSize = 50
      ..maximumSizeBytes = 30 * 1024 * 1024; // 30MB
  }
  runApp(const ProviderScope(child: EmbyTokApp()));
}
