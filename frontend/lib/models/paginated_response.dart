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

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemFromJson,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? <dynamic>[];
    return PaginatedResponse<T>(
      items: rawItems.map((e) => itemFromJson(e)).toList(),
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items,
        'total': total,
        'offset': offset,
        'limit': limit,
      };
}
