import 'dart:async';
import '../../models/media_item.dart';
import 'i_playback_controller.dart';
import 'playback_url_resolver.dart';
import 'vlc_controller_adapter.dart';

class ControllerFactory {
  final PlaybackUrlResolver urlResolver;

  ControllerFactory({required this.urlResolver});

  Future<IPlaybackController?> create(
    MediaItem item,
    String serverUrl,
    String token,
  ) async {
    final urls = urlResolver.resolveUrls(item, serverUrl, token);
    for (final url in urls) {
      if (url.isEmpty) continue;
      try {
        final adapter = await VlcControllerAdapter.networkUrl(
          url,
          httpHeaders: item.authHeaders(token),
        );
        await adapter.initialize().timeout(const Duration(seconds: 12));
        return adapter;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
