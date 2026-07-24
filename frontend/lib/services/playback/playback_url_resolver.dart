import '../../models/media_item.dart';

abstract class PlaybackUrlResolver {
  List<String> resolveUrls(MediaItem item, String serverUrl, String token);
}
