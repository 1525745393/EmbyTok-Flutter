import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/models/media_item.dart';
import 'package:embbytok_flutter/models/media_source.dart';

void main() {
  group('MediaItem', () {
    group('fromJson', () {
      test('正确解析完整 JSON', () {
        final json = {
          'id': 'item-1',
          'title': '测试电影',
          'type': 'Movie',
          'duration_seconds': 7200.0,
          'thumbnail_url': 'http://example.com/thumb.jpg',
          'overview': '这是一部测试电影',
          'year': 2023,
          'rating': 8.5,
          'genres': ['动作', '科幻'],
          'playback_url': 'http://example.com/video.mp4',
        };
        final item = MediaItem.fromJson(json);
        expect(item.id, 'item-1');
        expect(item.title, '测试电影');
        expect(item.type, 'Movie');
        expect(item.durationSeconds, 7200.0);
        expect(item.thumbnailUrl, 'http://example.com/thumb.jpg');
        expect(item.overview, '这是一部测试电影');
        expect(item.year, 2023);
        expect(item.rating, 8.5);
        expect(item.genres, ['动作', '科幻']);
        expect(item.playbackUrl, 'http://example.com/video.mp4');
      });

      test('处理可选字段为 null', () {
        final json = {
          'id': 'item-2',
          'title': '简单视频',
          'type': 'Episode',
        };
        final item = MediaItem.fromJson(json);
        expect(item.id, 'item-2');
        expect(item.title, '简单视频');
        expect(item.type, 'Episode');
        expect(item.durationSeconds, isNull);
        expect(item.thumbnailUrl, isNull);
        expect(item.overview, isNull);
        expect(item.year, isNull);
        expect(item.rating, isNull);
        expect(item.genres, isNull);
        expect(item.playbackUrl, isNull);
      });

      test('处理空 JSON', () {
        final json = <String, dynamic>{};
        final item = MediaItem.fromJson(json);
        expect(item.id, '');
        expect(item.title, '');
        expect(item.type, '');
      });

      test('正确解析 genres 列表', () {
        final json = {
          'id': 'item-3',
          'title': '测试',
          'type': 'Movie',
          'genres': ['喜剧', '爱情', '动画'],
        };
        final item = MediaItem.fromJson(json);
        expect(item.genres, hasLength(3));
        expect(item.genres, containsAll(['喜剧', '爱情', '动画']));
      });
    });

    group('toJson', () {
      test('正确序列化为 JSON', () {
        final item = MediaItem(
          id: 'item-1',
          title: '测试',
          type: 'Movie',
          durationSeconds: 3600.0,
          year: 2024,
        );
        final json = item.toJson();
        expect(json['id'], 'item-1');
        expect(json['title'], '测试');
        expect(json['type'], 'Movie');
        expect(json['duration_seconds'], 3600.0);
        expect(json['year'], 2024);
        expect(json['thumbnail_url'], isNull);
      });
    });

    group('播放 URL 计算方法', () {
      test('computePlaybackUrl 生成正确的 DirectPlay URL', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        final url = item.computePlaybackUrl('http://emby.example.com', 'test-token');
        expect(url, 'http://emby.example.com/Videos/video-123/stream?api_key=test-token&Static=true');
      });

      test('computePlaybackUrl 缺少 serverUrl 返回 null', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        expect(item.computePlaybackUrl(null, 'test-token'), isNull);
        expect(item.computePlaybackUrl('', 'test-token'), isNull);
      });

      test('computePlaybackUrl 缺少 token 返回 null', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        expect(item.computePlaybackUrl('http://emby.example.com', null), isNull);
        expect(item.computePlaybackUrl('http://emby.example.com', ''), isNull);
      });

      test('computeDirectStreamUrl 生成正确的 DirectStream URL', () {
        final mediaSource = MediaSource(
          id: 'ms-001',
          container: 'mkv',
          width: 1920,
          height: 1080,
        );
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
          mediaSources: [mediaSource],
        );
        final url = item.computeDirectStreamUrl('http://emby.example.com', 'test-token');
        expect(url, contains('http://emby.example.com/Videos/video-123/stream.mp4'));
        expect(url, contains('api_key=test-token'));
        expect(url, contains('MediaSourceId=ms-001'));
        expect(url, contains('VideoCodec=h264,hevc,av1'));
      });

      test('computeDirectStreamUrl 无 mediaSource 时不包含 MediaSourceId', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        final url = item.computeDirectStreamUrl('http://emby.example.com', 'test-token');
        expect(url, contains('api_key=test-token'));
        expect(url, isNot(contains('MediaSourceId=')));
      });

      test('computeHlsUrl 生成正确的 HLS 转码 URL', () {
        final mediaSource = MediaSource(
          id: 'ms-001',
          container: 'mkv',
          width: 1920,
          height: 1080,
        );
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
          mediaSources: [mediaSource],
        );
        final url = item.computeHlsUrl('http://emby.example.com', 'test-token', playSessionId: 'session-abc');
        expect(url, contains('http://emby.example.com/Videos/video-123/master.m3u8'));
        expect(url, contains('api_key=test-token'));
        expect(url, contains('PlaySessionId=session-abc'));
        expect(url, contains('TranscodingMaxAudioChannels=2'));
      });

      test('computeHlsUrl 不带 playSessionId 也能工作', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        final url = item.computeHlsUrl('http://emby.example.com', 'test-token');
        expect(url, contains('api_key=test-token'));
        expect(url, isNot(contains('PlaySessionId=')));
      });
    });

    group('authHeaders', () {
      test('有 token 时返回正确的认证头', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        final headers = item.authHeaders('my-token');
        expect(headers['X-Emby-Token'], 'my-token');
      });

      test('无 token 时返回空 map', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
        );
        expect(item.authHeaders(null), isEmpty);
        expect(item.authHeaders(''), isEmpty);
      });
    });

    group('progressPercent', () {
      test('有播放进度时正确计算百分比', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
          runtimeTicks: 10000000, // 1秒
          userData: UserData(playbackPositionTicks: 5000000),
        );
        expect(item.progressPercent, 0.5);
      });

      test('无播放进度时返回 0', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
          runtimeTicks: 10000000,
        );
        expect(item.progressPercent, 0.0);
      });

      test('播放进度超过时长时 clamp 到 1.0', () {
        final item = MediaItem(
          id: 'video-123',
          title: '测试视频',
          type: 'Movie',
          runtimeTicks: 10000000,
          userData: UserData(playbackPositionTicks: 15000000),
        );
        expect(item.progressPercent, 1.0);
      });
    });
  });
}
