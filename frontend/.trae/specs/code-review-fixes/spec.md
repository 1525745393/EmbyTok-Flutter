# 代码审查问题修复 Spec

## Overview
- **Summary**: 修复代码审查报告中确认存在的真实问题，包括安全漏洞、依赖版本升级、代码优化
- **Purpose**: 提升应用安全性和稳定性，修复已知漏洞和风险
- **Target Users**: 所有 EmbyTok 用户，特别是关心数据安全和应用稳定性的用户

## Goals
- 修复 access_token 明文存储的安全风险
- 升级 Dio 修复 CVE-2024-30167 SSL 证书校验绕过漏洞
- 升级 video_player 修复 MediaCodec 释放竞态问题
- 修复 PaintingBinding API 弃用警告
- 提升 SRT 字幕解析的健壮性

## Non-Goals (Out of Scope)
- 不修改业务逻辑或功能行为
- 不重构现有代码结构
- 不添加新功能
- 不修改报告中已确认不存在的问题（如 formattedDuration、URL &amp; 问题等）

## Background & Context
根据 EmbyTok_Code_Review_Report.md 的验证结果，报告中 56 个问题中约 5 个为真实问题需要修复：
- 2 个安全问题（access_token 明文存储、Dio CVE）
- 1 个依赖版本问题（video_player MediaCodec 竞态）
- 2 个代码优化问题（PaintingBinding API、SRT 解析）

## Functional Requirements
- **FR-1**: access_token 应使用 flutter_secure_storage 存储，而非 SharedPreferences
- **FR-2**: Dio 版本应升级到 5.4.3+ 修复 CVE-2024-30167
- **FR-3**: video_player 版本应升级到 2.9+ 修复 MediaCodec 竞态
- **FR-4**: PaintingBinding API 应更新为 WidgetsFlutterBinding 兼容写法
- **FR-5**: SRT 字幕解析应使用更健壮的分割方式

## Non-Functional Requirements
- **NFR-1**: 修复不应改变现有登录/播放流程的行为
- **NFR-2**: 修复后应保持向后兼容性（旧版本存储的数据应能正常迁移）
- **NFR-3**: 依赖升级不应引入新的编译错误

## Constraints
- **Technical**: Flutter/Dart 环境，使用 Riverpod 状态管理
- **Dependencies**: 项目已依赖 flutter_secure_storage，可直接使用

## Assumptions
- 用户已安装 flutter_secure_storage 依赖（项目已声明）
- 旧版本存储的数据（SharedPreferences）需要迁移到新存储方式
- 依赖升级后不需要修改代码适配新 API

## Acceptance Criteria

### AC-1: access_token 使用安全存储
- **Given**: 用户登录成功
- **When**: 系统持久化登录信息
- **Then**: access_token 存储在 flutter_secure_storage（Keychain/Keystore）中，SharedPreferences 仅存储非敏感信息
- **Verification**: `human-judgment`

### AC-2: 旧数据迁移
- **Given**: 用户已使用旧版本登录过（access_token 存储在 SharedPreferences）
- **When**: 用户启动新版本应用
- **Then**: 系统自动从 SharedPreferences 读取旧 token 并迁移到 flutter_secure_storage
- **Verification**: `human-judgment`

### AC-3: Dio 版本升级
- **Given**: pubspec.yaml 中声明 Dio 依赖
- **When**: 运行 flutter pub get
- **Then**: Dio 版本为 5.4.3+，无编译错误
- **Verification**: `programmatic`

### AC-4: video_player 版本升级
- **Given**: pubspec.yaml 中声明 video_player 依赖
- **When**: 运行 flutter pub get
- **Then**: video_player 版本为 2.9+，无编译错误
- **Verification**: `programmatic`

### AC-5: PaintingBinding API 更新
- **Given**: 应用启动时配置 ImageCache
- **When**: 应用启动
- **Then**: 使用 WidgetsFlutterBinding.ensureInitialized().imageCache 而非弃用的 API
- **Verification**: `human-judgment`

### AC-6: SRT 解析健壮性提升
- **Given**: SRT 文件使用单个换行或多个空行分隔 block
- **When**: 解析 SRT 文件
- **Then**: 解析正确，不报错
- **Verification**: `programmatic`

## Open Questions
- [ ] 是否需要在设置页面添加"清除安全存储"选项？（当前不需要）
- [ ] 是否需要为安全存储添加加密？（flutter_secure_storage 已使用系统级加密）
