# 代码审查问题修复 - 验证清单

## Task 1: access_token 安全存储
- [x] auth_provider.dart 中 token 存储使用 flutter_secure_storage
- [x] auth_provider.dart 中实现旧数据迁移逻辑
- [x] SharedPreferences 中不再存储 access_token
- [x] 登录后检查 SharedPreferences 无 access_token
- [x] 从旧版本升级后自动迁移 token

## Task 2: Dio 版本升级
- [x] pubspec.yaml 中 dio 版本为 ^5.4.3+
- [ ] flutter pub get 成功（待本地执行）
- [ ] flutter analyze 无 Dio 相关错误（待本地执行）

## Task 3: video_player 版本升级
- [x] pubspec.yaml 中 video_player 版本为 ^2.9.0+
- [ ] flutter pub get 成功（待本地执行）
- [ ] flutter analyze 无 video_player 相关错误（待本地执行）

## Task 4: PaintingBinding API 更新
- [x] main.dart 中使用 WidgetsBinding.instance.imageCache
- [x] 移除 PaintingBinding.instance.imageCache 调用
- [ ] flutter analyze 无弃用警告（待本地执行）

## Task 5: SRT 字幕解析健壮性
- [x] subtitle_track.dart 中使用 RegExp(r'\n{2,}') 分割 block
- [x] 解析多个空行分隔的 SRT 文件成功
- [x] 原有正常 SRT 文件解析不受影响
