# RELEASE_OPTIMIZATION.md — 发布流程优化方案

> 本文档概述 EmbyTok Flutter 项目的发布流程优化方案，包含缓存加速、质量保障、安全增强、用户体验优化等内容。

---

## 一、当前流程的问题与挑战

### 1.1 构建效率
- **Gradle 依赖无持久缓存**：CI 中每次运行 `flutter build apk` 时，Gradle 都要重新下载依赖，显著增加构建时间（预计 2–5 分钟）。
- **Flutter pub 缓存未隔离**：不同版本的 Flutter SDK 之间未区分缓存 key。
- **Android SDK 重复下载**：GitHub Actions runner 中的 Android SDK platform/build-tools 在非标准版本时需要重新下载。

### 1.2 质量保障
- **发布前缺少自动验证**：tag 推送前无法检查版本号不一致、CHANGELOG 缺失等问题。
- **构建产物缺少完整性校验**：下载 APK 后用户无法确认文件未被篡改。
- **测试未在发布前强制执行**：即使单元测试失败，仍可能触发发布构建。

### 1.3 安全增强
- **签名校验缺失**：APK 签名是否正确（未调试的 debug 签名 vs 正式 release 签名）未做验证。
- **版本号单调递增未强制**：理论上存在 versionCode 回退的风险。

### 1.4 用户体验
- **发布说明依赖人工填写**：容易遗漏关键变更。
- **无发布回滚方案**：发布出错时需要手动操作，风险高。
- **无版本兼容性检查**：用户安装新版本时无法提示 minSdk 等兼容性问题。

### 1.5 流程简化
- **版本号更新分散**：需手动修改 pubspec.yaml、build.gradle、version.dart、version.py 共 4 个位置，遗漏率高。
- **tag 创建不规范**：缺乏统一约定（`vMAJOR.MINOR.PATCH`）。

---

## 二、优化方案概览

| 维度 | 具体方案 | 实现位置 | 预期收益 |
| --- | --- | --- | --- |
| **速度** | 多层缓存（Java / Gradle / Flutter pub / Android SDK） | `.github/workflows/android-release.yml` | 构建时间减少 30%–60% |
| **质量** | 发布前 verify-release.sh 自动验证；analyze/test 可选 | `scripts/verify-release.sh` + CI workflow | 避免错误版本上线 |
| **安全** | SHA256 校验和；签名验证（`apksigner verify --verbose`）；versionCode 单调递增检查 | CI workflow + verify-release.sh | 可防篡改和回退攻击 |
| **体验** | 自动 CHANGELOG 条目；自动生成 Release notes + 构建时间/产物大小/耗时统计 | CI workflow + `scripts/release.sh` | 发布信息丰富、可追溯 |
| **简化** | Makefile 一键目标 + 交互式 release.sh + 回滚脚本 | `Makefile` + `scripts/release.sh` | 发布操作 ≤ 1 个命令 |

---

## 三、已实现优化详解

### 3.1 发布前自动验证（scripts/verify-release.sh）

**验证项：**
1. 关键文件存在（pubspec.yaml、build.gradle、version.dart、version.py、CHANGELOG.md）
2. 前端版本号一致性（pubspec ↔ gradle ↔ dart 三处必须相等）
3. versionCode 一致性与"大于上次 tag"的检查
4. 前后端版本同步性检查（可选警告）
5. CHANGELOG.md 中是否存在当前版本的 `## [X.Y.Z]` 条目
6. Android SDK 配置检查（minSdk / targetSdk / compileSdk，Google Play 的 minSdk ≥ 21 要求）
7. Git 工作树干净检查
8. 可选：`--with-tests` 运行 Flutter 测试
9. 可选：`--with-analyze` 运行 flutter analyze

**输出示例：**
```
✅ 所有关键检查通过，可以发布！
  注意：存在 1 个警告项，请酌情处理

  版本信息：
    版本号: 1.2.4
    versionCode: 15
    minSdk: 21, targetSdk: 34
```

**使用方式：**
```bash
./scripts/verify-release.sh           # 基础验证
./scripts/verify-release.sh --strict  # 基础验证 + 测试 + analyze
./scripts/verify-release.sh --with-tests --with-analyze
```

### 3.2 CI 多层缓存（android-release.yml）

在 `build-android` job 中添加 4 层缓存：

