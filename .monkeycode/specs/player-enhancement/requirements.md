# Requirements Document

## Introduction

本需求文档针对 EmbyTok-Flutter 的播放器增强功能。当前项目使用 Flutter 官方 `video_player` 插件，其解码能力完全依赖各平台原生播放器（Android ExoPlayer / iOS AVPlayer），导致 HEVC/H.265 格式视频在部分设备上无法播放，且不支持自定义转码流配置。本需求旨在评估现状局限并引入具备内置软硬解加速生态的播放引擎。

## Glossary

- **HEVC/H.265**：高效视频编码标准，较 H.264 压缩率提升约 50%，但解码计算量更大
- **HLS**：HTTP Live Streaming，苹果公司提出的流媒体传输协议
- **DASH**：Dynamic Adaptive Streaming over HTTP，MPEG 制定的自适应流媒体协议
- **软解**：由 CPU 执行解码运算，不依赖特定硬件芯片
- **硬解**：由 GPU 或专用解码芯片执行解码，功耗低、性能高
- **Direct Play**：客户端直接播放原始视频文件，不经任何转码
- **Direct Stream**：服务端仅变更容器封装格式，不重编码音视频流
- **Transcode**：服务端实时重编码视频流以适配客户端能力

## Requirements

### Requirement 1：HEVC/H.265 全平台解码

**User Story:** AS 终端用户，I want 在各类设备上流畅播放 HEVC/H.265 编码的视频，so that 不受设备硬件解码能力的限制。

#### Acceptance Criteria

1. The system SHALL decode HEVC/H.265 视频流，when 设备硬件不支持 HEVC 硬解时自动切换至软件解码
2. When 系统检测到设备 GPU 支持 HEVC 硬解，the system SHALL 优先使用硬件解码以降低功耗
3. IF 软件解码时 CPU 占用率达到 90% 阈值， the system SHALL 自动降低输出分辨率以防止掉帧
4. The system SHALL 支持 HEVC/H.265 8-bit 和 10-bit 两种色深格式的解码

### Requirement 2：自建转码流播放

**User Story:** AS 运维人员，I want 客户端支持 HLS 与 DASH 流媒体协议，so that 可以使用自建转码服务替代 Emby 原生转码能力。

#### Acceptance Criteria

1. The system SHALL 播放 HLS（.m3u8）格式的流媒体内容，包括多码率自适应切换
2. The system SHALL 播放 MPEG-DASH（.mpd）格式的流媒体内容
3. When HLS 分片加载失败，the system SHALL 重试当前分片并继续播放后续分片
4. The system SHALL 在用户可见的加载指示器中展示流媒体缓冲状态

### Requirement 3：播放引擎替换与兼容

**User Story:** AS 产品负责人，I want 用具备内置软硬解生态的播放引擎替换官方 video_player，so that 统一各平台的解码能力并消除硬件依赖差异。

#### Acceptance Criteria

1. The system SHALL 将核心播放引擎从 Flutter video_player 替换为具备独立解码库（如 FFmpeg/libVLC/mpv）的播放引擎
2. The system SHALL 保持现有播放控制接口的兼容性，包括播放、暂停、Seek、倍速、静音
3. The system SHALL 保持现有手势交互行为不变，包括单击显隐控制层、双击快进快退、长按倍速、水平拖动 Seek、垂直拖动音量/亮度
4. The system SHALL 支持 0.5x / 0.75x / 1.0x / 1.25x / 1.5x / 2.0x 六档倍速播放

### Requirement 4：音频编解码扩展

**User Story:** AS 终端用户，I want 播放使用 AC3/EAC3/FLAC/Opus 等高级音频编码的视频，so that 获得高质量的多声道音频体验。

#### Acceptance Criteria

1. The system SHALL 解码 AC3（Dolby Digital）和 EAC3（Dolby Digital Plus）音频编码
2. The system SHALL 解码 FLAC 无损音频编码
3. The system SHALL 解码 Opus 音频编码
4. The system SHALL 正确处理 5.1 和 7.1 多声道音频的下混输出

### Requirement 5：播放性能和稳定性

**User Story:** AS 终端用户，I want 播放体验稳定流畅，so that 不会因编解码切换或流媒体加载出现卡顿和崩溃。

#### Acceptance Criteria

1. The system SHALL 将首帧渲染耗时控制在 800ms 以内
2. The system SHALL 维持每次 Seek 操作延迟在 300ms 以内
3. The system SHALL 在播放器初始化失败时回退到 HLS 转码流作为兜底方案
4. IF 连续 3 次播放失败，the system SHALL 向用户展示友好的错误提示并提供重试选项

### Requirement 6：播放引擎生态评估

**User Story:** AS 技术决策者，I want 对候选播放引擎进行横向评估，so that 选择最适合项目长期发展的技术方案。

#### Acceptance Criteria

1. The system SHALL 提供至少 3 种候选播放引擎（libVLC、mpv、ExoPlayer 增强版）的技术对比报告，覆盖解码能力、包体积、性能基准、社区活跃度、许可证兼容性维度
2. The system SHALL 基于对比报告确定最终选型并记录决策理由
