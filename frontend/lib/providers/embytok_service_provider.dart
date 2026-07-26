// 全局 EmbytokService Provider
//
// 统一管理 EmbytokService 的生命周期，替代原有的单例模式。
// 所有需要访问 EmbytokService 的地方都应通过 ref.watch(embytokServiceProvider) 获取，
// 测试时通过 ProviderScope.overrides 替换为 mock 实现。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/embytok_service.dart';

/// 全局 EmbytokService 实例
final embytokServiceProvider = Provider<EmbytokService>((ref) => EmbytokService());
