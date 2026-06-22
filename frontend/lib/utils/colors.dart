// 应用颜色常量：统一管理主题色和硬编码颜色值

import 'package:flutter/material.dart';

/// 主色：粉紫色（用于按钮、强调色、收藏图标等）
const Color primaryPink = Color(0xFFE91E63);

/// 历史页图标色：浅粉色
const Color historyPink = Color(0xFFFF5983);

/// 错误提示色
const Color errorColor = Color(0xFFFF5252);

/// 深色背景
const Color backgroundColor = Color(0xFF000000);

/// 深色卡片/表面色（由浅到深）
const Color surfaceColorL1 = Color(0xFF121212);
const Color surfaceColorL2 = Color(0xFF1E1E1E);
const Color surfaceColorL3 = Color(0xFF2A2A2A);

/// 文本主色
const Color textPrimary = Color(0xFFFFFFFF);

/// 文本次要色（70% 不透明度）
const Color textSecondary = Color(0xB3FFFFFF);

/// 文本第三色（54% 不透明度）
const Color textTertiary = Color(0x8AFFFFFF);

/// 文本第四色（38% 不透明度）
const Color textQuaternary = Color(0x61FFFFFF);

/// 文本占位色（30% 不透明度）
const Color textPlaceholder = Color(0x4DFFFFFF);

/// 分隔线/边框色（12% 不透明度）
const Color dividerColor = Color(0x1FFFFFFF);

/// 进度条底色（24% 不透明度）
const Color progressBackground = Color(0x3DFFFFFF);

/// 视频时长标签背景
const Color durationBadgeBackground = Color(0xB3000000);

/// 半透明黑色（用于渐变遮罩、阴影等）
const Color black54 = Color(0x8A000000); // 54% 不透明
const Color black87 = Color(0xDE000000); // 87% 不透明

/// 叠加层黑色（用于顶部/底部工具栏的半透明渐变）
const Color overlayBlack = Color(0xAA000000); // 67% 不透明
const Color overlayBlackDeep = Color(0xCC000000); // 80% 不透明

/// 琥珀色（用于收藏、强调）
const Color amberColor = Color(0xFFFFC107);

/// Material Colors.grey 快捷引用
const Color grey50 = Color(0xFFFAFAFA);
const Color grey100 = Color(0xFFF5F5F5);
const Color grey200 = Color(0xFFEEEEEE);
const Color grey300 = Color(0xFFE0E0E0);
const Color grey400 = Color(0xFFBDBDBD);
const Color grey500 = Color(0xFF9E9E9E);
const Color grey600 = Color(0xFF757575);
const Color grey700 = Color(0xFF616161);
const Color grey800 = Color(0xFF424242);
const Color grey850 = Color(0xFF303030);
const Color grey900 = Color(0xFF212121);
