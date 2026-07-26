// 媒体服务器 API 适配层 Provider
//
// 提供 MediaServerApi 接口的全局实例，默认使用 EmbyServerApi 实现。
// 通过此 Provider 可以实现服务端实现的可替换（如未来支持 Jellyfin、Plex 等），
// 测试时也可以通过 overrideWithValue 替换为 mock 实现。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/emby_server_api.dart';
import '../services/media_server_api.dart';

/// 全局 MediaServerApi 实例
///
/// 默认提供 EmbyServerApi 实现，测试或需要替换服务端时可 override。
final mediaServerApiProvider = Provider<MediaServerApi>((ref) => EmbyServerApi());
