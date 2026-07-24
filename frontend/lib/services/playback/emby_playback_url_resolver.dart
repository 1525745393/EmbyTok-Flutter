import '../../models/media_item.dart';
import 'playback_url_resolver.dart';

class EmbyPlaybackUrlResolver implements PlaybackUrlResolver {
  final String? playSessionId;

  EmbyPlaybackUrlResolver({this.playSessionId});

  @override
  List<String> resolveUrls(MediaItem item, String serverUrl, String token) {
    final urls = <String>[];

    final directPlay = item.computePlaybackUrl(serverUrl, token);
    if (directPlay != null && directPlay.isNotEmpty) {
      urls.add(directPlay);
    }

    final directStream = item.computeDirectStreamUrl(serverUrl, token);
    if (directStream != null && directStream.isNotEmpty) {
      urls.add(directStream);
    }

    final hls = item.computeHlsUrl(serverUrl, token, playSessionId: playSessionId);
    if (hls != null && hls.isNotEmpty) {
      urls.add(hls);
    }

    return urls;
  }
}
