// 媒体库模型：对应后端 Library

class Library {

  Library({
    required this.id,
    required this.name,
    required this.type,
    this.itemCount,
    this.coverImageUrl,
  });

  factory Library.fromJson(Map<String, dynamic> json) => Library(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? '',
        itemCount: json['item_count'] as int?,
        coverImageUrl: json['cover_image_url'] as String?,
      );
  final String id;
  final String name;
  final String type;
  final int? itemCount;
  final String? coverImageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'item_count': itemCount,
        'cover_image_url': coverImageUrl,
      };
}
