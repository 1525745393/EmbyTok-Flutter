// 应用配置模型：持久化到本地存储中的用户配置

class AppConfig {
  final String backendUrl;
  final String embyServerUrl;
  final String userId;
  final String userName;
  final String themeMode;
  final bool subtitleEnabled;

  AppConfig({
    required this.backendUrl,
    required this.embyServerUrl,
    required this.userId,
    required this.userName,
    required this.themeMode,
    required this.subtitleEnabled,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        backendUrl: json['backend_url'] as String? ?? '',
        embyServerUrl: json['emby_server_url'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        userName: json['user_name'] as String? ?? '',
        themeMode: json['theme_mode'] as String? ?? 'system',
        subtitleEnabled: json['subtitle_enabled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'backend_url': backendUrl,
        'emby_server_url': embyServerUrl,
        'user_id': userId,
        'user_name': userName,
        'theme_mode': themeMode,
        'subtitle_enabled': subtitleEnabled,
      };
}
