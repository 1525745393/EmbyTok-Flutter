# 测试体系建设建议 - 实施计划

## 当前测试状况汇总

| 测试类型 | 状态 | 数量 | 说明 |
|---------|------|------|------|
| Flutter 单元测试 | ✅ 已有 | 47 个文件 | models(12) / providers(12) / services(5) / widgets(6) / views(5) / utils(3) / repositories(1) / theme(1) |
| Python 后端测试 | ❌ 缺失 | 0 | backend/tests 目录不存在 |
| Flutter 静态分析 | ✅ 已有 | - | Makefile lint 目标，flutter analyze |
| Widget 测试 | ⚠️ 不足 | 6 个 | 多为单一 widget，缺少复杂交互测试 |
| 集成测试 | ❌ 缺失 | 0 | 无完整流程集成测试 |

---

## 建议补充的测试（按优先级）

## [ ] Task 1: MediaItem.fromJson 解析测试增强
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 扩展现有 `test/models/media_item_test.dart`
  - 覆盖 PascalCase / snake_case / 混合格式的 JSON 解析
  - 覆盖 Emby API 真实返回格式的字段映射（如 Name、RunTimeTicks、UserData 等）
  - 覆盖边缘情况：空字符串、类型不匹配、字段重命名
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-1.1: PascalCase 格式 JSON 解析正确（Emby 原生格式）
  - `programmatic` TR-1.2: snake_case 格式 JSON 解析正确
  - `programmatic` TR-1.3: 混合格式 JSON 解析正确
  - `programmatic` TR-1.4: UserData 嵌套对象解析正确
  - `programmatic` TR-1.5: 类型不匹配时优雅降级（如 string 转 int）
- **Notes**: Emby API 原生使用 PascalCase，这是最常见的实际输入格式

## [ ] Task 2: 字幕解析测试增强
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 扩展现有 `test/models/subtitle_track_test.dart`
  - 测试 parseSrt / parseVtt / parseAss 三种格式
  - 覆盖各种边界情况：空文件、超长文本、特殊字符、多个连续空行、乱序序号
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-2.1: SRT 空文件解析返回空列表
  - `programmatic` TR-2.2: SRT 单个字幕 block 解析正确
  - `programmatic` TR-2.3: SRT 多个连续空行分隔解析正确
  - `programmatic` TR-2.4: SRT 特殊字符（中文、 emoji、HTML 标签）解析正确
  - `programmatic` TR-2.5: SRT 超长文本（>1000 字符）解析正确
  - `programmatic` TR-2.6: VTT 格式解析正确（如有 parseVtt）
  - `programmatic` TR-2.7: ASS 格式解析正确（如有 parseAss）
  - `programmatic` TR-2.8: 损坏格式不崩溃，返回空列表或部分结果
- **Notes**: 字幕解析是播放体验的核心组件，需重点覆盖

## [ ] Task 3: VideoListNotifier 竞态测试
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 在 `test/providers/` 下新增测试文件
  - 测试快速连续 refresh / loadMore 的场景
  - 验证旧请求的结果不会覆盖新请求的状态
  - 验证 dispose 后请求不会导致状态异常
- **Acceptance Criteria Addressed**: AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-3.1: 快速连续调用 refresh 只保留最后一次结果
  - `programmatic` TR-3.2: 快速连续调用 loadMore 不会重复添加数据
  - `programmatic` TR-3.3: dispose 后请求完成不会抛出异常
  - `programmatic` TR-3.4: 并发请求中 isLoading 状态正确
- **Notes**: 快速滑动 feed 是高频场景，竞态问题影响用户体验

## [ ] Task 4: FavoritesNotifier 并发测试
- **Priority**: high
- **Depends On**: None
- **Description**: 
  - 扩展现有 `test/providers/favorites_provider_test.dart`
  - 测试快速连点 toggleFavorite 的去重逻辑
  - 验证最终状态与服务端一致
