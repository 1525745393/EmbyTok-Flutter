// 泛型分页响应：items / total / offset / limit
// 同时支持 Emby 原生 PascalCase（Items/TotalRecordCount）与简化 snake_case

class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int offset;
  final int limit;

  PaginatedResponse({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  /// 同时支持 Emby 原生字段（Items、TotalRecordCount）
  /// 与简化字段（items、total、offset、limit）
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemFromJson,
  ) {
    final rawItems = (json['Items'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        <dynamic>[];
    final total = (json['TotalRecordCount'] as int?) ??
        (json['total'] as int?) ??
        0;
    final offset = (json['StartIndex'] as int?) ??
        (json['offset'] as int?) ??
        0;
    final limit = (json['Limit'] as int?) ??
        (json['limit'] as int?) ??
        20;
    return PaginatedResponse<T>(
      items: rawItems.map((e) => itemFromJson(e)).toList(),
      total: total,
      offset: offset,
      limit: limit,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items,
        'total': total,
        'offset': offset,
        'limit': limit,
      };
}
