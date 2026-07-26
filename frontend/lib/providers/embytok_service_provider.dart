// 全局 EmbytokService Provider
//
// 统一管理 EmbytokService 的生命周期，替代原有的单例模式。
// 所有需要访问 EmbytokService 的地方都应通过 ref.watch(embytokServiceProvider) 获取，
// 测试时通过 ProviderScope.overrides 替换为 mock 实现。
//
// 依赖关系：embytokServiceProvider -> mediaServerApiProvider
// 通过依赖注入实现服务端实现的可替换。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/embytok_service.dart';
import 'media_server_api_provider.dart';

/// 全局 EmbytokService 实例
///
/// 从 mediaServerApiProvider 获取适配层实例，实现服务端实现的可替换。
final embytokServiceProvider = Provider<EmbytokService>((ref) {
  final api = ref.watch(mediaServerApiProvider);
  return EmbytokService(api: api);
});
