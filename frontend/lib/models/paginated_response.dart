// 泛型分页响应：items / total / offset / limit
// 通过 itemFromJson 回调将 dynamic 转为具体类型 T

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

  // 从后端 snake_case 格式解析
  // {"items": [...], "total": N, "offset": 0, "limit": 20}
  //
  // 同时兼容 Emby 原生格式：
  // {"Items": [...], "TotalRecordCount": N}
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemFromJson,
  ) {
    // 先尝试 Emby 格式（Items / TotalRecordCount）
    final embyItems = json['Items'] as List<dynamic>?;
    final embyTotal = json['TotalRecordCount'] as int?;

    List<T> items;
    int total;

    if (embyItems != null) {
      // Emby 原生格式
      items = embyItems.map((e) => itemFromJson(e)).toList();
      total = embyTotal ?? items.length;
    } else {
      // 后端 snake_case 格式（向后兼容）
      final rawItems = json['items'] as List<dynamic>? ?? <dynamic>[];
      items = rawItems.map((e) => itemFromJson(e)).toList();
      total = json['total'] as int? ?? 0;
    }

    final offset = json['offset'] as int? ?? 0;
    final limit = json['limit'] as int? ?? 20;

    return PaginatedResponse<T>(
      items: items,
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
