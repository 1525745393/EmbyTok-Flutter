// 歌手信息聚合缓存单元测试
//
// 验证：
// - Last.fm 命中：头像/简介出处均为 lastfm
// - Last.fm 无记录：群晖 URL（未登录时为 null）+ Wikipedia 简介兜底
// - 全无数据：来源 none（UI 首字母兜底）
// - 缓存：同歌手两次查询只发一次网络请求
// - 并发：同时查询同一歌手共享同一个 future

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/providers/artist_info_provider.dart';
import 'package:embytok_flutter/providers/lastfm_provider.dart';
import 'package:embytok_flutter/providers/synology_auth_provider.dart';
import 'package:embytok_flutter/services/artist_info_service.dart';
import 'package:embytok_flutter/services/lastfm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Last.fm artist.getinfo 成功响应
  http.Response lastfmOk(String artist) => http.Response(
        jsonEncode({
          'artist': {
            'name': artist,
            'image': [
              {
                '#text': 'https://lastfm.example/$artist.png',
                'size': 'extralarge'
              },
            ],
            'bio': {
              'summary': '$artist 是知名歌手。',
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('Last.fm 命中：头像与简介出处均为 lastfm', () async {
    var lastfmReq = 0;
    var wikiReq = 0;
    final container = ProviderContainer(overrides: [
      lastfmServiceProvider.overrideWith((ref) => LastFmService(
            apiKey: 'k',
            client: MockClient((request) async {
              lastfmReq++;
              return lastfmOk('周杰伦');
            }),
          )),
      artistInfoServiceProvider.overrideWith((ref) => ArtistInfoService(
            client: MockClient((request) async {
              wikiReq++;
              return http.Response('', 404);
            }),
          )),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(artistInfoCacheProvider).get('周杰伦');

    expect(result.imageUrl, 'https://lastfm.example/周杰伦.png');
    expect(result.imageSource, ArtistInfoSource.lastfm);
    expect(result.bio, contains('周杰伦'));
    expect(result.bioSource, ArtistInfoSource.lastfm);
    // Last.fm 命中后不再请求 Wikipedia
    expect(wikiReq, 0);
    expect(lastfmReq, 1);
  });

  test('Last.fm 未配置：头像无（未登录无群晖 URL），简介 Wikipedia 兜底', () async {
    var lastfmReq = 0;
    final container = ProviderContainer(overrides: [
      // 未配置 API Key → lastfmServiceProvider 为 null
      lastfmApiKeyAsyncProvider.overrideWith((ref) async => ''),
      artistInfoServiceProvider.overrideWith((ref) => ArtistInfoService(
            client: MockClient((request) async {
              lastfmReq++;
              return http.Response(
                jsonEncode({'title': '周杰伦', 'extract': '周杰伦，中国台湾歌手。'}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          )),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(artistInfoCacheProvider).get('周杰伦');

    expect(result.imageUrl, isNull);
    expect(result.imageSource, ArtistInfoSource.none);
    expect(result.bio, contains('周杰伦'));
    expect(result.bioSource, ArtistInfoSource.wikipedia);
    expect(lastfmReq, 1);
  });

  test('全无数据：来源均为 none（UI 首字母兜底）', () async {
    final container = ProviderContainer(overrides: [
      lastfmApiKeyAsyncProvider.overrideWith((ref) async => ''),
      artistInfoServiceProvider.overrideWith((ref) => ArtistInfoService(
            client: MockClient((request) async => http.Response('', 404)),
          )),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(artistInfoCacheProvider).get('冷门歌手XYZ');

    expect(result.imageUrl, isNull);
    expect(result.imageSource, ArtistInfoSource.none);
    expect(result.bio, isNull);
    expect(result.bioSource, ArtistInfoSource.none);
  });

  test('缓存：同歌手两次查询只发一次 Last.fm 请求', () async {
    var lastfmReq = 0;
    final container = ProviderContainer(overrides: [
      lastfmServiceProvider.overrideWith((ref) => LastFmService(
            apiKey: 'k',
            client: MockClient((request) async {
              lastfmReq++;
              return lastfmOk('王菲');
            }),
          )),
      artistInfoServiceProvider.overrideWith((ref) => ArtistInfoService(
            client: MockClient((request) async => http.Response('', 404)),
          )),
    ]);
    addTearDown(container.dispose);
    final cache = container.read(artistInfoCacheProvider);

    await cache.get('王菲');
    await cache.get('王菲');

    expect(lastfmReq, 1, reason: '缓存命中不应重复请求');
  });

  test('并发：同时查询同一歌手共享同一个 future（只发一次请求）', () async {
    var lastfmReq = 0;
    final container = ProviderContainer(overrides: [
      lastfmServiceProvider.overrideWith((ref) => LastFmService(
            apiKey: 'k',
            client: MockClient((request) async {
              lastfmReq++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return lastfmOk('泰勒');
            }),
          )),
      artistInfoServiceProvider.overrideWith((ref) => ArtistInfoService(
            client: MockClient((request) async => http.Response('', 404)),
          )),
    ]);
    addTearDown(container.dispose);
    final cache = container.read(artistInfoCacheProvider);

    final results = await Future.wait([
      cache.get('泰勒'),
      cache.get('泰勒'),
      cache.get('泰勒'),
    ]);

    expect(results, hasLength(3));
    expect(results.every((r) => r.bioSource == ArtistInfoSource.lastfm), isTrue);
    expect(lastfmReq, 1, reason: '并发查询共享 future，仅一次请求');
  });
}
