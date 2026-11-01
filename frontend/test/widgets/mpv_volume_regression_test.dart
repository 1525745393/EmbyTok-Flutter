// MPV 音量换算回归测试
//
// 缺陷：media_kit `Player.setVolume` 音量范围为 0~100（默认 100.0），
// 而 App 统一控制句柄（VideoPlayerWidget.setVolume，对齐 EXO/VLC）使用 0.0~1.0。
// 原实现把 1.0 直接透传给 media_kit，等价于 1% 音量：
//  - 未静音时 MPV 声音几乎听不见；
//  - 右侧竖滑音量条（0~1）拉满也只有 1%；
//  - setMuted(false) 恢复后同样只有 1%。
// 修复：统一经 MpvVideoPlayerState.toMpvVolume 做 0~1 → 0~100 换算。
// 本测试锁定该换算契约（含越界钳制），防止再次回退。

import 'package:embytok_flutter/widgets/video/mpv_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MpvVideoPlayerState.toMpvVolume 音量换算契约', () {
    test('0.0~1.0 线性映射到 0~100', () {
      expect(MpvVideoPlayerState.toMpvVolume(0.0), 0.0);
      expect(MpvVideoPlayerState.toMpvVolume(0.5), 50.0);
      expect(MpvVideoPlayerState.toMpvVolume(1.0), 100.0);
    });

    test('与修复前缺陷行为区分：满音量必须为 100 而非 1', () {
      // 回归保护：修复前 setVolume(1.0) → media_kit 收到 1.0（=1% 音量）
      expect(MpvVideoPlayerState.toMpvVolume(1.0), 100.0);
      expect(MpvVideoPlayerState.toMpvVolume(1.0), isNot(1.0));
    });

    test('越界输入被钳制到 0~100', () {
      expect(MpvVideoPlayerState.toMpvVolume(-0.5), 0.0);
      expect(MpvVideoPlayerState.toMpvVolume(2.0), 100.0);
    });
  });
}
