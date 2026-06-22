// 搜索建议模型：Emby SearchHints
class SearchHint {
  final String id;
  final String name;
  final String? type;          // 类型：Movie/Series/Episode/Person/MusicAlbum 等
  final String? thumbnailUrl;  // 缩略图 URL
  final int? year;
  final String? seriesName;    // 如果是剧集/集数

  const SearchHint({
    required this.id,
    required this.name,
    this.type,
    this.thumbnailUrl,
    this.year,
    this.seriesName,
  });

  factory SearchHint.fromJson(Map<String, dynamic> json) {
    // 同时支持 Emby 原生字段（PascalCase）与简化字段
    return SearchHint(
      id: (json['Id'] as String?) ?? (json['id'] as String?) ?? '',
      name: (json['Name'] as String?) ?? (json['name'] as String?) ?? '',
      type: (json['Type'] as String?) ?? (json['type'] as String?),
      thumbnailUrl: (json['ThumbnailUrl'] as String?) ??
          (json['thumbnail_url'] as String?) ??
          (json['thumbnailUrl'] as String?),
      year: (json['ProductionYear'] as int?) ?? (json['year'] as int?),
      seriesName: (json['SeriesName'] as String?) ??
          (json['series_name'] as String?) ??
          (json['seriesName'] as String?),
    );
  }
}
