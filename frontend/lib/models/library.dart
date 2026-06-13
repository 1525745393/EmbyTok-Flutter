// 媒体库模型：对应 Emby VirtualFolder

class Library {
  final String id;
  final String name;
  final String type;
  final int? itemCount;
  final String? coverImageUrl;

  Library({
    required this.id,
    required this.name,
    required this.type,
    this.itemCount,
    this.coverImageUrl,
  });

  // 从 Emby 原生响应格式解析：
  // {
  //   "Id": "...",
  //   "Name": "...",
  //   "CollectionType": "movies" | "tvshows" | "music" | "homevideos" | ...,
  //   "ItemId": "...",
  //   ...
  // }
  // 同时兼容后端 snake_case 格式（向前兼容）
  factory Library.fromJson(Map<String, dynamic> json) {
    // 优先使用 Emby 格式，其次使用后端格式
    final id = (json['Id'] as String?) ?? json['id'] as String? ?? '';
    final name =
        (json['Name'] as String?) ?? json['name'] as String? ?? '';
    final type = (json['CollectionType'] as String?) ??
        json['type'] as String? ??
        '';
    return Library(
      id: id,
      name: name,
      type: type,
      itemCount: json['item_count'] as int? ??
          (json['RefreshProgress'] as int?),
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'item_count': itemCount,
        'cover_image_url': coverImageUrl,
      };
}
