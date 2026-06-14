# Changelog

所有重要变更将在此文件记录。

> 格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 规范，
> 并使用 [语义版本号（Semantic Versioning）](https://semver.org/lang/zh-CN/)。

## 变更分类

本项目使用以下标准分类（每项按顺序排列）：

| 分类 | 含义 | Git 提交前缀示例 |
| --- | --- | --- |
| **Added** | 新功能 / 新增特性 | `feat:` |
| **Changed** | 既有功能行为变更 | `refactor:`、`chore(deps):` |
| **Deprecated** | 标记为将被移除的功能 | `deprecate:` |
| **Removed** | 移除已废弃功能 | `remove:` |
| **Fixed** | Bug 修复 | `fix:` |
| **Security** | 安全相关修复 | `security:` / `fix(sec):` |
| **Performance** | 性能优化 | `perf:` |
| **Docs** | 文档 / 注释变更 | `docs:` |
| **Style** | 代码格式化 / 风格调整 | `style:` |
| **Test** | 测试相关变更 | `test:` |

---

## [未发布] — yyyy-mm-dd

> 说明：每次新的变更**优先追加到此区块**，直到下一次版本发布时将此处内容移动到对应版本号区块，并更新日期。

### Added

- （待补充）

### Changed

- （待补充）

### Fixed

- （待补充）

---

## [1.2.4] — 2026-06-14

### Fixed

- 修复 Flutter 构建失败：`providers.dart` 中 `export` 指令位于声明之后，违反 Dart 语法规则
- 统一 `pubspec.yaml`、`build.gradle`、`lib/utils/version.dart` 之间版本号不一致问题

### Added

- 新增语义版本管理系统：`frontend/lib/utils/version.dart（Dart）与 `backend/core/version.py`（Python）
- 新增发布验证脚本 `scripts/verify-release.sh`
- 新增版本升级步骤文档 `docs/RELEASE.md`
- 新增 Git 提交信息规范 `docs/COMMIT_CONVENTION.md`

---

## [1.2.3] — 2026-06-14

### Changed

- 根据项目整体代码整理
- （历史版本的详细信息请参考 Git 提交历史

---

## [1.2.2] — 2026-06-14

### Changed

- （请在每次发布时补充）

---

## [1.2.1] — 2026-06-14

### Changed

- （请在每次发布时补充）

---

## [1.2.0] — 2026-06-14

### Added

- EmbyTok Flutter 项目初始化，完成竖屏视频浏览核心功能

---

## [1.0.0] — 2026-06-01

### Added

- 初始版本发布

---

## 版本号格式说明

**MAJOR.MINOR.PATCH**

- **MAJOR**（主版本号）：当你做了不兼容的 API 修改
- **MINOR**（次版本号）：当你做了向下兼容的功能性新增
- **PATCH**（修订号）：当你做了向下兼容的问题修正

**预发布版本标识**（可选，可选于 PATCH 之后）：`1.2.4-beta.1`、`1.2.4-rc.1`

## 本文件编辑规范

1. **最新版本永远在最上方，旧版本按时间倒序排列；
2. 相同类型的变更应归为同一组（Added / Changed / Fixed ...）；
3. 每条变更行以动词开头，结尾不加句号；
4. 每条变更描述面向**用户**而非开发者（即“可以理解为什么有用途），必要时补充到提交哈希以便引用；
5. 发布版本标题格式固定为：`## [X.Y.Z] — YYYY-MM-DD`；
6. 在 GitHub 链接中列出链接到对应 tag。
