// 「上次看到」角标（视频库网格 / 关注页 / 发现页海报共用）
//
// 用于标记播放页位置记忆命中的视频海报。
// 视觉要求：在缩略图上足够醒目（红色渐变胶囊 + 投影 + 加粗白字），
// 用户从播放页返回网格页时能一眼定位到刚看的视频。
// 可传入服务端播放进度百分比（progressPercent），显示「上次看到 45%」。

import 'package:flutter/material.dart';

class LastWatchedBadge extends StatelessWidget {
  const LastWatchedBadge({super.key, this.progressPercent});

  /// 观看进度百分比（0-100）。为空时仅显示「上次看到」。
  final int? progressPercent;

  @override
  Widget build(BuildContext context) {
    final label = progressPercent != null
        ? '上次看到 $progressPercent%'
        : '上次看到';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFE53935)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
