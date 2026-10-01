import 'dart:io';

import '../models/local_video_item.dart';

/// SMB 扫描器（P0 增强）
///
/// 当前实现：TCP 连通性测试 + 基础目录结构预留。
/// 完整 SMB1/2 协议浏览需要原生插件（JCIFS/libsmbclient），后续接入。
class SmbScanner {
  /// 测试 SMB 主机连通性
  /// 返回 null 表示成功，否则返回错误信息
  static Future<String?> testConnection({
    required String host,
    int port = 445,
    String? username,
    String? password,
    String? share,
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.destroy();
      return null; // 连通
    } on SocketException catch (e) {
      return '无法连接 $host:$port — ${e.message}';
    } catch (e) {
      return '连接失败: $e';
    }
  }

  /// 扫描 SMB 共享目录中的视频文件
  ///
  /// 当前为骨架：连通性测试通过后返回空列表，等待原生 SMB 插件接入后补全文件遍历。
  static Future<List<LocalVideoItem>> scan({
    required String sourceId,
    required String host,
    int port = 445,
    String? username,
    String? password,
    String? share,
    String? path,
  }) async {
    final error = await testConnection(
      host: host,
      port: port,
      username: username,
      password: password,
      share: share,
    );
    if (error != null) {
      throw Exception(error);
    }
    // TODO: 接入 libsmbclient / JCIFS 后遍历共享目录
    // 视频扩展名与 WebDAV 保持一致
    return [];
  }
}
