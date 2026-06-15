# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/) 语义化版本规范。

---

## [1.1.7] - 2026-06-15

### 新增
- 发布流程脚本系统（release.sh / verify-release.sh / rollback-release.sh）
- 版本号统一管理文件（version.dart / version.py）
- CI 构建安全增强（keystore 文件权限设置）

### 修复
- 发布脚本跨平台兼容性（macOS/Linux sed 语法差异）
- Git 提交安全性（精确文件列表替代 `git add -A`）
- 回滚脚本错误消息语义清晰化

---

## [1.1.3] - 2025-06-14

### 新增
- `scripts/release.sh` - 自动化版本发布脚本，支持 patch/minor/major 三种发布类型
- `scripts/rollback-release.sh` - 发布回滚脚本，支持 dry-run 预览模式
- `scripts/verify-release.sh` - 发布前版本一致性验证脚本
- `frontend/lib/utils/version.dart` - Flutter 版本信息常量文件
- `backend/core/version.py` - Python 后端版本信息常量文件

### 修复
- **跨平台兼容性**: `release.sh` 中实现 `sed_inplace()` 函数，根据 `uname -s` 自动检测操作系统，在 macOS (BSD sed) 和 Linux (GNU sed) 上正确执行就地编辑，之前硬编码的 `sed -i` 在 macOS 上会产生临时文件或错误
- **发布安全性**: `release.sh` 中将 `git add -A` 替换为精确文件列表 `git add frontend/pubspec.yaml frontend/android/app/build.gradle frontend/lib/utils/version.dart backend/core/version.py CHANGELOG.md`，防止意外提交未跟踪的敏感文件（如密钥、本地配置等）
- **命令健壮性**: `release.sh` 开头增加 `git`/`sed`/`grep`/`awk` 命令存在性预检查，缺失时输出中文错误消息并优雅退出，避免因命令不存在导致脚本中途失败
- **CI 构建安全**: GitHub Actions workflow 中 keystore 文件解码后立即设置 `chmod 600` 权限，仅允许拥有者读写，并在日志中输出权限验证结果
- **回滚消息修复**: `rollback-release.sh` 中将矛盾的"已存在或不存在"消息修正为清晰的"远程 tag 不存在，跳过"，使错误信息与实际分支判断逻辑一致

### 改进
- 同步 `frontend/android/app/build.gradle` 版本号（`versionName` 1.0.7 → 1.1.3，`versionCode` 7 → 13），与 `frontend/pubspec.yaml` 保持一致
- 所有发布脚本使用统一的颜色输出风格，增强可读性
- `release.sh` 支持 `--dry-run` 参数，在不实际修改任何文件的情况下预览发布流程
- `verify-release.sh` 检查项目中 4 个版本号位置（pubspec/build.gradle/version.dart/version.py）的一致性

---

## [1.1.2] - 历史版本

- EmbyTok Flutter 客户端基础架构
- 视频浏览、搜索、收藏功能实现

---

## [1.1.0] - 初始版本

- EmbyTok Flutter 应用首次发布
- 竖屏视频浏览体验
- 媒体库管理
- 用户偏好设置

---

## 版本号说明

- **MAJOR** 版本：API 不兼容的变更
- **MINOR** 版本：向下兼容的功能性新增
- **PATCH** 版本：向下兼容的问题修正

## 发布流程

1. 执行 `./scripts/verify-release.sh` 确认当前版本号一致
2. 执行 `./scripts/release.sh --dry-run patch|minor|major` 预览发布
3. 移除 `--dry-run` 正式执行发布
4. 推送标签：`git push origin vX.Y.Z`，自动触发 GitHub Actions 构建

## 回滚流程

1. 执行 `./scripts/rollback-release.sh --dry-run` 预览回滚
2. 移除 `--dry-run` 确认执行
3. 如需回滚远程提交，执行 `git push -f origin main`（请谨慎使用）