- **Acceptance Criteria Addressed**: AC-2, AC-3
- **Test Requirements**:
  - `programmatic` TR-4.1: 快速连续 toggleFavorite 只执行一次网络请求
  - `programmatic` TR-4.2: 最终收藏状态正确（与最后一次操作一致）
  - `programmatic` TR-4.3: 网络失败时回滚到正确的前一状态
  - `programmatic` TR-4.4: 同时对不同 item 操作互不干扰
- **Notes**: 收藏是高频操作，连点去重是常见需求

## [ ] Task 5: AuthProvider 持久化测试
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 扩展现有 `test/providers/auth_provider_test.dart`
  - 测试损坏的 SharedPreferences / flutter_secure_storage 数据恢复
  - 测试旧数据迁移逻辑（从 SharedPreferences 迁移到 secure_storage）
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-5.1: 损坏的 JSON 数据不导致启动崩溃，进入未登录状态
  - `programmatic` TR-5.2: 缺少 token 字段时进入未登录状态
  - `programmatic` TR-5.3: 旧格式数据能正确迁移到新格式
  - `programmatic` TR-5.4: secure_storage 读取失败时降级处理
- **Notes**: 与刚完成的 access_token 安全存储修复配套

## [ ] Task 6: Widget 测试 - GestureOverlay 手势交互
- **Priority**: medium
- **Depends On**: None
- **Description**: 
  - 在 `test/widgets/` 下新增 GestureOverlay 测试
  - 测试各种手势：单击、双击、长按、滑动（上下左右）、捏合缩放
  - 验证回调正确触发、冲突手势正确区分
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `programmatic` TR-6.1: 单击触发 onTap 回调
  - `programmatic` TR-6.2: 双击触发 onDoubleTap 回调（不触发 onTap）
  - `programmatic` TR-6.3: 长按触发 onLongPress 回调
  - `programmatic` TR-6.4: 垂直滑动触发 onVerticalDragUpdate 回调
  - `programmatic` TR-6.5: 水平滑动触发 onHorizontalDragUpdate 回调
  - `programmatic` TR-6.6: 滑动距离小于阈值不触发手势
- **Notes**: 手势交互是竖屏视频播放器的核心 UI，需重点测试

## [ ] Task 7: 集成测试 - 完整流程
- **Priority**: low
- **Depends On**: None
- **Description**: 
  - 使用 flutter_test + Mock 实现端到端流程测试
  - 覆盖：登录 → 浏览 feed → 播放视频 → 收藏 → 退出登录
  - 使用 mock 的 API 服务，不依赖真实 Emby 服务器
- **Acceptance Criteria Addressed**: AC-2
- **Test Requirements**:
  - `human-judgement` TR-7.1: 登录成功后进入首页
  - `human-judgement` TR-7.2: 首页能看到视频列表
  - `human-judgement` TR-7.3: 点击视频进入播放页
  - `human-judgement` TR-7.4: 播放页能触发收藏操作
  - `human-judgement` TR-7.5: 退出登录回到登录页
- **Notes**: 集成测试成本高，建议在核心单元测试完善后再补充

---

## 优先级说明

| 级别 | 数量 | 判定标准 |
|------|------|----------|
| **high** | 4 个 | 核心业务路径 / 高风险模块 / 已发现过相关 bug |
| **medium** | 2 个 | 重要但非核心 / 有一定风险 |
| **low** | 1 个 | 锦上添花 / 成本较高收益较低 |

## 建议实施顺序

1. Task 1 (MediaItem 解析) — 模型层基础，成本低收益高
2. Task 2 (字幕解析) — 模型层基础，成本低收益高
3. Task 3 (VideoList 竞态) — 核心业务，影响 feed 体验
4. Task 4 (收藏并发) — 高频操作，影响用户数据
5. Task 5 (Auth 持久化) — 配套安全存储修复
6. Task 6 (手势 Widget) — UI 交互层
7. Task 7 (集成测试) — 端到端覆盖
