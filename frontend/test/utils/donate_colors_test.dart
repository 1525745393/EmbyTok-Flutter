// donate_colors 单元测试
//
// 验证打赏对话框品牌色常量。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:embytok_flutter/utils/donate_colors.dart';

void main() {
  group('DonateColors', () {
    test('wechat 是微信品牌绿', () {
      expect(DonateColors.wechat, isA<Color>());
      expect(DonateColors.wechat.value, 0xFF07C160);
    });

    test('alipay 是支付宝品牌蓝', () {
      expect(DonateColors.alipay, isA<Color>());
      expect(DonateColors.alipay.value, 0xFF1677FF);
    });

    test('donateAccent 是打赏主色（红色）', () {
      expect(DonateColors.donateAccent, isA<Color>());
      expect(DonateColors.donateAccent.value, 0xFFF44336);
    });

    test('品牌色不透明度为 100%', () {
      expect(DonateColors.wechat.alpha, 0xFF);
      expect(DonateColors.alipay.alpha, 0xFF);
      expect(DonateColors.donateAccent.alpha, 0xFF);
    });

    test('wechat 绿色通道分量最高', () {
      // 微信绿 #07C160，G 分量 0xC1 = 193
      expect(DonateColors.wechat.green, 0xC1);
      expect(DonateColors.wechat.green > DonateColors.wechat.red, true);
      expect(DonateColors.wechat.green > DonateColors.wechat.blue, true);
    });

    test('alipay 蓝色通道分量最高', () {
      // 支付宝蓝 #1677FF，B 分量 0xFF = 255
      expect(DonateColors.alipay.blue, 0xFF);
      expect(DonateColors.alipay.blue > DonateColors.alipay.red, true);
      expect(DonateColors.alipay.blue > DonateColors.alipay.green, true);
    });

    test('donateAccent 红色通道分量最高', () {
      // 打赏红 #F44336，R 分量 0xF4 = 244
      expect(DonateColors.donateAccent.red, 0xF4);
      expect(DonateColors.donateAccent.red > DonateColors.donateAccent.green, true);
      expect(DonateColors.donateAccent.red > DonateColors.donateAccent.blue, true);
    });

    test('三个品牌色互不相同', () {
      expect(DonateColors.wechat != DonateColors.alipay, true);
      expect(DonateColors.wechat != DonateColors.donateAccent, true);
      expect(DonateColors.alipay != DonateColors.donateAccent, true);
    });
  });
}
