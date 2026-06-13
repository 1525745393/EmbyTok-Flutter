// 媒体库模型：对应 Emby VirtualFolder

class Library {
  final String id;
  final String name;
  final String type; // 原始 CollectionType（可能为：movies, tvshows, music, homevideos, books, boxsets, mixed, 或空）
  final int? itemCount;
  final String? coverImageUrl;

  Library({
    required this.id,
    required this.name,
    required this.type,
    this.itemCount,
    this.coverImageUrl,
  });

  // 规范的 CollectionType getter：统一提供给 UI 层使用
  // 可能的值："movies", "tvshows", "music", "homevideos", "books", "boxsets", "mixed", ""
  String? get collectionType {
    if (type.isNotEmpty) return type;
    return null;
  }

  // UI 显示用：中文名
  String get displayType {
    switch (type.toLowerCase()) {
      case 'movies':
        return '电影';
      case 'tvshows':
        return '剧集';
      case 'homevideos':
        return '家庭视频';
      case 'music':
        return '音乐';
      case 'musicvideos':
        return '音乐视频';
      case 'boxsets':
        return '合集';
      case 'books':
        return '书籍';
      case 'mixed':
        return '混合';
      default:
        return '媒体库';
    }
  }

  // 从 Emby 原生响应格式解析
  factory Library.fromJson(Map<String, dynamic> json) {
    // Emby 常用字段：Id, Name, CollectionType, ItemId, RefreshProgress, 等
    final id = (json['Id'] as String?) ?? json['id'] as String? ?? '';
    final name = (json['Name'] as String?) ??
        json['name'] as String? ??
        '';
    // CollectionType 是 Emby 原生的类型标识
    final collectionType = (json['CollectionType'] as String?) ??
        json['type'] as String? ??
        '';
    return Library(
      id: id,
      name: name,
      type: collectionType,
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
