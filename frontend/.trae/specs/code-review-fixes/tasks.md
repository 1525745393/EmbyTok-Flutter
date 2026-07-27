# 代码审查问题修复 - 实现计划

## [x] Task 1: 修复 access_token 明文存储安全风险
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 将 auth_provider.dart 中的 access_token 存储从 SharedPreferences 迁移到 flutter_secure_storage
  - 实现旧数据迁移逻辑：启动时检查 SharedPreferences 中是否有旧 token，如有则迁移到 secure_storage 并删除旧数据
  - SharedPreferences 仅保留非敏感配置（emby_server_url、user_id、user_name）
- **Acceptance Criteria Addressed**: AC-1, AC-2
- **Test Requirements**:
  - `human-judgement` TR-1.1: 登录后检查 SharedPreferences 中无 access_token 字段
  - `human-judgement` TR-1.2: 从旧版本升级后，启动时自动迁移 token 且登录状态正常
  - `human-judgement` TR-1.3: 清除 SharedPreferences 后，应用仍能从 secure_storage 恢复登录状态
- **Notes**: 需要处理 flutter_secure_storage 的初始化错误，降级到 SharedPreferences（仅作为 fallback）

## [x] Task 2: 升级 Dio 修复 CVE-2024-30167
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 将 pubspec.yaml 中的 dio 版本从 ^5.4.0 升级到 ^5.4.3
- **Acceptance Criteria Addressed**: AC-3
- **Test Requirements**:
  - `programmatic` TR-2.1: flutter pub get 成功，无依赖冲突
  - `programmatic` TR-2.2: flutter analyze 无 Dio 相关错误
- **Notes**: 5.4.3 修复了 SSL 证书校验绕过漏洞，API 无破坏性变更

## [x] Task 3: 升级 video_player 修复 MediaCodec 竞态
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 将 pubspec.yaml 中的 video_player 版本从 ^2.8.0 升级到 ^2.9.0
- **Acceptance Criteria Addressed**: AC-4
- **Test Requirements**:
  - `programmatic` TR-3.1: flutter pub get 成功，无依赖冲突
  - `programmatic` TR-3.2: flutter analyze 无 video_player 相关错误
- **Notes**: 2.9.0 修复了 Android MediaCodec 释放竞态问题，API 无破坏性变更

## [x] Task 4: 修复 PaintingBinding API 弃用警告
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 修改 main.dart 中的 ImageCache 配置代码
  - 使用 WidgetsFlutterBinding.ensureInitialized().imageCache 替代 PaintingBinding.instance.imageCache
- **Acceptance Criteria Addressed**: AC-5
- **Test Requirements**:
  - `human-judgement` TR-4.1: flutter analyze 无 PaintingBinding 弃用警告
  - `human-judgement` TR-4.2: 应用启动正常，图片缓存功能正常
- **Notes**: WidgetsFlutterBinding.ensureInitialized() 在 main() 开头已调用，可直接使用其返回值

## [x] Task 5: 提升 SRT 字幕解析健壮性
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 修改 subtitle_track.dart 中的 parseSrt 方法
  - 使用 RegExp(r'\n{2,}') 替代 split('\n\n') 分割 block，容忍多个连续空行
- **Acceptance Criteria Addressed**: AC-6
- **Test Requirements**:
  - `programmatic` TR-5.1: 解析使用单个换行分隔的 SRT 文件成功
  - `programmatic` TR-5.1: 解析使用多个空行分隔的 SRT 文件成功
  - `human-judgement` TR-5.2: 原有的正常 SRT 文件解析不受影响
- **Notes**: 保持向后兼容，不修改 ASS/VTT 解析逻辑
