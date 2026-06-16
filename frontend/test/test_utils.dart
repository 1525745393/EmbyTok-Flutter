/// 测试用 JSON fixtures
class TestFixtures {
  static Map<String, dynamic> userJson({
    String userId = 'user-123',
    String username = 'testuser',
    String accessToken = 'test-token-abc',
  }) {
    return {
      'user_id': userId,
      'username': username,
      'access_token': accessToken,
    };
  }

  static Map<String, dynamic> libraryJson({
    String id = 'lib-1',
    String name = '电影',
    String type = 'movies',
    int? itemCount = 100,
    String? coverImageUrl,
  }) {
    return {
      'id': id,
      'name': name,
      'type': type,
      'item_count': itemCount,
      'cover_image_url': coverImageUrl,
    };
  }

  static Map<String, dynamic> mediaItemJson({
    String id = 'item-1',
    String title = '测试视频',
    String type = 'Movie',
    double? durationSeconds = 7200.0,
    String? thumbnailUrl,
    String? overview,
    int? year,
    double? rating,
    List<String>? genres,
  }) {
    return {
      'id': id,
      'title': title,
      'type': type,
      'duration_seconds': durationSeconds,
      'thumbnail_url': thumbnailUrl,
      'overview': overview,
      'year': year,
      'rating': rating,
      'genres': genres,
    };
  }

  static Map<String, dynamic> paginatedResponseJson({
    List<Map<String, dynamic>> items = const [],
    int total = 0,
    int offset = 0,
    int limit = 20,
  }) {
    return {
      'items': items,
      'total': total,
      'offset': offset,
      'limit': limit,
    };
  }
}

/// 测试常量
class TestConstants {
  static const String testBackendUrl = 'http://localhost:8000';
  static const String testEmbyUrl = 'http://emby.example.com';
  static const String testToken = 'test-access-token';
  static const String testUserId = 'user-123';
}
