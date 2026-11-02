import '../models/models.dart';
import 'api_client.dart';

abstract interface class EmbyAuthApi {
  // 认证与用户相关
  // ============================

  /// 设置默认认证信息，后续调用可省略参数
  void setupAuth({
    required String embyServerUrl,
    required String apiKey,
    String? userId,
  });

  /// 清除认证信息
  void clearAuth();

  /// 底层 HTTP 客户端（供 auth 层注入 401 登出等全局行为）
  ApiClient get apiClient;

  /// 用户登录，返回用户信息和访问令牌
  Future<User> login({
    required String embyServerUrl,
    required String username,
    required String password,
  });
}
