# 代码审查标准与流程（Code Review Standard & Process）

> 目的：解决「代码质量参差不齐」，把评审从「凭感觉」变成「可按清单执行、可复盘」的机制。
> 适用范围：`frontend`（Flutter / Dart 3 / Riverpod / GoRouter / Material 3）与 `backend`（FastAPI / Python）的全部 Pull Request。
> 配套文件：`.github/PULL_REQUEST_TEMPLATE.md`（PR 必填）、`docs/COMMIT_CONVENTION.md`（提交规范）、`.github/workflows/ci.yml` 与 `pr-check.yml`（CI 门禁）。

---

## 1. 角色与职责

| 角色 | 职责 |
| --- | --- |
| **Author（作者）** | 开 PR 前本地自测；按模板填描述；回应每条评审意见；修复后重新请求评审 |
| **Reviewer（审查者）** | 至少 1 人；核心模块（播放器、状态管理、鉴权、后端路由）至少 2 人。对 Blocker / Major 给出明确结论 |
| **Maintainer（维护者）** | 拥有合并权限；确认所有门禁通过、争议已裁决；执行 Squash Merge |

审查是**共同对质量负责**，不是挑错。意见分「必须改」与「建议改」，禁止人身评价。

---

## 2. 评审流程（PR 生命周期）

1. **开 PR 前（Author）**
   - `flutter analyze lib` 零 `error`；`flutter test` 全绿。
   - 自审：自己 diff 一遍，确认无调试残留、无硬编码密钥。
2. **开 PR**
   - 必须用 PR 模板；标题符合 Conventional Commits（已被 `pr-check.yml` 强制，不通过则无法合并）。
   - 描述写清：**改了什么 / 为什么 / 如何验证**。
3. **CI 门禁全绿**：`analyze`（0 error）、`test`、`docker build`（见 `ci.yml`）。
4. **人工评审**：至少 1 名 Reviewer 完成评审，所有 **Blocker / Major** 关闭或显式 waiver。
5. **合并**：使用 **Squash Merge**（与 semantic-release / CHANGELOG 自动生成对齐，见 `COMMIT_CONVENTION.md`）。
6. **合并后**：删除源分支；在 CHANGELOG 中按 type 归类（成员已废弃的 style/test 不记录）。

---

## 3. 评审清单（逐维度核对）

### 3.1 架构与状态管理（Riverpod）
- [ ] Provider 单一职责；不在 `build` 中创建 Controller / Subscription / 发起网络请求。
- [ ] 跨组件状态走 provider，不靠全局单例随意传递。
- [ ] 路由用 GoRouter 声明式跳转，不在 Widget 里裸调 `Navigator` 绕过守卫。
- [ ] **文件体量**：单文件 > 400 行需说明理由或拆分。（反面案例：`feed_view.dart` 已约 900 行，新增逻辑应优先下沉到 `coordinators/`、`widgets/` 或新 provider，而非继续堆在页面里。）

### 3.2 UI 与主题（Material 3）
- [ ] 颜色只用 `Theme.of(context).colorScheme`，**禁止硬编码 hex**（设计令牌外的特殊色需先在 `theme/app_theme.dart` 显式定义）。
- [ ] 间距 / 圆角使用统一令牌，避免散落魔法数字（`8 / 12 / 4 / 32` 等应集中为常量）。
- [ ] 沿用既有文案约定：**中文 UI 文案、英文注释、英文类名/变量名**。
- [ ] Widget 拆分粒度：一个 UI 块一个私有类 / 小组件，避免超长 `build`。
- [ ] 暗色模式必须自测（本仓库默认已改为深色主题，UI 改动须验证亮/暗两套）。

### 3.3 性能
- [ ] 视频 / 图片资源及时释放（`VideoPlayerController.dispose()`、`CachedNetworkImage` 带 `cacheWidth`）。
- [ ] 列表用 `ListView.builder` / 分页加载，不一次性加载全量。
- [ ] 新增交互带防抖（搜索 150–300ms、滚动保存 500ms、跳页 100ms，沿用现有节奏）。
- [ ] `build` 中不创建临时对象（如每次重建 `BoxDecoration`）；可 `const` 的提取为 `const`。

### 3.4 健壮性与错误处理
- [ ] **所有 `Future` 必须包 `try/catch`，错误以中文提示**（既有约定，强制）。
- [ ] 空 / 错误 / 加载三态齐全；优先复用 `EmptyStateCard` / `ErrorStateCard`，不自造。
- [ ] 不吞异常、不向用户暴露堆栈；后端新增路由返回统一 JSON 错误格式（沿用 `core.errors.APIError`）。

