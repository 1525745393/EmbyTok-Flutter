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
  final embyServerUrl = auth.embyServerUrl;
  final userId = auth.user?.id;
  final token = auth.token;

  if (!auth.isAuthenticated ||
      embyServerUrl == null ||
      userId == null ||
      token == null) {
    return <Library>[];
  }

  final service = EmbytokService();
  service.setupAuth(
    embyServerUrl: embyServerUrl,
    userId: userId,
    apiKey: token,
  );
  try {
    return await service.getLibraries();
  } catch (e) {
    final message = e is String ? e : '获取媒体库失败：$e';
    throw message;
  }
});
