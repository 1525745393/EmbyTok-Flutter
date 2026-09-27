// 深链接处理：识别 Emby Web URL 并提取 itemId
class DeepLinkParser {
  /// 从各类 Emby URL 中提取 itemId
  /// 支持格式：
  /// - /web/index.html#!/item/12345
  /// - /item/12345
  /// - ?itemId=12345
  static String? extractItemId(String url) {
    if (url.isEmpty) return null;

    // 格式：#!/item/{id}
    final hashMatch = RegExp(r'#!\/item\/([^\/?#]+)').firstMatch(url);
    if (hashMatch != null) return hashMatch.group(1);

    // 格式：/item/{id}
    final pathMatch = RegExp(r'\/item\/([^\/?#]+)').firstMatch(url);
    if (pathMatch != null) return pathMatch.group(1);

    // 格式：?itemId={id} 或 &itemId={id}
    final queryMatch = RegExp(r'[?&]itemId=([^&#]+)').firstMatch(url);
    if (queryMatch != null) return queryMatch.group(1);

    return null;
  }

  /// 判断是否为 Emby 相关 URL
  static bool isEmbyUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('/web/index.html') ||
        url.contains('/item/') ||
        RegExp(r'[?&]itemId=').hasMatch(url);
  }
}
