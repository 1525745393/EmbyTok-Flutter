# RELEASE.md — 版本升级与发布流程

本文档描述 EmbyTok 项目的标准发布流程，适用于所有版本（patch / minor / major / pre-release）。

> 关键词「必须 / 建议 / 可选」遵循 RFC 2119 语义。

---

## 1. 版本号约定（Semantic Versioning 2.0.0）

```
MAJOR.MINOR.PATCH[-PRERELEASE]
```

| 字段 | 变更时机 | 示例 |
| --- | --- | --- |
| **MAJOR** | 不兼容的 API 变更 | `1.x.x` → `2.0.0` |
| **MINOR** | 向下兼容的功能新增 | `1.2.x` → `1.3.0` |
| **PATCH** | 向下兼容的问题修复 | `1.2.3` → `1.2.4` |
| **PRERELEASE** | 内测 / RC 版本（可选） | `1.2.4-beta.1`、`1.2.4-rc.1` |

### 当前项目版本号位置（单一事实来源 + 同步更新）

发布新版本 **必须** 同时更新以下 5 处：

| 位置 | 字段/变量 | 示例 |
| --- | --- | --- |
| `frontend/pubspec.yaml` | `version: 1.2.4` | 语义版本号 |
| `frontend/android/app/build.gradle` | `versionName "1.2.4"` + `versionCode 15` | 版本名 + 整数递增 |
| `frontend/lib/utils/version.dart` | `kAppVersion = '1.2.4'` / `kAppVersionCode = 15` | Dart 常量 |
| `backend/core/version.py` | `__version__ = "1.2.4"` | Python 常量 |
| `CHANGELOG.md` | 新增 `## [1.2.4] — YYYY-MM-DD` 条目 | 用户可读变更说明 |

### versionCode 规则（Android）

- **必须单调递增**（整数）
- 建议与语义版本号保持线性关系：
  - `versionCode = 10000 * MAJOR + 100 * MINOR + PATCH`
  - 例如 `1.2.4` → `10000 + 200 + 4 = 10204`
- 当前项目仍使用较简单的自定义递增，只要每次发布 `+1` 即可。

---

## 2. 发布前检查清单（Checklist）

在执行发布之前，逐项勾选并满足以下要求：

### 2.1 代码质量

- [ ] 所有代码已提交到 Git，`git status` 显示 `nothing to commit, working tree clean`
- [ ] GitHub Actions 最新一次 CI 构建状态为 **通过**
- [ ] 本地运行 `flutter analyze` 无严重错误（error/warning 级别为 0 或可接受）

### 2.2 版本号一致性

- [ ] `pubspec.yaml` 中 `version` 字段为本次目标版本
- [ ] `build.gradle` 中 `versionName` 与 `versionCode` 正确
- [ ] `lib/utils/version.dart` 中 `kAppVersion` 与 `kAppVersionCode` 同步
- [ ] `backend/core/version.py` 中 `__version__` 同步
- [ ] 运行 `scripts/verify-release.sh`，输出显示 `✅ 所有检查通过`

### 2.3 Changelog

- [ ] `CHANGELOG.md` 中已新增 `## [X.Y.Z] — YYYY-MM-DD` 条目
- [ ] 该条目下包含 Added / Changed / Fixed 等分类，且每条变更描述面向**用户**
- [ ] `[未发布]` 区块中本次发布涉及的变更已移动到新的版本条目下

### 2.4 构建验证

- [ ] Android Release 构建：`cd frontend && flutter build apk --release --split-per-abi`
- [ ] Docker 后端构建：`docker build -t embytok-backend:vX.Y.Z backend/`

---

## 3. 标准发布步骤（Step-by-Step）

> 以从 `1.2.3` 升级到 `1.2.4` 为例。

### 步骤 1：创建发布分支（可选，patch 版本可在 main 直接操作）

```bash
git checkout main
git pull origin main
git checkout -b release/v1.2.4
```

### 步骤 2：更新版本号

**2a. `frontend/pubspec.yaml`**
```diff
- version: 1.2.3
+ version: 1.2.4
```

