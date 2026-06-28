// toolbar_visibility_provider 单元测试（PR #72）
//
// 覆盖纯净模式 / 全屏 push/pop / 引用计数的组合场景：
// - 纯净模式（setAutoPlayActive）持续 hide，与全屏独立
// - 全屏 push/pop 配对 hide/show
// - 全屏中切换纯净模式不破坏全屏状态
// - 退出全屏时正确恢复（保留纯净模式 hide 状态）

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:embytok_flutter/providers/toolbar_visibility_provider.dart';

void main() {
  group('ToolbarVisibilityNotifier 纯净模式 + 全屏 hide/show（PR #72）', () {
    test('初始状态为显示（true）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(toolbarVisibilityProvider), isTrue);
    });

    test('setAutoPlayActive(true) → 工具栏隐藏', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(toolbarVisibilityProvider.notifier).setAutoPlayActive(true);
      expect(container.read(toolbarVisibilityProvider), isFalse);
    });

    test('setAutoPlayActive 重复相同值不重复触发', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.setAutoPlayActive(true);
      notifier.setAutoPlayActive(true);
      notifier.setAutoPlayActive(false);
      notifier.setAutoPlayActive(false);
      // 最终 false
      expect(container.read(toolbarVisibilityProvider), isTrue);
    });

    test('hide()/show() 引用计数正确', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.hide();
      expect(container.read(toolbarVisibilityProvider), isFalse);
      notifier.show();
      expect(container.read(toolbarVisibilityProvider), isTrue);
      // 配对多次
      notifier.hide();
      notifier.hide();
      notifier.show();
      expect(container.read(toolbarVisibilityProvider), isFalse);
      notifier.show();
      expect(container.read(toolbarVisibilityProvider), isTrue);
    });

    test('show() 在 hideCount=0 时保持显示（不允许低于 0）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.show();
      notifier.show();
      expect(container.read(toolbarVisibilityProvider), isTrue);
    });

    test('纯净模式 + 全屏 push：state 仍 false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.setAutoPlayActive(true);
      notifier.hide(); // 模拟全屏 push
      expect(container.read(toolbarVisibilityProvider), isFalse);
    });

    test('纯净模式 + 全屏 push + 全屏 pop：state 仍 false（保持纯净模式 hide）',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.setAutoPlayActive(true);
      notifier.hide(); // 全屏 push
      notifier.show(); // 全屏 pop
      expect(container.read(toolbarVisibilityProvider), isFalse);
    });

    test('非纯净 + 全屏 push + 全屏 pop：state 恢复 true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.hide();
      notifier.show();
      expect(container.read(toolbarVisibilityProvider), isTrue);
    });

    test('全屏中开纯净模式：state 仍 false；退出全屏后仍 false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.hide(); // 全屏 push
      notifier.setAutoPlayActive(true); // 全屏中开纯净模式
      expect(container.read(toolbarVisibilityProvider), isFalse);
      notifier.show(); // 全屏 pop
      expect(container.read(toolbarVisibilityProvider), isFalse);
    });

    test('全屏中关纯净模式：state 全屏中 false，退出全屏后 true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.setAutoPlayActive(true);
      notifier.hide(); // 全屏 push
      notifier.setAutoPlayActive(false); // 全屏中关纯净模式
      expect(container.read(toolbarVisibilityProvider), isFalse); // 全屏中
      notifier.show(); // 全屏 pop
      expect(container.read(toolbarVisibilityProvider), isTrue); // 恢复显示
    });

    test('双重 hide + 一次 show：state 仍 false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(toolbarVisibilityProvider.notifier);
      notifier.hide();
      notifier.hide();
      notifier.show();
      expect(container.read(toolbarVisibilityProvider), isFalse);
    });
  });
}
