import 'package:url_launcher/url_launcher.dart';

/// 第三方播放器信息
class ExternalPlayerInfo {
  const ExternalPlayerInfo({
    required this.packageName,
    required this.displayName,
    this.scheme,
    this.mimeType = 'video/*',
  });

  final String packageName;
  final String displayName;
  final String? scheme; // URL scheme（如 vlc://）
  final String? mimeType;
}

/// 已支持的第三方播放器列表
const List<ExternalPlayerInfo> knownExternalPlayers = [
  ExternalPlayerInfo(
    packageName: 'org.videolan.vlc',
    displayName: 'VLC',
    scheme: 'vlc',
  ),
  ExternalPlayerInfo(
    packageName: 'com.mxtech.videoplayer.ad',
    displayName: 'MX Player',
  ),
  ExternalPlayerInfo(
    packageName: 'com.mxtech.videoplayer.pro',
    displayName: 'MX Player Pro',
  ),
  ExternalPlayerInfo(
    packageName: 'com.google.android.videos',
    displayName: 'Google TV',
  ),
];

/// 第三方播放器兜底服务
///
/// 当内置播放器无法解码时，通过 Android Intent 唤起已安装的第三方播放器播放视频流。
/// 使用 url_launcher 的 VIEW action + 指定 package 实现。
class ExternalPlayerService {
  /// 用指定第三方播放器播放视频 URL
  ///
  /// [videoUrl] 视频流地址
  /// [title] 视频标题（部分播放器会显示）
  /// [packageName] 指定播放器包名，为空则让系统选择
  /// [subtitlesUrl] 外挂字幕 URL（可选）
  static Future<bool> play({
    required String videoUrl,
    String? title,
    String? packageName,
    String? subtitlesUrl,
  }) async {
    // 构造 VIEW Intent URL
    // Android: intent: ...#Intent;action=android.intent.action.VIEW;type=video/*;end
    final buf = StringBuffer();
    buf.write('intent://');
    buf.write(Uri.parse(videoUrl).host);
    buf.write(Uri.parse(videoUrl).path);
    final queryParams = <String, String>{};
    if (Uri.parse(videoUrl).query.isNotEmpty) {
      queryParams.addAll(Uri.parse(videoUrl).queryParameters);
    }
    queryParams['title'] = title ?? '';
    if (subtitlesUrl != null) {
      queryParams['subtitles'] = subtitlesUrl;
    }
    buf.write('?');
    buf.write(queryParams.entries.map((e) => '${e.key}=${e.value}').join('&'));
    buf.write('#Intent;');
    buf.write('action=android.intent.action.VIEW;');
    buf.write('type=video/*;');
    buf.write('scheme=${Uri.parse(videoUrl).scheme};');
    if (packageName != null && packageName.isNotEmpty) {
      buf.write('package=$packageName;');
    }
    buf.write('S.browser_fallback_url=${Uri.encodeComponent(videoUrl)};');
    buf.write('end');

    final intentUri = Uri.parse(buf.toString());

    try {
      if (await canLaunchUrl(intentUri)) {
        await launchUrl(intentUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // 忽略，回退到直接打开 URL
    }

    // 回退：直接用浏览器/外部应用打开 URL
    final fallbackUri = Uri.parse(videoUrl);
    try {
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// 弹出选择播放器对话框（由 UI 层调用）
  /// 返回用户选择的播放器包名，取消返回 null
  static List<ExternalPlayerInfo> get availablePlayers => knownExternalPlayers;
}