**2b. `frontend/android/app/build.gradle`**
```diff
- versionCode 14
- versionName "1.2.3"
+ versionCode 15
+ versionName "1.2.4"
```

**2c. `frontend/lib/utils/version.dart`**
```diff
- const String kAppVersion = '1.2.3';
- const int kAppVersionCode = 14;
+ const String kAppVersion = '1.2.4';
+ const int kAppVersionCode = 15;
```

**2d. `backend/core/version.py`**
```diff
- __version__: str = "1.2.3"
+ __version__: str = "1.2.4"
```

### 步骤 3：更新 CHANGELOG.md

将 `[未发布]` 区块中自上次发布以来的变更移动到新版本条目中：

```diff
+ ## [1.2.4] — 2026-06-14
+
+ ### Fixed
+
+ - 修复 Flutter 构建失败：providers.dart export 指令顺序错误
+
+ ### Added
+
+ - 新增语义版本管理系统（version.dart / version.py）
+ - 新增发布验证脚本 verify-release.sh
```

### 步骤 4：提交版本更新

```bash
git add -A
git commit -m "chore: 发布 v1.2.4"
```

### 步骤 5：运行发布验证脚本

```bash
./scripts/verify-release.sh
```

期望输出：`✅ 所有检查通过，可以发布！`

### 步骤 6：创建并推送 tag

```bash
git tag v1.2.4 -m "Release v1.2.4"
git push origin main
git push origin v1.2.4
```

> **重要**：tag 一旦推送到远端即视为不可变。如需修改，请生成新的 patch 版本。

### 步骤 7（可选）：合并到 release 分支并触发发布流水线

- 如果项目设置了 GitHub Release 自动触发，推送 tag 后将自动创建 Release
- 否则在 GitHub Release 页面手动创建，描述从 CHANGELOG 对应条目中复制

---

## 4. 预发布版本流程（Beta / RC）

预发布版本号示例：`1.3.0-beta.1`、`1.3.0-rc.1`

- 在 `pubspec.yaml` / `build.gradle` / `version.dart` / `version.py` 中填入带 `-xxx.N` 后缀的版本
- CHANGELOG 中以 `## [1.3.0-beta.1] — YYYY-MM-DD` 格式记录
- tag 命名为 `v1.3.0-beta.1`
- 建议标记为 GitHub "Pre-release"，直到正式 release 发布

---

## 5. 常见问题与风险控制

| 风险 | 现象 | 处理方式 |
| --- | --- | --- |
| **Git 历史改写** | `git commit --amend` 或 `git rebase` 已经推送的 tag 指向 commit | tag 推送到远端后 **禁止** amend 或 rebase。如需修正，生成新的 patch 版本（+1 PATCH），并用新 tag 发布 |
| **版本号不一致** | `verify-release.sh` 报告 `ERRORS > 0` | 对照第 1 节的 5 处位置逐一核对并同步更新 |
| **CHANGELOG 冲突** | 多人同时编辑 CHANGELOG.md 导致 `<<<<<<<` 标记 | **结构化合并**：保留单一版本号标题，按 Added/Changed/Fixed 等小节合并条目，去除冲突标记 |
| **versionCode 递减** | build.gradle 中 versionCode 小于上次发布 | 必须 +1，或使用 `10000 * MAJOR + 100 * MINOR + PATCH` 的公式自动计算 |
| **CI 构建失败** | GitHub Actions 构建未通过 | 在发布前必须保证 CI 为绿色；若仅为非关键测试 flaky，考虑标记为 allow-failure 并在下次修复 |

---

## 6. 快速命令参考

| 场景 | 命令 |
| --- | --- |
| 查看当前版本号 | `grep -E "^version" frontend/pubspec.yaml` |
| 发布前验证 | `./scripts/verify-release.sh` |
| 发布前验证 + 测试 | `./scripts/verify-release.sh --with-tests` |
| 查看已发布 tag | `git tag --sort=-creatordate | head -10` |
| 创建发布 tag | `git tag v1.2.4 -m "Release v1.2.4"` |
| 推送 tag | `git push origin v1.2.4` |
