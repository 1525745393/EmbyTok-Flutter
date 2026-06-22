# 项目全面检查 - Spec

## Overview
- **Summary**: 对 EmbyTok-Flutter 项目进行全面检查，验证代码实现是否符合规格要求，识别缺失或需要修复的问题。
- **Purpose**: 确保项目达到发布标准，发现并记录所有待处理的问题。
- **Target**: EmbyTok-Flutter v1.0 发布前的全面检查。

## Why
用户要求"检查项目"，需要全面审查项目状态：
- 验证现有功能是否正确实现
- 识别代码质量问题
- 检查文档完整性
- 确保符合发布标准

## What Changes

### 检查范围
1. **代码完整性检查**：验证所有必需文件是否存在
2. **功能实现检查**：验证核心功能是否按规格实现
3. **代码质量检查**：分析代码结构、潜在问题
4. **后端 API 检查**：验证 FastAPI 路由和数据模型
5. **文档完整性检查**：验证 README 和文档是否完整
6. **安全问题检查**：验证敏感信息处理和认证机制

## Impact
- **Affected specs**: embbytok-flutter-v1, fix-video-ui-v1
- **Affected code**: 所有前端和后端文件

## ADDED Requirements

### Requirement: 代码完整性检查
项目 SHALL 包含所有必需的文件和目录结构。

#### Scenario: 前端目录结构
- **WHEN**: 检查 `frontend/lib/` 目录
- **THEN**: 必须包含 `models/`, `views/`, `widgets/`, `services/`, `providers/`, `utils/` 目录

#### Scenario: 后端目录结构
- **WHEN**: 检查 `backend/` 目录
- **THEN**: 必须包含 `main.py`, `routers/`, `models/`, `clients/`, `core/` 目录

### Requirement: 功能实现检查
核心功能 SHALL 按照 AC-1 到 AC-10 实现。

#### Scenario: 登录功能
- **WHEN**: 检查 `login_view.dart`
- **THEN**: 必须包含后端代理地址、Emby 服务器地址、用户名、密码输入框

#### Scenario: 视频播放
- **WHEN**: 检查 `video_player_widget.dart`
- **THEN**: 必须支持播放控制、手势交互、认证 URL

### Requirement: 代码质量检查
代码 SHALL 符合 Flutter 最佳实践。

#### Scenario: 无严重编译错误
- **WHEN**: 运行 `flutter analyze`
- **THEN**: 无 error 级别问题

#### Scenario: Provider 正确使用
- **WHEN**: 检查 providers/
- **THEN**: 所有 Provider 正确使用 Riverpod 语法

## 检查清单

### Phase 1: 文件结构检查
- [ ] 前端目录结构完整
- [ ] 后端目录结构完整
- [ ] 必需文件存在

### Phase 2: 核心功能检查
- [ ] 登录页面完整
- [ ] 视频播放组件完整
- [ ] 手势交互组件完整
- [ ] 收藏功能完整
- [ ] 搜索功能完整
- [ ] 历史记录功能完整

### Phase 3: 后端 API 检查
- [ ] 健康检查端点
- [ ] 认证端点
- [ ] 媒体库端点
- [ ] 搜索端点

### Phase 4: 代码质量检查
- [ ] Flutter analyze 无错误
- [ ] 依赖配置正确
- [ ] 无硬编码敏感信息

### Phase 5: 文档检查
- [ ] README 完整
- [ ] 必要的文档存在

## Open Questions
- [ ] 是否有遗漏的核心功能？
- [ ] 代码是否有明显的性能问题？
- [ ] 是否有未处理的边界情况？
