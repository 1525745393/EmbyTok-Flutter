/// 服务端播放进度拉取测试 (TDD)
/// 测试 getPlaybackPosition 能否正确从服务端拉取最新播放进度，
/// 用于播放开始时实现多端进度互通。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:embytok_flutter/services/api_client.dart';
import 'package:embytok_flutter/services/embytok_service.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late ApiClient apiClient;
  late EmbytokService service;

  const testEmbyUrl = 'http://emby.example.com';
  const testToken = 'test-access-token';
  const testUserId = 'user-abc-123';
  const testItemId = 'item-123';

  // getItemDetail 使用的 Fields 参数（与 emby_server_api.dart 中保持一致）
  const itemDetailFields =
      'Overview,Genres,People,CommunityRating,CriticRating,OfficialRating,'
      'RunTimeTicks,ProductionYear,PremiereDate,DateCreated,Studios,'
      'MediaSources,UserData,ParentIndexNumber,IndexNumber,SeriesName,'
      'SeasonName,SeriesId,SeasonId,ImageTags,BackdropImageTags';

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    apiClient = ApiClient.withDio(dio);
    service = EmbytokService.withClient(apiClient);
  });

  // 构造 Emby 原生 PascalCase 的单个媒体项响应
  Map<String, dynamic> buildMediaItemJson({
    required String id,
    required String name,
    required String type,
    int? runTimeTicks,
    Map<String, dynamic>? userData,
  }) {
    return <String, dynamic>{
      'Id': id,
      'Name': name,
      'Type': type,
      if (runTimeTicks != null) 'RunTimeTicks': runTimeTicks,
      if (userData != null) 'UserData': userData,
    };
  }

  group('getPlaybackPosition - 服务端播放进度拉取', () {
    test('正常返回进度：UserData 中包含 PlaybackPositionTicks 时返回正确值',
        () async {
      const expectedTicks = 18000000000; // 30 分钟进度（ticks）
      final response = buildMediaItemJson(
        id: testItemId,
        name: '测试电影',
        type: 'Movie',
        runTimeTicks: 72000000000, // 总时长 2 小时
        userData: <String, dynamic>{
          'PlaybackPositionTicks': expectedTicks,
          'IsFavorite': false,
          'Played': false,
          'PlayCount': 1,
        },
      );

      dioAdapter
          .onGet('/Users/$testUserId/Items/$testItemId', (server) => server.reply(200, response), queryParameters: <String, dynamic>{'Fields': itemDetailFields});

      final ticks = await service.getPlaybackPosition(
        testItemId,
        userId: testUserId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(ticks, expectedTicks);
    });

    test('无播放记录：UserData 为 null 时返回 0', () async {
      // 响应中不包含 UserData 字段，MediaItem.userData 将为 null
      final response = buildMediaItemJson(
        id: testItemId,
        name: '未播放电影',
        type: 'Movie',
        runTimeTicks: 72000000000,
      );

      dioAdapter
          .onGet('/Users/$testUserId/Items/$testItemId', (server) => server.reply(200, response), queryParameters: <String, dynamic>{'Fields': itemDetailFields});

      final ticks = await service.getPlaybackPosition(
        testItemId,
        userId: testUserId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(ticks, 0);
    });

    test('playbackPositionTicks 为 0 时返回 0', () async {
      // UserData 存在但 PlaybackPositionTicks 为 0（从未播放过）
      final response = buildMediaItemJson(
        id: testItemId,
        name: '未播放电影',
        type: 'Movie',
        runTimeTicks: 72000000000,
        userData: <String, dynamic>{
          'PlaybackPositionTicks': 0,
          'IsFavorite': false,
          'Played': false,
          'PlayCount': 0,
        },
      );

      dioAdapter
          .onGet('/Users/$testUserId/Items/$testItemId', (server) => server.reply(200, response), queryParameters: <String, dynamic>{'Fields': itemDetailFields});

      final ticks = await service.getPlaybackPosition(
        testItemId,
        userId: testUserId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(ticks, 0);
    });

    test('网络错误时返回 0 不抛出异常', () async {
      // 模拟网络连接错误
      dioAdapter.onGet(
        '/Users/$testUserId/Items/$testItemId',
        (server) => server.throws(
          500,
          DioException(
            requestOptions:
                RequestOptions(path: '/Users/$testUserId/Items/$testItemId'),
            type: DioExceptionType.connectionError,
            message: 'Connection failed',
          ),
        ),
        queryParameters: <String, dynamic>{'Fields': itemDetailFields},
      );

      // 不应抛出异常，而应返回 0
      final ticks = await service.getPlaybackPosition(
        testItemId,
        userId: testUserId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(ticks, 0);
    });

    test('服务器返回 500 错误时返回 0 不抛出异常', () async {
      dioAdapter
          .onGet('/Users/$testUserId/Items/$testItemId', (server) => server.reply(500, <String, dynamic>{
            'detail': '服务器内部错误',
          }), queryParameters: <String, dynamic>{'Fields': itemDetailFields});

      final ticks = await service.getPlaybackPosition(
        testItemId,
        userId: testUserId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(ticks, 0);
    });

    test('无 userId 时降级到 /Items/{id} 路径并正确返回进度', () async {
      const expectedTicks = 9000000000; // 15 分钟进度
      final response = buildMediaItemJson(
        id: testItemId,
        name: '测试电影',
        type: 'Movie',
        runTimeTicks: 72000000000,
        userData: <String, dynamic>{
          'PlaybackPositionTicks': expectedTicks,
        },
      );

      dioAdapter
          .onGet('/Items/$testItemId', (server) => server.reply(200, response), queryParameters: <String, dynamic>{'Fields': itemDetailFields});

      final ticks = await service.getPlaybackPosition(
        testItemId,
        serverUrl: testEmbyUrl,
        token: testToken,
      );

      expect(ticks, expectedTicks);
    });
  });
}
