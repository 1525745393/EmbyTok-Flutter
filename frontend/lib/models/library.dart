// 媒体库模型：对应后端 Library

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

  factory Library.fromJson(Map<String, dynamic> json) => Library(
        id: (json['Id'] as String?) ??
            (json['ItemId'] as String?) ??
            (json['id'] as String?) ??
            '',
        name: (json['Name'] as String?) ?? (json['name'] as String?) ?? '',
        type: (json['CollectionType'] as String?) ??
            (json['type'] as String?) ??
            'movies',
        itemCount: (json['ItemCount'] as int?) ?? (json['item_count'] as int?),
        coverImageUrl: (json['ImageUrl'] as String?) ??
            (json['cover_image_url'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'item_count': itemCount,
        'cover_image_url': coverImageUrl,
      };
}
