# EmbyTok 播放器控制功能差距分析

## 概述
- **目的**：对比 EmbyTok React 版本与 EmbyTok-Flutter 的播放器控制功能差异，识别缺失功能
- **参考项目**：https://github.com/1525745393/EmbyTok (React/TypeScript)
- **当前项目**：EmbyTok-Flutter (Flutter)

## EmbyTok React 播放器控制功能

### 1. VideoControls.tsx（右侧操作栏）
| 功能 | 图标 | 状态 |
|------|------|------|
| 自动播放开关 | Infinity | ✅ 有 |
| 用户头像/海报 | - | ✅ 有 |
| 点赞 | Heart | ✅ 有 |
| 详情 | Info | ✅ 有 |
| 删除 | Trash2 | ✅ 有 |
| 静音 | Disc (旋转动画) | ✅ 有 |

### 2. VideoPlayer.tsx（视频覆盖层）
| 功能 | 状态 |
|------|------|
| 暂停时显示播放图标 | ✅ 有 |
| 倍速 > 1x 时显示 "Double Speed" 徽章 | ✅ 有 |
| 拖动时显示快进/快退偏移量 (+/-Xs) | ✅ 有 |
| 错误状态显示 | ✅ 有 |

### 3. VideoFeed.tsx（Feed 级别）
| 功能 | 图标 |
|------|------|
| 随机模式 | Shuffle |
| 刷新 | RefreshCw |
| 影片浏览 | Film |
| 自动播放状态 | Infinity |

## Flutter 项目当前实现

### 1. 右侧操作栏 (_buildRightActions)
| 功能 | 状态 | 差异 |
|------|------|------|
| 下一集 | chevron_right | ✅ 一致 |
| 全屏切换 | fullscreen | ✅ 一致 |
| 静音开关 | volume_off/volume_up | ✅ 一致 |
| 点赞 | favorite/favorite_border | ✅ 一致 |
| 收藏 | star/star_border | ⚠️ 与点赞重复 |
| 评论 | mode_comment_outlined | ✅ 一致 |
| 分享 | share | ✅ 一致 |
| **自动播放开关** | - | ❌ **缺失** |
| **删除按钮** | - | ❌ **缺失** |
| **详情按钮** | - | ❌ **缺失** |

### 2. 底部控制条 (VideoControls)
| 功能 | 状态 | 差异 |
|------|------|------|
| 上一集 | skip_previous | ✅ 一致 |
| 播放/暂停 | pause/play_arrow | ✅ 一致 |
| 下一集 | skip_next | ✅ 一致 |
| 时间显示 | mm:ss / mm:ss | ✅ 一致 |
| 进度条 | Slider | ✅ 一致 |
| 字幕 | subtitles | ✅ 一致 |
| 倍速 | x.xx | ✅ 一致 |

### 3. 手势覆盖层 (GestureOverlay)
| 功能 | 状态 | 差异 |
|------|------|------|
| 双击点赞 | FlyingHeart | ✅ 一致 |
| 双击左 1/3 快退 10s | +反馈 | ✅ 一致 |
| 双击右 1/3 快进 10s | +反馈 | ✅ 一致 |
| 长按 2x 倍速 | SpeedBadge | ✅ 一致 |
| 水平拖动进度 | SeekPreviewBar | ✅ 一致 |
| 单击切换控制层 | - | ✅ 一致 |
| **倍速 > 1x 时显示 "Double Speed" 徽章** | - | ❌ **缺失** |

### 4. Feed 级别
| 功能 | 状态 | 差异 |
|------|------|------|
| 随机模式 (Shuffle) | - | ❌ **缺失** |
| 自动播放状态 | - | ❌ **缺失** |

## 功能差距汇总

### 高优先级缺失
1. **自动播放开关** - 右侧操作栏缺少 Infinity 图标开关
2. **倍速状态徽章** - 播放速度 > 1x 时右上角应显示 "Double Speed" 提示

### 中优先级缺失
3. **删除功能** - 右侧缺少 Trash2 删除按钮
4. **详情按钮** - 右侧缺少 Info 按钮（可考虑复用现有 bottom gradient 信息区）
5. **收藏/点赞重复** - star_border 和 favorite_border 执行相同操作

### 低优先级（已有替代方案）
6. **随机模式** - Feed 级别 Shuffle 按钮（当前可通过浏览模式切换实现）

## 建议修复顺序
1. 添加自动播放开关（isAutoPlayProvider 已存在，只需添加 UI）
2. 添加倍速状态徽章（播放速度 > 1x 时显示）
3. 修复收藏/点赞重复逻辑
4. 添加删除按钮
5. 添加详情按钮（或确认现有底部信息区是否足够）
