// 人员（演员/导演/编剧）模型
class Person {
  final String name;
  final String? id;
  final String? role;        // 角色名（如 "主角"）
  final String type;          // 类型：Actor/Director/Writer 等
  final String? imageUrl;     // 头像图片 URL
  final int? itemId;          // 关联的媒体项 ID（如存在）

  const Person({
    required this.name,
    this.id,
    this.role = '',
    this.type = 'Actor',
    this.imageUrl,
    this.itemId,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    // 同时支持 Emby 原生字段（People 数组中）和简化字段
    return Person(
      name: (json['Name'] as String?) ?? (json['name'] as String?) ?? '',
      id: (json['Id'] as String?) ?? (json['id'] as String?),
      role: (json['Role'] as String?) ?? (json['role'] as String?) ?? '',
      type: (json['Type'] as String?) ?? (json['type'] as String?) ?? 'Actor',
      imageUrl: (json['ImageUrl'] as String?) ?? (json['image_url'] as String?) ?? (json['imageUrl'] as String?),
      itemId: (json['ItemId'] as int?) ?? (json['itemId'] as int?) ?? (json['item_id'] as int?),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
        'role': role,
        'type': type,
        'image_url': imageUrl,
        'item_id': itemId,
      };
}