### 3.5 测试
- [ ] 纯逻辑 / provider 必须有单测（`mockito` + `http_mock_adapter` 已配置）。
- [ ] 关键路径覆盖：状态切换、错误分支、分页边界、空数据。
- [ ] **测试失败必须阻断发布**（当前 `ci.yml` 的 `flutter test ... || echo` 会豁免失败，属质量缺口，建议改为硬门禁，见第 6 节）。

### 3.6 安全
- [ ] 后端 CORS 不允许 `allow_origins=["*"]` 公网暴露；限制为前端域名白名单。
- [ ] 密钥 / Token 不进代码，统一走 Secrets（见 `.github/SECRETS.md`）。
- [ ] 用户输入（搜索词、路径参数、Emby 返回字段）必须校验 / 转义后再使用。

### 3.7 无障碍
- [ ] 可点击目标 ≥ 44×44 px。
- [ ] 键盘 / 遥控器可用（本仓库已有快捷键，TV 模式规划中）；焦点态可见。
- [ ] 文字与背景对比度符合 **WCAG AA**（正文 4.5:1，大文本 3:1）。

### 3.8 文档与提交
- [ ] 公共 API / 新增 Provider 补注释；破坏性变更在 footer 标 `BREAKING CHANGE:`。
- [ ] 提交信息符合 `COMMIT_CONVENTION.md`；**单次提交只做一件事**。
- [ ] PR 描述说明「改了什么 / 为什么 / 如何验证」。

---

## 4. 问题严重级别

| 级别 | 含义 | 合并前要求 |
| --- | --- | --- |
| **Blocker** | 编译错误、崩溃、数据丢失、安全漏洞、破坏现有功能 | 必须修复 |
| **Major** | 明显 bug、性能回退、无障碍硬伤、违反主题基线（硬编码色） | 必须修复，或 Maintainer 显式 waiver 并留 issue |
| **Minor** | 命名、重复代码、魔法数字、`warning` 级 lint | 建议修复，可跟进 issue |
| **Nit** | 纯风格偏好 | 可选 |

**合并准入条件**：0 个未关闭的 Blocker；0 个未 waiver 的 Major；至少 1 个审批；CI 全绿。

---

## 5. 本仓库常见反模式（来自实际代码走查）

- 巨型 `build` 方法 / 巨型文件（如 `feed_view.dart` ~900 行）。
- 硬编码颜色与散落魔法间距数字，未走 `ColorScheme` / 设计令牌。
- 在 `build` 内发起网络请求或创建控制器。
- 异步未捕获、空状态未处理。
- PR 描述缺失，或标题不符合 Conventional Commits（已被 `pr-check.yml` 拦截）。
- 测试被 `|| echo` 豁免，导致坏测试长期堆积。

---

## 6. 自动化与工具（已有 + 建议强化）

**已有**
- `.github/workflows/pr-check.yml`：强制 PR 标题符合 Conventional Commits。
- `.github/workflows/ci.yml`：`flutter analyze`（仅 `error` 阻断）、`flutter test`、`docker build`。
- `flutter_lints`（基础规则）。

**建议强化（提升一致性、堵住质量缺口）**
1. `ci.yml` 中把 `flutter test ... || echo "不影响发布"` 改为失败即 `exit 1`，让测试成为硬门禁。
2. 引入 `very_good_analysis` 或自定义 `analysis_options.yaml`，把 `warning` 级 lint 纳入评审关注（与现有「中文文案 / 英文注释」约定互补）。
3. 可选：PR 尺寸限制（如单 PR ≤ 800 行 diff）、依赖审计（`pip-audit` / `flutter pub outdated` 报告）。

> 上述强化属于 CI 行为变更，落地前请在团队内确认；需要我直接改 `ci.yml` 可另行提出。

---

## 7. Reviewer 合并准入清单（勾选后合并）

- [ ] CI 全绿（analyze 0 error、test 通过、build 成功）
- [ ] 至少 1 个审批（核心模块 2 个）
- [ ] 所有 Blocker / Major 已关闭或显式 waiver
- [ ] 符合主题基线（无硬编码色）与无障碍基线（对比度 AA、点击目标 ≥44）
- [ ] 提交信息规范、PR 描述完整
- [ ] UI 改动已自测暗色模式 / 手势 / 字幕
