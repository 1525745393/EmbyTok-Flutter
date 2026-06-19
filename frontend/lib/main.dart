import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

/// 应用启动入口
/// - 设置 Flutter 内置图片缓存的最大容量，避免长时间浏览导致 OOM
/// - 初始化 Riverpod 状态管理
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 限制 Flutter 内置图片缓存：最多 200 张，总大小不超过 100MB
  // 这是防止长时间滑动 feed 视图导致图片内存积累的关键优化
  if (!kIsWeb) {
    PaintingBinding.instance.imageCache
      ..maximumSize = 200
      ..maximumSizeBytes = 100 * 1024 * 1024; // 100MB
  }
  runApp(const ProviderScope(child: EmbyTokApp()));
}
