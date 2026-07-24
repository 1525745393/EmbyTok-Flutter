import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/media_item.dart';
import 'package:embbytok_flutter/services/playback/playback_url_resolver.dart';
import 'package:embbytok_flutter/services/playback/emby_playback_url_resolver.dart';

void main() {
  const serverUrl = 'http://emby.example.com';
  const token = 'test-token';
  const itemId = 'item-123';

  MediaItem createItem({String? playbackUrl}) {
    return MediaItem(
      id: itemId,
      title: 'Test Video',
      type: 'Movie',
      playbackUrl: playbackUrl,
    );
  }

  group('EmbyPlaybackUrlResolver', () {
    test('返回三级 URL 列表', () {
      final resolver = EmbyPlaybackUrlResolver();
      final item = createItem();
      final urls = resolver.resolveUrls(item, serverUrl, token);

      expect(urls.length, 3);
      expect(urls[0], contains('/Videos/$itemId/stream?api_key='));
      expect(urls[0], contains('Static=true'));
      expect(urls[1], contains('/Videos/$itemId/stream.mp4?api_key='));
      expect(urls[1], contains('AllowVideoStreamCopy=true'));
      expect(urls[2], contains('/Videos/$itemId/master.m3u8?api_key='));
      expect(urls[2], contains('SegmentContainer=ts'));
    });

    test('serverUrl 为空时返回空列表', () {
      final resolver = EmbyPlaybackUrlResolver();
      final item = createItem();
      final urls = resolver.resolveUrls(item, '', token);

      expect(urls, isEmpty);
    });

    test('token 为空时返回空列表', () {
      final resolver = EmbyPlaybackUrlResolver();
      final item = createItem();
      final urls = resolver.resolveUrls(item, serverUrl, '');

      expect(urls, isEmpty);
    });

    test('playbackUrl 已存在时仍构造三级 URL', () {
      final resolver = EmbyPlaybackUrlResolver();
      final item = createItem(playbackUrl: 'http://direct.url/video.mp4');
      final urls = resolver.resolveUrls(item, serverUrl, token);

      expect(urls.length, 3);
    });

    test('传入 playSessionId 时 HLS URL 含会话参数', () {
      const sessionId = 'session-abc';
      final resolver = EmbyPlaybackUrlResolver(playSessionId: sessionId);
      final item = createItem();
      final urls = resolver.resolveUrls(item, serverUrl, token);

      expect(urls[2], contains('PlaySessionId=$sessionId'));
    });

    test('不传 playSessionId 时 HLS URL 不含会话参数', () {
      final resolver = EmbyPlaybackUrlResolver();
      final item = createItem();
      final urls = resolver.resolveUrls(item, serverUrl, token);

      expect(urls[2], isNot(contains('PlaySessionId=')));
    });
  });

  group('PlaybackUrlResolver 接口', () {
    test('自定义实现可按预期工作', () {
      final customResolver = _CustomResolver();
      final item = createItem();
      final urls = customResolver.resolveUrls(item, serverUrl, token);

      expect(urls, ['http://custom.stream/hls.m3u8']);
    });
  });
}

class _CustomResolver implements PlaybackUrlResolver {
  @override
  List<String> resolveUrls(MediaItem item, String serverUrl, String token) {
    return ['http://custom.stream/hls.m3u8'];
  }
}
