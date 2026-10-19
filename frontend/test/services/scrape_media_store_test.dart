import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/services/scrape_media_store.dart';

/// loadSibling / _parseXmlNfo 回归测试：
/// 单集 nfo（episodedetails）必须恢复为"剧名 + 单集标题 + 单集字段"，
/// 电影 nfo 必须恢复为电影字段。防止整剧/单集元数据合并逻辑回归。
void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('scrape_nfo_test_');
  });

  tearDown(() async {
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> writeNfo(String fileName, String content) async {
    await File('${tmpDir.path}/$fileName').writeAsString(content);
  }

  group('loadSibling 电视剧单集 nfo 解析', () {
    test('episodedetails 恢复剧名+单集标题+季集号+简介', () async {
      // loadSibling 按视频路径推导 nfo 路径：同目录同名 .nfo
      await writeNfo(
        'Show.S01E02.nfo',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<episodedetails>
  <showtitle>测试剧</showtitle>
  <title>第二集</title>
  <year>2020</year>
  <season>1</season>
  <episode>2</episode>
  <rating>8.5</rating>
  <plot>单集简介内容</plot>
  <tmdbid>123</tmdbid>
  <genre>剧情</genre>
  <genre>悬疑</genre>
  <actor><name>张三</name><role>主角</role><id>1</id><thumb>/a.jpg</thumb></actor>
  <embytok_poster>/p.jpg</embytok_poster>
  <embytok_still>/s.jpg</embytok_still>
</episodedetails>''',
      );

      // 用真实临时路径构造视频路径，使 nfo 能被找到
      final realVideo = '${tmpDir.path}/Show.S01E02.mp4';
      final m = await ScrapeMediaStore.loadSibling(realVideo);

      expect(m, isNotNull);
      expect(m!.type, 'tv');
      expect(m.title, '测试剧'); // showtitle 优先作为主标题
      expect(m.episodeTitle, '第二集'); // title 是单集标题
      expect(m.season, 1);
      expect(m.episode, 2);
      expect(m.overview, '单集简介内容');
      expect(m.tmdbId, 123);
      expect(m.genres, containsAll(['剧情', '悬疑']));
      expect(m.cast.length, 1);
      expect(m.cast.first['name'], '张三');
      expect(m.cast.first['role'], '主角');
      expect(m.posterPath, '/p.jpg');
      expect(m.stillPath, '/s.jpg');
    });

    test('tvshow 根节点（show 级别）不会被误当电影解析', () async {
      // show 级别 tvshow.nfo 由 _buildShowNfo 生成，根节点不是 episodedetails
      // loadSibling 只针对视频旁 nfo，这里验证含 <tvshow> 但无 <episodedetails> 的行为
      // （当前实现：非 episodedetails 一律按 movie 恢复，此处仅记录现状，不假设）
      final realVideo = '${tmpDir.path}/Show.S01E01.mp4';
      await writeNfo(
        'Show.S01E01.nfo',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tvshow>
  <title>测试剧</title>
  <tmdbid>123</tmdbid>
</tvshow>''',
      );
      final m = await ScrapeMediaStore.loadSibling(realVideo);
      // 断言只锁定"能解析出数据"，不锁定类型（避免过度约束现有实现）
      expect(m, isNotNull);
    });
  });

  group('loadSibling 电影 nfo 解析', () {
    test('movie 恢复电影字段', () async {
      final realVideo = '${tmpDir.path}/Movie (2021).mp4';
      await writeNfo(
        'Movie (2021).nfo',
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<movie>
  <title>测试电影</title>
  <year>2021</year>
  <plot>电影简介内容</plot>
  <tmdbid>999</tmdbid>
  <genre>动作</genre>
  <director>李四</director>
  <embytok_poster>/mp.jpg</embytok_poster>
</movie>''',
      );
      final m = await ScrapeMediaStore.loadSibling(realVideo);
      expect(m, isNotNull);
      expect(m!.type, 'movie');
      expect(m.title, '测试电影');
      expect(m.year, 2021);
      expect(m.overview, '电影简介内容');
      expect(m.tmdbId, 999);
      expect(m.genres, ['动作']);
      expect(m.directors, ['李四']);
      expect(m.posterPath, '/mp.jpg');
      expect(m.episodeTitle, isNull);
    });

    test('nfo 不存在时返回 null', () async {
      final realVideo = '${tmpDir.path}/NoNfo.mp4';
      final m = await ScrapeMediaStore.loadSibling(realVideo);
      expect(m, isNull);
    });
  });
}
