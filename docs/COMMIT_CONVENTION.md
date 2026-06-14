# COMMIT_CONVENTION.md — Git 提交信息规范

本项目遵循 **Conventional Commits**（约定式提交）规范，
并以中文为提交说明语言。规范的提交信息让 CHANGELOG 自动生成、版本号自动递增成为可能。

---

## 1. 提交信息格式

```
<type>(<scope>): <subject>
<空行>
<body>
<空行>
<footer>
```

- **type**（必填）：变更类型，使用下列枚举值之一
- **scope**（可选）：变更影响的模块（如 `video-player`、`auth`、`backend`、`ci`）
- **subject**（必填）：简短描述（建议中文，≤ 50 字符，以动词开头，结尾不加句号）
- **body**（可选）：详细说明，可多行
- **footer**（可选）：破坏性变更（BREAKING CHANGE）或关联的 Issue/PR 编号

---

## 2. Type 枚举值与语义版本映射

| type | 含义 | 语义版本影响 | CHANGELOG 分类 |
| --- | --- | --- | --- |
| **feat** | 新功能（Feature） | MINOR | Added |
| **fix** | Bug 修复 | PATCH | Fixed |
| **perf** | 性能优化 | PATCH | Performance |
| **refactor** | 代码重构（非新功能也非 Bug 修复） | — | Changed |
| **style** | 代码格式化/风格调整 | — | （通常不记录） |
| **docs** | 文档/注释变更 | — | Docs |
| **test** | 新增或修改测试 | — | （通常不记录） |
| **chore** | 构建工具/依赖升级/脚手架等变更 | PATCH 或 — | Changed |
| **ci** | CI/CD 配置变更 | — | Changed |
| **build** | 构建流程或外部依赖变更 | — | Changed |
| **revert** | 撤销之前的提交 | PATCH | Changed |
| **security** | 安全修复 | PATCH | Security |
| **deprecate** | 标记为将被移除的功能 | MINOR | Deprecated |
| **remove** | 移除已废弃功能 | MAJOR | Removed |

### BREAKING CHANGE（破坏性变更）

当提交包含 API 不兼容变更时，应在 **footer** 中以 `BREAKING CHANGE:` 开头说明，
或在 type 后加 `!`（例如 `feat!: 移除旧版播放接口`）。
出现 BREAKING CHANGE 时必须 bump MAJOR 版本号。

---

## 3. 正确示例

### ✅ 新功能
```
feat(video-player): 支持长按视频 2 倍速播放
```

### ✅ Bug 修复
```
fix(auth): 修复 providers.dart 中 export 指令顺序导致构建失败的问题
```

### ✅ 文档
```
docs: 补充 RELEASE.md 中 versionCode 递增规则说明
```

### ✅ 性能优化
```
perf(video-list): 优化视频列表懒加载逻辑，减少首屏内存占用
```

### ✅ 重构
```
refactor: 将 deviceMode 迁移到 app_preferences_providers.dart
```

### ✅ 依赖升级
```
chore(deps): 升级 flutter_riverpod 到 2.5.0
```

### ✅ CI 配置
```
ci: 在 android-release.yml 中添加签名密钥检查
```

### ✅ 破坏性变更
```
feat!: 移除 /api/v1/items 旧接口

BREAKING CHANGE: /api/v1/items 接口不再支持，
请改用 /api/v2/items 并传递新的 filter 格式。
```

---

## 4. 错误示例与修正

| ❌ 错误 | ✅ 修正 | 原因 |
| --- | --- | --- |
| `更新版本号` | `chore: 发布 v1.2.4` | 缺少 type 前缀 |
| `fix bug` | `fix(video-player): 修复竖屏切换时播放状态丢失` | 语言不统一 + 无明确范围 |
| `feat: 添加了 A 功能，也修复了 B bug。` | 拆分为两个提交：`feat: ...` 和 `fix: ...` | 单次提交只做一件事 |
| `FEAT: 新功能` | `feat: 新功能` | type 必须小写 |
| `feat: 支持长按视频 2 倍速播放。` | `feat(video-player): 支持长按视频 2 倍速播放` | 结尾不加句号，建议加 scope |

---

## 5. 与 CHANGELOG 的映射规则

在撰写 CHANGELOG.md 时，按以下方式将提交映射到分类：

1. 选取自上次 release 以来的所有提交
2. 按 type 归类到 CHANGELOG 分类（见第 2 节表格）
3. 相同类型下按提交时间倒序或按功能分组（后者优先）
4. 删除纯 style / test 等不影响用户感知的提交
5. 每条变更以动词开头（"新增 / 修复 / 优化 / 移除..."），结尾不加句号

---

## 6. 提交信息生成命令参考

### 查看自 v1.2.3 以来的所有提交（用于撰写 CHANGELOG）
```bash
git log --oneline --no-merges v1.2.3..HEAD
```

### 按 type 分组查看
```bash
git log --oneline --no-merges v1.2.3..HEAD | grep -E "^[a-f0-9]+ feat" | head -20
git log --oneline --no-merges v1.2.3..HEAD | grep -E "^[a-f0-9]+ fix" | head -20
```

---

## 7. 项目规范摘要

- 使用中文撰写 subject；必要时 body 可英文补充
- 单次提交只做一件事（atomic commit 原则）
- 提交信息首字母（type 之后）不需要大写
- 不使用表情符号（保持 CI/CD 日志解析简单）
- subject 长度建议 ≤ 50 字符，body 每行 ≤ 72 字符
- BREAKING CHANGE 必须在 footer 中明确标注并 bump MAJOR 版本