1. **Java / Gradle 缓存**：`actions/setup-java@v4` + `cache: "gradle"`
2. **Flutter 缓存**：`subosito/flutter-action@v2` 的 cache-key 基于 `pubspec.lock` 哈希
3. **Gradle wrapper & dependencies 缓存**：`actions/cache@v4` 缓存 `~/.gradle`
4. **Android SDK 缓存**：`actions/cache@v4` 缓存 `platforms/android-34` 与 `build-tools/34.0.0`

**缓存命中率评估**：相同 SDK 版本时，首次构建需下载依赖（~3–5 分钟），后续构建命中缓存，依赖部分可在 30 秒内完成。

### 3.3 构建计时与产物大小

构建过程中记录：
- APK 构建时间（`apk_build_time`）
- AAB 构建时间（`aab_build_time`）
- 总耗时（`total_build_time`）

输出到 GitHub Release 中的 `body`，便于版本间性能对比。

### 3.4 SHA256 校验和自动生成

构建完成后执行：
```bash
sha256sum build/app/outputs/flutter-apk/app-release.apk
sha256sum build/app/outputs/bundle/release/app-release.aab
```

生成 `checksums.sha256` 并作为 artifact 上传，最终附在 GitHub Release 中。用户安装前可通过：
```bash
sha256sum -c checksums.sha256
```

### 3.5 APK 签名验证（release mode）

使用 Android SDK 自带的 `apksigner verify --verbose` 检查：
- 是否为正式 release 签名（而非 debug 签名）
- 签名证书指纹是否正确
- v1/v2/v3 签名方案支持情况

### 3.6 CHANGELOG 自动生成 Release Notes

在 `create-release` job 中：
1. 从 `CHANGELOG.md` 提取 `## [X.Y.Z]` 到 `## [X.Y.Z-1]` 之间的内容
2. 追加构建时间、版本号、versionCode、APK 文件大小
3. 生成完整的 Release body

### 3.7 一键发布脚本（scripts/release.sh）

支持模式：
- `patch`：1.2.4 → 1.2.5（Bug 修复）
- `minor`：1.2.4 → 1.3.0（新增功能）
- `major`：1.2.4 → 2.0.0（破坏性变更）
- `bump`：交互式选择（推荐）
- `custom 1.2.5`：手动指定版本号
- `--dry-run`：预览不实际变更

**执行流程：**
1. 检查 Git 工作树干净 → 2. 读取当前版本 → 3. 计算新版本 → 4. 修改 4 个文件 → 5. 添加 CHANGELOG 条目 → 6. 运行 verify-release.sh → 7. git commit + tag → 8. git push

### 3.8 发布回滚脚本（scripts/rollback-release.sh）

- 删除本地和远程的最新 tag
- 保留历史 tag（v1.2.3 等）供回滚参考
- `--dry-run` 模式预览删除内容
- 不回退 main 分支代码（需手动决定是否使用 git reset/revert）

---

## 四、Makefile 目标一览

```bash
# 查看当前版本号和状态
make version

# 发布前验证（本地也可运行）
make verify-release       # 等价于 scripts/verify-release.sh
make release-check        # 别名

# 一键发布
make release-patch        # patch 版本自动发布
make release-minor        # minor 版本自动发布
make release-major        # major 版本自动发布
make release-bump         # 交互式选择
make release-dry-run      # 预览发布流程

# 回滚
make release-rollback     # 回滚到上一个 tag

# 查看相关文档
make release-docs
```

---

## 五、标准发布流程（示例）

### 场景 1：发布 patch 版本（修复 Bug）

```bash
# 1. 确保 main 分支干净
git checkout main
git pull origin main

# 2. 运行一键发布
make release-patch
# 或：./scripts/release.sh patch

# 3. 自动流程：
#    - 读取当前版本 1.2.4
#    - 自动更新到 1.2.5 (versionCode 16)
#    - 生成 CHANGELOG.md [1.2.5] 条目
#    - 运行 verify-release.sh 验证
#    - git commit "chore: 发布 v1.2.5"
#    - git tag v1.2.5
#    - git push origin main --tags

# 4. 观察 GitHub Actions 构建状态
#    - build-android job 约 5-10 分钟
#    - create-release job 自动生成 Release

# 5. 编辑 CHANGELOG.md，补充详细变更内容（可选）
```

### 场景 2：发布新版本前的验证

```bash
make verify-release
# ✅ 版本号一致？
# ✅ CHANGELOG 条目存在？
# ✅ Android SDK 配置正确？
# ✅ Git 工作树干净？

./scripts/release.sh --dry-run patch
# 预览下一个版本的变更
```

### 场景 3：发现问题后的回滚

