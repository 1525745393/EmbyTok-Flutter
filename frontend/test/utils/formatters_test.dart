// formatters 单元测试
//
// 验证通用格式化工具函数的正确性。

import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('null 返回 0:00', () {
      expect(formatDuration(null), '0:00');
    });

    test('0 秒返回 0:00', () {
      expect(formatDuration(0), '0:00');
    });

    test('负数返回 0:00', () {
      expect(formatDuration(-10), '0:00');
    });

    test('30 秒返回 0:30', () {
      expect(formatDuration(30), '0:30');
    });

    test('90 秒返回 1:30', () {
      expect(formatDuration(90), '1:30');
    });

    test('59 秒返回 0:59', () {
      expect(formatDuration(59), '0:59');
    });

    test('60 秒返回 1:00', () {
      expect(formatDuration(60), '1:00');
    });

    test('3600 秒（1小时）返回 1h 00m', () {
      expect(formatDuration(3600), '1h 00m');
    });

    test('3661 秒（1小时1分1秒）返回 1h 01m', () {
      expect(formatDuration(3661), '1h 01m');
    });

    test('7200 秒（2小时）返回 2h 00m', () {
      expect(formatDuration(7200), '2h 00m');
    });

    test('小数秒正确取整', () {
      expect(formatDuration(90.5), '1:30');
      expect(formatDuration(90.9), '1:30');
    });
  });

  group('formatWatchProgress', () {
    test('total 为 0 返回 已观看 0%', () {
      expect(formatWatchProgress(50, 0), '已观看 0%');
    });

    test('total 为负数返回 已观看 0%', () {
      expect(formatWatchProgress(50, -10), '已观看 0%');
    });

    test('0% 进度', () {
      expect(formatWatchProgress(0, 100), '已观看 0%');
    });

    test('50% 进度', () {
      expect(formatWatchProgress(50, 100), '已观看 50%');
    });

    test('100% 进度', () {
      expect(formatWatchProgress(100, 100), '已观看 100%');
    });

    test('超过 100% 被 clamp 到 100%', () {
      expect(formatWatchProgress(150, 100), '已观看 100%');
    });

    test('负数进度被 clamp 到 0%', () {
      expect(formatWatchProgress(-10, 100), '已观看 0%');
    });

    test('小数进度正确取整', () {
      expect(formatWatchProgress(33.3, 100), '已观看 33%');
      expect(formatWatchProgress(66.7, 100), '已观看 66%');
    });
  });

  group('htmlDecode', () {
    test('空字符串返回空字符串', () {
      expect(htmlDecode(''), '');
    });

    test('无实体的字符串不变', () {
      expect(htmlDecode('hello world'), 'hello world');
    });

    test('解码 &#39; 为单引号', () {
      expect(htmlDecode('It&#39;s me'), "It's me");
    });

    test('解码 &quot; 为双引号', () {
      expect(htmlDecode('&quot;hello&quot;'), '"hello"');
    });

    test('解码 &amp; 为 &', () {
      expect(htmlDecode('A &amp; B'), 'A & B');
    });

    test('解码 &lt; 为 <', () {
      expect(htmlDecode('&lt;div&gt;'), '<div>');
    });

    test('解码 &gt; 为 >', () {
      expect(htmlDecode('&lt;div&gt;'), '<div>');
    });

    test('混合实体解码', () {
      expect(htmlDecode('It&#39;s &quot;A &amp; B&quot;'), 'It\'s "A & B"');
    });
  });

  group('formatBytes', () {
    test('0 字节返回 暂无缓存', () {
      expect(formatBytes(0), '暂无缓存');
    });

    test('负数返回 暂无缓存', () {
      expect(formatBytes(-100), '暂无缓存');
    });

    test('小于 1024 字节显示 B', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1023), '1023 B');
    });

    test('1024 字节显示 1.0 KB', () {
      expect(formatBytes(1024), '1.0 KB');
    });

    test('1536 字节显示 1.5 KB', () {
      expect(formatBytes(1536), '1.5 KB');
    });

    test('1 MB 显示 1.0 MB', () {
      expect(formatBytes(1024 * 1024), '1.0 MB');
    });

    test('1.5 MB 显示 1.5 MB', () {
      expect(formatBytes((1024 * 1024 * 1.5).toInt()), '1.5 MB');
    });

    test('1 GB 显示 1.00 GB', () {
      expect(formatBytes(1024 * 1024 * 1024), '1.00 GB');
    });

    test('2.5 GB 显示 2.50 GB', () {
      expect(formatBytes((1024 * 1024 * 1024 * 2.5).toInt()), '2.50 GB');
    });
  });

  group('personTypeLabelFromCode', () {
    test('Actor 返回 演员', () {
      expect(personTypeLabelFromCode('Actor'), '演员');
    });

    test('Director 返回 导演', () {
      expect(personTypeLabelFromCode('Director'), '导演');
    });

    test('Writer 返回 编剧', () {
      expect(personTypeLabelFromCode('Writer'), '编剧');
    });

    test('null 返回 全部', () {
      expect(personTypeLabelFromCode(null), '全部');
    });

    test('空字符串返回 全部', () {
      expect(personTypeLabelFromCode(''), '全部');
    });

    test('其他类型返回 人物', () {
      expect(personTypeLabelFromCode('Producer'), '人物');
      expect(personTypeLabelFromCode('Composer'), '人物');
    });
  });

  group('personWorksTitleFromCode', () {
    test('Actor 返回 参演作品', () {
      expect(personWorksTitleFromCode('Actor'), '参演作品');
    });

    test('Director 返回 执导作品', () {
      expect(personWorksTitleFromCode('Director'), '执导作品');
    });

    test('Writer 返回 编剧作品', () {
      expect(personWorksTitleFromCode('Writer'), '编剧作品');
    });

    test('null 返回 相关作品', () {
      expect(personWorksTitleFromCode(null), '相关作品');
    });

    test('其他类型返回 相关作品', () {
      expect(personWorksTitleFromCode('Producer'), '相关作品');
    });
  });

  group('mediaTypeLabelFromCode', () {
    test('Movie 返回 电影', () {
      expect(mediaTypeLabelFromCode('Movie'), '电影');
    });

    test('Series 返回 剧集', () {
      expect(mediaTypeLabelFromCode('Series'), '剧集');
    });

    test('BoxSet 返回 合集', () {
      expect(mediaTypeLabelFromCode('BoxSet'), '合集');
    });

    test('Episode 返回 单集', () {
      expect(mediaTypeLabelFromCode('Episode'), '单集');
    });

    test('null 返回 作品', () {
      expect(mediaTypeLabelFromCode(null), '作品');
    });

    test('空字符串返回 作品', () {
      expect(mediaTypeLabelFromCode(''), '作品');
    });

    test('未知类型返回英文原文', () {
      expect(mediaTypeLabelFromCode('MusicAlbum'), 'MusicAlbum');
      expect(mediaTypeLabelFromCode('Audio'), 'Audio');
    });
  });
}
