// 媒体库模型：对应 Emby /Library/VirtualFolders 返回的 VirtualFolder

import '../utils/constants.dart';

class Library {
  final String id;
  final String name;
  final String type; // 对应 Emby 的 CollectionType：movies/tvshows/homevideos/photos/...
  final int? itemCount;
  final String? coverImageUrl;

  Library({
    required this.id,
    required this.name,
    required this.type,
    this.itemCount,
    this.coverImageUrl,
  });

  // 同时支持 Emby 原生字段（Id/Name/CollectionType）和 snake_case（id/name/type）
  factory Library.fromJson(Map<String, dynamic> json) {
    final id =
        (json['Id'] as String?) ?? (json['id'] as String?) ?? '';
    final name =
        (json['Name'] as String?) ?? (json['name'] as String?) ?? '';
    final type =
        (json['CollectionType'] as String?) ??
        (json['type'] as String?) ??
        '';
    return Library(
      id: id,
      name: name,
      type: type.isEmpty ? kLibraryTypeMixed : type.toLowerCase(),
      itemCount: (json['item_count'] as int?) ?? (json['ItemCount'] as int?),
      coverImageUrl: (json['cover_image_url'] as String?) ??
          (json['coverImageUrl'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'item_count': itemCount,
        'cover_image_url': coverImageUrl,
      };

  // ========== 派生属性 ==========

  // 中文显示类型名称（如：电影、剧集、家庭视频、照片）；
  // 未知类型回退为库名（避免显示奇怪的内容）
  String get displayTypeName =>
      libraryDisplayLabel(type, fallback: name);

  // 是否为图片库（照片）
  bool get isPhotoLibrary => isPhotoLibraryType(type);

  // 是否为视频类库（电影、剧集、家庭视频、音乐视频、混合）
  bool get isVideoLibrary => isVideoLibraryType(type);

  // 对应的 IncludeItemTypes 查询参数值
  String get includeItemTypes => includeItemTypesForLibraryType(type);
}
