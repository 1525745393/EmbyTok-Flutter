// MPV/VLC 音轨切换重建回归测试
//
// 缺陷：播放器音轨切换不生效（P1-3）。链路本应是
//   VideoPlayerWidget 监听音轨 provider → rebuild 传入带
//   `AudioStreamIndex=` 的新 url → 播放器 didUpdateWidget 检测 url 变化 →
//   重建播放器 → 音轨切换才真正作用于底层引擎。
// 修复前 MpvVideoPlayer/VlcVideoPlayer 的 didUpdateWidget 只处理
// isCurrentPage/muted，url 变化时不重建，底层 libmpv/libVLC 仍持有旧流，
// 音轨切换完全无效。
//
// 测试方法：widget 测试环境无 media_kit / VLC 平台实现，播放器初始化必失败
// 并触发 onError。因此：
//  - 首次 build → 初始化失败 → onError 计数 1；
//  - 同 url 仅参数变化（muted）→ 不重建 → 计数仍 1；
//  - url 变化（模拟音轨切换产生的新 url）→ 触发重建 → 再次初始化失败 →
//    计数 2。
// 计数增量即「url 变化触发了重建」的观察证据；修复前计数停在 1。

import 'package:embytok_flutter/widgets/video/mpv_video_player.dart';
import 'package:embytok_flutter/widgets/video/vlc_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MpvVideoPlayer url 变化触发重建（音轨切换链路）', () {
    testWidgets('url 变化 → onError 再次触发；同 url 参数变化不重建', (tester) async {
      var errorCount = 0;
      Widget build(String url, {bool muted = false}) => MaterialApp(
            home: Scaffold(
              body: MpvVideoPlayer(
                url: url,
                muted: muted,
                onError: (_) => errorCount++,
              ),
            ),
          );

      // 首次 build：测试环境无 media_kit 平台实现，初始化失败 → onError 1
      await tester.pumpWidget(build('http://test.example/a.mp4'));
      await tester.pumpAndSettle();
      expect(errorCount, 1,
          reason: '测试环境无 media_kit 平台实现，首次初始化应失败');

      // 同 url 仅 muted 变化：走音量分支不重建 → 计数不变
      await tester.pumpWidget(build('http://test.example/a.mp4', muted: true));
      await tester.pumpAndSettle();
      expect(errorCount, 1, reason: '同 url 参数变化不应触发重建');

      // url 变化（音轨切换 → 带 AudioStreamIndex 的新 url）：重建 → 再次
      // 初始化失败 → 计数 2。修复前此断言失败（计数仍 1）。
      await tester
          .pumpWidget(build('http://test.example/a.mp4?AudioStreamIndex=2'));
      await tester.pumpAndSettle();
      expect(errorCount, 2,
          reason: 'url 变化应触发播放器重建（音轨切换生效的前提）');
    });
  });

  group('VlcVideoPlayer url 变化触发重建（音轨切换链路）', () {
    testWidgets('url 变化 → 重建再次初始化', (tester) async {
      // VLC 在测试环境构造不抛异常（内部异步失败静默），观察口改用
      // onPlayerReady：每次 _init 成功路径都会回调，计数增量即重建证据。
      // 注意：不测「同 url muted 变化」——该分支会调用 setVolume，而测试
      // 环境 controller 未 attach 原生 VLC 会抛 StateError（环境限制，
      // 非生产缺陷）；「同 url 参数变化不重建」契约由同构的 MPV 组覆盖。
      var readyCount = 0;
      Widget build(String url) => MaterialApp(
            home: Scaffold(
              body: VlcVideoPlayer(
                url: url,
                onPlayerReady: (_) => readyCount++,
              ),
            ),
          );

      // 首次 build：VLC 构造成功路径 → onPlayerReady 1
      await tester.pumpWidget(build('http://test.example/a.mp4'));
      await tester.pumpAndSettle();
      expect(readyCount, 1, reason: '首次初始化应触发 onPlayerReady');

      // url 变化（音轨切换 → 带 AudioStreamIndex 的新 url）：重建 → 再次
      // 初始化 → 计数 2。修复前此断言失败（计数仍 1）。
      await tester
          .pumpWidget(build('http://test.example/a.mp4?AudioStreamIndex=2'));
      await tester.pumpAndSettle();
      expect(readyCount, 2,
          reason: 'url 变化应触发播放器重建（音轨切换生效的前提）');
    });
  });
}
