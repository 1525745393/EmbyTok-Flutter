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

  // 从 Emby 原生响应格式解析：
  // {
  //   "User": {"Id": "...", "Name": "..."},
  //   "AccessToken": "...",
  //   ...
  // }
  factory User.fromJson(Map<String, dynamic> json) {
    final userObj = json['User'] as Map<String, dynamic>?;
    return User(
      id: (userObj?['Id'] as String?) ?? json['user_id'] as String? ?? '',
      name: (userObj?['Name'] as String?) ??
          json['username'] as String? ??
          '',
      accessToken: (json['AccessToken'] as String?) ??
          json['access_token'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'username': name,
        'access_token': accessToken,
      };
}