```bash
make release-rollback
# 或：./scripts/rollback-release.sh

# 后续：
#   - 在 GitHub Release 页面手动删除对应 Release
#   - 修改版本号，重新发布
```

---

## 六、CI/CD 流程图

```
Push tag v1.2.5
     │
     ▼
GitHub Actions: android-release.yml
     │
     ├─ pre-release-check job
     │   └─ 运行 verify-release.sh → 失败则阻止后续构建
     │
     └─ build-android job
          ├─ 还原签名 keystore
          ├─ Flutter pub get (Gradle 预热)
          ├─ 构建 APK split per abi （带计时）
          ├─ 构建 AAB (release) （带计时）
          ├─ SHA256 校验和生成
          ├─ apksigner verify 签名验证
          └─ 上传 APK + AAB + 校验和 artifact

     └─ create-release job
          ├─ 下载 APK + AAB + 校验和
          ├─ 从 CHANGELOG.md 提取版本说明
          └─ 创建 GitHub Release 并附加文件
```

---

## 七、文件清单与参考

| 文件 | 用途 |
| --- | --- |
| `.github/workflows/android-release.yml` | Android 签名构建与 Release 创建（已包含缓存/计时/校验和） |
| `.github/workflows/ci.yml` | 日常 CI：Flutter 测试/analyze + 后端测试 + Docker 构建验证 |
| `scripts/release.sh` | 一键发布脚本 |
| `scripts/verify-release.sh` | 发布前验证脚本 |
| `scripts/rollback-release.sh` | 发布回滚脚本 |
| `Makefile` | 统一 Makefile，包含发布相关目标 |
| `frontend/pubspec.yaml` | Flutter 版本号单一来源 |
| `frontend/android/app/build.gradle` | Android 版本名/版本号 |
| `frontend/lib/utils/version.dart` | Dart 侧版本号管理（SemanticVersion 解析比较） |
| `backend/core/version.py` | Python 侧版本号管理（SemanticVersion 解析比较） |
| `CHANGELOG.md` | Keep a Changelog 格式变更日志 |
| `docs/RELEASE.md` | 详细发布流程说明 |
| `docs/COMMIT_CONVENTION.md` | Conventional Commits 提交信息规范 |

---

## 八、版本兼容性检查说明

### 8.1 Android 系统版本
- minSdk: 21 → Android 5.0+
- targetSdk: 34 → Android 14
- compileSdk: 34 → 最新 Android 14 SDK

### 8.2 Flutter 版本要求
- 项目要求 Flutter ≥ 3.10.0（可在 pubspec.yaml 中调整）
- CI 固定使用 3.24.0（稳定版）

### 8.3 语义版本（SemVer）
- **PATCH：** 仅修复 bug，向后兼容 → 最后一位 +1
- **MINOR：** 新增功能但向后兼容 → 中间位 +1，最后位 0
- **MAJOR：** 引入破坏性变更 → 首位 +1，其他位 0

---

## 九、后续可选优化

- [ ] **集成自动化测试**：`verify-release.sh --with-tests` 强制单元测试通过
- [ ] **发布失败告警**：添加 Slack/Discord/邮件通知
- [ ] **多环境发布通道**：alpha / beta / stable 通道
- [ ] **构建产物自动签名分离**：使用 GitHub Environments 隔离签名密钥
- [ ] **App Bundle (AAB) 自动上传到 Google Play**：需接入 Google Play Developer API
- [ ] **APK 安装后首次启动性能基准**：集成 Firebase Performance / Sentry 性能追踪
- [ ] **CHANGELOG 自动生成**：基于 `git log` 提取 Conventional Commits 生成
- [ ] **版本升级比较矩阵**：用户在网页中选择版本后，展示 CHANGELOG
- [ ] **SemVer 自动化**：使用 `standard-version` 或类似工具

---

## 十、关键提醒

1. **tag 推送后不可变**：若发现错误，使用新版本号（+1 PATCH）重新发布，切勿 amend/force-push 已发布 tag。
2. **签名密钥安全**：`ANDROID_KEYSTORE` secrets 仅限 Release 工作流使用。本地开发时建议保留自己的 debug keystore。
3. **CHANGELOG 是发布的一部分**：CHANGELOG 条目存在即视为"可发布"的信号。
4. **dry-run 模式是安全的**：`./scripts/release.sh --dry-run` 不修改任何文件，可放心用于预览。
5. **CI 缓存在 key 变化时自动失效**：pubspec.lock 或 gradle 版本变化 → 缓存 key 变化 → 新下载。
