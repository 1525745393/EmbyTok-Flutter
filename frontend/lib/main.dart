import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 创建 ProviderContainer 以便在应用启动前加载设置
  final container = ProviderContainer();

  // 加载自动播放设置
  await container.read(isAutoPlayProvider.notifier).loadFromStorage();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const EmbyTokApp(),
  ));
}
