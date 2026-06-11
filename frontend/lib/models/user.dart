// 用户模型：封装登录后返回的用户信息

class User {
  final String id;
  final String name;
  final String accessToken;

  User({
    required this.id,
    required this.name,
    required this.accessToken,
  });

  // 从后端 snake_case JSON 字段解析
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['user_id'] as String? ?? '',
        name: json['username'] as String? ?? '',
        accessToken: json['access_token'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'username': name,
        'access_token': accessToken,
      };
}
