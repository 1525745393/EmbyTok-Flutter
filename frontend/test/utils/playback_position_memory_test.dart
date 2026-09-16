// PlaybackPositionMemory.lastWatchedItemId 单元测试
//
// 覆盖：命中 / 未命中 / 源不存在 / 列表签名不存在 / 脏数据容错
//（关注页与发现页「上次看到」角标依赖该读取结果）。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:embytok_flutter/utils/constants.dart';
import 'package:embytok_flutter/utils/playback_position_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('命中：返回上次观看的视频 id', () async {
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition:
          '{"discover":{"itemA":{"idx":3,"last":"itemD"}}}',
    });
    final id = await PlaybackPositionMemory.lastWatchedItemId(
      source: 'discover',
      listSignature: 'itemA',
    );
    expect(id, 'itemD');
  });

  test('未命中：source 不存在返回 null', () async {
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition:
          '{"discover":{"itemA":{"idx":3,"last":"itemD"}}}',
    });
    final id = await PlaybackPositionMemory.lastWatchedItemId(
      source: 'follow',
      listSignature: 'itemA',
    );
    expect(id, isNull);
  });

  test('未命中：列表签名不存在返回 null', () async {
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition:
          '{"discover":{"itemA":{"idx":3,"last":"itemD"}}}',
    });
    final id = await PlaybackPositionMemory.lastWatchedItemId(
      source: 'discover',
      listSignature: 'otherList',
    );
    expect(id, isNull);
  });

  test('容错：无存储 / 空串 / 非法 JSON 均返回 null', () async {
    expect(
      await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: 'itemA',
      ),
      isNull,
    );
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition: '',
    });
    expect(
      await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: 'itemA',
      ),
      isNull,
    );
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition: 'not-json{{{',
    });
    expect(
      await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: 'itemA',
      ),
      isNull,
    );
  });

  test('容错：last 字段缺失或非字符串返回 null', () async {
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition:
          '{"discover":{"itemA":{"idx":1}}}',
    });
    expect(
      await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: 'itemA',
      ),
      isNull,
    );
    SharedPreferences.setMockInitialValues({
      kStorageKeyPlaybackShellPosition:
          '{"discover":{"itemA":{"idx":1,"last":123}}}',
    });
    expect(
      await PlaybackPositionMemory.lastWatchedItemId(
        source: 'discover',
        listSignature: 'itemA',
      ),
      isNull,
    );
  });
}
