import 'package:flutter_test/flutter_test.dart';
import 'package:embbytok_flutter/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    group('基本格式化', () {
      test('格式化秒数（小于 1 分钟）', () {
        expect(formatDuration(30), '0:30');
        expect(formatDuration(45), '0:45');
        expect(formatDuration(59), '0:59');
      });

      test('格式化分钟数（小于 1 小时）', () {
        expect(formatDuration(60), '1:00');
        expect(formatDuration(90), '1:30');
        expect(formatDuration(120), '2:00');
        expect(formatDuration(3599), '59:59');
      });

      test('格式化小时数', () {
        expect(formatDuration(3600), '1h 00m');
        expect(formatDuration(7200), '2h 00m');
        expect(formatDuration(7320), '2h 02m');
        expect(formatDuration(36000), '10h 00m');
      });
    });

    group('边界情况', () {
      test('null 输入返回默认值', () {
        expect(formatDuration(null), '0:00');
      });

      test('零返回默认值', () {
        expect(formatDuration(0), '0:00');
      });

      test('负数返回默认值', () {
        expect(formatDuration(-10), '0:00');
        expect(formatDuration(-100), '0:00');
      });

      test('极大值', () {
        expect(formatDuration(86400), '24h 00m'); // 1 天
        expect(formatDuration(360000), '100h 00m'); // 100 小时
      });

      test('小数秒数', () {
        expect(formatDuration(90.5), '1:30');
        expect(formatDuration(90.9), '1:30');
      });
    });
  });

  group('formatWatchProgress', () {
    group('基本格式化', () {
      test('0% 进度', () {
        expect(formatWatchProgress(0, 100), '已观看 0%');
      });

      test('50% 进度', () {
        expect(formatWatchProgress(50, 100), '已观看 50%');
      });

      test('100% 进度', () {
        expect(formatWatchProgress(100, 100), '已观看 100%');
      });

      test('部分进度', () {
        expect(formatWatchProgress(25, 100), '已观看 25%');
        expect(formatWatchProgress(75, 100), '已观看 75%');
      });
    });

    group('边界情况', () {
      test('total 为 0 返回默认值', () {
        expect(formatWatchProgress(50, 0), '已观看 0%');
      });

      test('total 为负数返回默认值', () {
        expect(formatWatchProgress(50, -100), '已观看 0%');
      });

      test('current 超过 total 时 clamp 到 100%', () {
        expect(formatWatchProgress(150, 100), '已观看 100%');
        expect(formatWatchProgress(200, 100), '已观看 100%');
      });

      test('current 为负数时 clamp 到 0%', () {
        expect(formatWatchProgress(-50, 100), '已观看 0%');
      });

      test('小数进度', () {
        expect(formatWatchProgress(33.3, 100), '已观看 33%');
        expect(formatWatchProgress(66.6, 100), '已观看 66%');
      });
    });
  });

  group('htmlDecode', () {
    group('基本 HTML 实体解码', () {
      test('解码单引号', () {
        expect(htmlDecode('&#39;'), "'");
        expect(htmlDecode('这是&#39;一条&#39;测试'), "这是'一条'测试");
      });

      test('解码双引号', () {
        expect(htmlDecode('&quot;'), '"');
        expect(htmlDecode('&quot;开始&quot;和&quot;结束&quot;'), '"开始"和"结束"');
      });

      test('解码 & 符号', () {
        expect(htmlDecode('&amp;'), '&');
        expect(htmlDecode('Tom &amp; Jerry'), 'Tom & Jerry');
      });

      test('解码小于号', () {
        expect(htmlDecode('&lt;'), '<');
        expect(htmlDecode('a &lt; b'), 'a < b');
      });

      test('解码大于号', () {
        expect(htmlDecode('&gt;'), '>');
        expect(htmlDecode('a &gt; b'), 'a > b');
      });
    });

    group('混合解码', () {
      test('多个 HTML 实体混合', () {
        expect(
          htmlDecode('&lt;div&gt;这是&amp;测试&#39;s&lt;/div&gt;'),
          '<div>这是&测试\'s</div>',
        );
      });
    });

    group('边界情况', () {
      test('空字符串', () {
        expect(htmlDecode(''), '');
      });

      test('无 HTML 实体的普通文本', () {
        expect(htmlDecode('普通文本'), '普通文本');
        expect(htmlDecode('No HTML entities here'), 'No HTML entities here');
      });

      test('部分 HTML 实体', () {
        expect(htmlDecode('部分&amp;解码'), '部分&解码');
      });

      test('连续解码相同实体', () {
        expect(htmlDecode('&#39;&#39;&#39;'), "'''");
      });
    });
  });
}
