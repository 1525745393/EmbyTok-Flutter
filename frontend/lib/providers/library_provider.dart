// 媒体库列表 & 当前选中的媒体库 ID

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

// 当前选中的媒体库 ID
final selectedLibraryIdProvider = StateProvider<String?>((ref) => null);

// 媒体库列表：FutureProvider，登录后自动获取
final libraryListProvider = FutureProvider<List<Library>>((ref) async {
  final auth = ref.watch(authProvider);
  final serverUrl = auth.embyServerUrl;
  final token = auth.token;

  if (!auth.isAuthenticated || serverUrl == null || token == null) {
    return <Library>[];
  }

  final service = EmbytokService();
  try {
    AppLogger.info('开始加载媒体库列表');
    final libraries = await service.getLibraries(
      serverUrl: serverUrl,
      token: token,
    );
    AppLogger.info('媒体库列表加载成功', data: {'count': libraries.length});
    return libraries;
  } catch (e) {
    AppLogger.error('加载媒体库失败', error: e);
    final message = e is String ? e : '获取媒体库失败：$e';
    // FutureProvider 会捕获异常，这里直接 rethrow 以便 UI 层用 AsyncValue 处理
    throw message;
  }
});
