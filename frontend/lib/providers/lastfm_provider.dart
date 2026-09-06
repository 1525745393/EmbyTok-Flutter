// Last.fm Provider：API Key 配置（SharedPreferences）+ 服务单例
//
// - lastfmApiKeyProvider：从本地存储读取 Last.fm API Key（空 = 未配置）
// - lastfmServiceProvider：有 Key 时创建 LastFmService 单例；
//   未配置 Key 时返回 null（调用方跳过 Last.fm，不影响主流程）
//
// Key 来源：设置页 → 服务器 → Last.fm（https://www.last.fm/api/account/create 免费申请）

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lastfm_service.dart';

/// 存储 Key 名（设置页读写同一常量）
const kStorageKeyLastFmApiKey = 'lastfm_api_key';

/// 异步读取 Last.fm API Key（空字符串 = 未配置）
final lastfmApiKeyAsyncProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(kStorageKeyLastFmApiKey) ?? '';
});

/// 保存 Last.fm API Key（返回是否成功）
Future<bool> saveLastFmApiKey(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(kStorageKeyLastFmApiKey, key.trim());
  } catch (_) {
    return false;
  }
}

/// Last.fm 服务单例（未配置 Key 时为 null）
///
/// 依赖 Key：Key 变化（重新进入 App / 刷新）后重新创建服务。
final lastfmServiceProvider = Provider<LastFmService?>((ref) {
  final keyAsync = ref.watch(lastfmApiKeyAsyncProvider);
  final key = keyAsync.valueOrNull ?? '';
  if (key.isEmpty) return null;
  final service = LastFmService(apiKey: key);
  ref.onDispose(service.dispose);
  return service;
});
