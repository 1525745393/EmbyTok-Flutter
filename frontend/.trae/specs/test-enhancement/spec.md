# 测试体系建设建议 - Product Requirement Document

## Overview
- **Summary**: 对 EmbyTok Flutter 项目当前测试状况进行评估，并提出补充测试建议，提升代码质量和稳定性
- **Purpose**: 识别当前测试覆盖的薄弱点，补充核心模块的单元测试和集成测试，降低回归风险
- **Target Users**: 开发团队、QA 团队

## Goals
- 确认当前测试体系的真实状况（测试数量、类型、覆盖率）
- 识别测试覆盖的薄弱环节
- 提出可落地的测试补充建议，按优先级排序
- 为后续测试开发提供明确的实施路径

## Non-Goals (Out of Scope)
- 不实际编写测试代码（本 PRD 仅做现状评估和建议）
- 不引入新的测试框架或工具
- 不做代码覆盖率的精确统计（环境无 Flutter SDK）
- 不涉及性能测试和压力测试

## Background & Context

### 当前测试状况（已确认）

**Flutter 单元测试（flutter test）**
- 测试文件总数：**47 个**
- 分布：
  - `models/` — 12 个（app_config, library, media_item, media_source, paginated_response, person, search_hint, subtitle_track, user_data, user, watch_history_item）
  - `providers/` — 12 个（app_preferences, auth, auto_play, favorites, library, recommend_signals, search_hints, search_history, subtitle_settings, toolbar_visibility, user_preferences, video_list_dispose）
  - `services/` — 5 个（actors_api, api_client, embytok_service, get_playback_position, video_pool_service）
  - `widgets/` — 6 个（heart_animation, seekable_progress_bar, subtitle_cue, subtitle_renderer, video_page_item_no_preload_threshold, video_player_widget_release）
  - `views/` — 5 个（back_navigation, feed_autopause, feed_view_transition, feed_view_valuekey, lifecycle_autopause）
  - `utils/` — 3 个（formatters, fullscreen_navigator, memory_cache）
  - `repositories/` — 1 个（cached_media_repository）
  - `theme/` — 1 个（system_overlay_style）

**Python 后端测试（pytest）**
- `backend/tests/` 目录：**不存在**
- Makefile 中有 `test-backend` 目标，但条件判断 `if [ -d "$(BACKEND_DIR)/tests" ]` 会跳过
- `pytest.ini`：**不存在**

**静态分析（flutter analyze）**
- 已集成到 Makefile 的 `lint` 目标
- 命令：`flutter analyze || true`（不阻断流程）

## Functional Requirements
- **FR-1**: 提供当前测试体系的完整盘点
- **FR-2**: 按优先级提出测试补充建议
- **FR-3**: 每个建议包含明确的测试范围和验收标准

## Non-Functional Requirements
- **NFR-1**: 建议应贴合项目实际，可落地执行
- **NFR-2**: 优先级划分清晰，先补核心路径再补边缘场景
- **NFR-3**: 不引入破坏性变更，所有测试与现有代码兼容

## Constraints
- **Technical**: Flutter/Dart 测试框架，使用 flutter_test 和 mockito
- **环境**: 当前环境未安装 Flutter SDK，无法运行测试和统计覆盖率
- **代码规模**: 项目约 3 万行 Dart 代码，测试文件 47 个

## Assumptions
- 现有测试均能正常通过（无 Flutter SDK 无法验证）
- 用户希望优先补充核心业务路径的测试
- 测试开发遵循现有测试文件的风格和模式

## Acceptance Criteria

### AC-1: 测试现状盘点准确
- **Given**: 项目的 test/ 目录结构
- **When**: 统计测试文件数量和分布
- **Then**: 分类准确，数量与实际文件一致
- **Verification**: `programmatic`

### AC-2: 测试建议覆盖核心薄弱点
- **Given**: 建议的测试补充清单
- **When**: 对照现有测试文件
- **Then**: 建议的测试均为现有覆盖不足或缺失的模块
- **Verification**: `human-judgment`

### AC-3: 优先级划分合理
- **Given**: 测试建议列表
- **When**: 按业务重要性和风险评估优先级
- **Then**: 核心路径（登录、播放、收藏）优先级最高
- **Verification**: `human-judgment`

## Open Questions
- [ ] 是否需要引入代码覆盖率工具（如 `coverage` 包）？
- [ ] 是否需要配置 CI/CD 自动运行测试？
- [ ] 后端 Python 测试是否计划补充？
