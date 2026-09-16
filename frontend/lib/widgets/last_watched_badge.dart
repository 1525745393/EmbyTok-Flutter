// 「上次看到」角标（关注页/发现页网格海报共用）
//
// 用于标记播放页位置记忆命中的视频海报。
// 视觉要求：在缩略图上足够醒目（红色渐变胶囊 + 投影 + 加粗白字），
// 用户从播放页返回网格页时能一眼定位到刚看的视频。

import 'package:flutter/material.dart';

class LastWatchedBadge extends StatelessWidget {
  const LastWatchedBadge({super.key});

  @override
  Widget build(BuildContext context) {
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 12, color: Colors.white),
          SizedBox(width: 3),
          Text(
            '上次看到',
            style: TextStyle(
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
