// 媒体库列表 & 当前选中的媒体库 ID

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/embbytok_service.dart';
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
    return await service.getLibraries(
      serverUrl: serverUrl,
      token: token,
    );
  } catch (e) {
    final message = e is String ? e : '获取媒体库失败：$e';
    // FutureProvider 会捕获异常，这里直接 rethrow 以便 UI 层用 AsyncValue 处理
    throw message;
  }
});
