# 修复 v1.13.0 发布状态 — 计划文档

## 0. 问题背景

两次 CI/CD 流水线失败，根因不同：

| # | Run | 触发方式 | 失败原因 |
|---|-----|---------|---------|
| 1 | #27777239266 | push → main | main 分支有保护，不允许直接 push `chore(release)` commit |
| 2 | #27778031947 | workflow_dispatch | `fatal: tag 'v1.13.0' already exists` — 前一次部分成功的 run 已经把 tag 推到了 GitHub，但 tag 指向了一个不在 main 分支历史上的 dangling commit |

**错误信息（第 2 次失败）:**
```
fatal: tag 'v1.13.0' already exists
[semantic-release] › ✘  An error occurred while running semantic-release: 
  ExecaError: Command failed with exit code 128: git tag v1.13.0 fe4f1dc165edad186195a722df7b6b5d0b7ebf41
```

---

## 1. 当前状态调查结果

### 1.1 main 分支的当前 HEAD
```
fe4f1dc chore(release): 1.13.0 [skip ci]   ← 当前 HEAD（由 semantic-release 生成，已成功推到 main）
 90016e5 feat: 检查 EmbyX 对接 Emby 服务器
 65004ca feat: 检查 EmbyX 对接 Emby 服务器
 5e3cecc feat: 检查 EmbyX 对接 Emby 服务器
 c55c1a0 chore(release): 1.13.0 [skip ci]   ← 更早的一次 release commit（历史遗留）
```

### 1.2 Tag `v1.13.0` 的状态
- **Tag 存在于 GitHub**: ✅
- **Tag 指向的 commit**: `59c0f35c36600f3f95c6d94e0c70c5bbc5cc71ff`
- **这个 commit 不在 main 分支的历史上**: ✅（`git merge-base --is-ancestor` 检测失败）
- **tag 的 commit 内容**: `chore(release): 1.13.0 [skip ci]`（由 semantic-release-bot 在 2026-06-17T16:02:57Z 创建）

### 1.3 GitHub Release `v1.13.0` 的状态
- **Release 存在**: ✅（非 draft，非 prerelease）
- **Release URL**: https://github.com/1525745393/EmbyTok-Flutter/releases/tag/v1.13.0
- **已上传的 APK/AAB 资产**（4 个文件）:
  - `app-arm64-v8a-release.apk` (13.5 MB)
  - `app-armeabi-v7a-release.apk` (13.1 MB)
  - `app-release.aab` (27.8 MB)
  - `app-x86_64-release.apk` (13.7 MB)
- **缺失的资产**（与 `.releaserc.json` 中 `assets` 配置对比）:
  - ❌ `app-release.apk` (universal APK) — 未上传

### 1.4 仓库文件状态
| 文件 | 值 | 来源 |
|------|-----|------|
| `frontend/pubspec.yaml` | `version: 1.13.0+1130` | fe4f1dc release commit |
| `CHANGELOG.md` | 有 3 段重复的 `# [1.13.0]` 记录 | 多次 release 尝试各自追加 |

### 1.5 核心问题总结

**Tag 一致性问题**（最关键）:
- tag `v1.13.0` 指向 commit `59c0f35c`（历史上某个更早的 release commit）
- 这个 commit **不在 main 分支的祖先链上**（dangling）
- 当前 main 的 HEAD 是 `fe4f1dc`（另一个同名的 release commit）
- 结果：tag 和 main 分支 HEAD 不一致 → 新的 CI run 检测到 tag 已存在但 tag 不在当前 main 路径上 → 无法完成 release

**文件脏状态**（次要，可接受或后续清理）:
- CHANGELOG.md 有 3 段重复的 1.13.0 条目
- 缺失 universal APK 的 release 资产

---

## 2. 可选方案对比

### 方案 A（本计划推荐）：移动 tag 到正确位置 + 清理状态
**目标**: 让 tag `v1.13.0` 指向当前 main HEAD 的 release commit (`fe4f1dc`)，修复 GitHub Release 关联

**操作步骤**（共 6 步，全部通过 GitHub REST API + Git 命令完成，无需重新构建 Flutter）:

1. **删除远程 tag `v1.13.0`**  
   `DELETE /repos/1525745393/EmbyTok-Flutter/git/refs/tags/v1.13.0`

2. **创建新 tag `v1.13.0` 指向 commit `fe4f1dc`**  
   `POST /repos/1525745393/EmbyTok-Flutter/git/refs`  
   body: `{"ref": "refs/tags/v1.13.0", "sha": "fe4f1dc165edad186195a722df7b6b5d0b7ebf41"}`

3. **验证新 tag**  
   `GET /repos/1525745393/EmbyTok-Flutter/git/ref/tags/v1.13.0` → 确认 sha 为 `fe4f1dc...`

4. **更新 GitHub Release 的 `target_commitish`**（可选）  
   获取 release id → `PATCH /repos/:owner/:repo/releases/:id` → `{"target_commitish": "main"}`  
   *注意：大多数情况下不需要，因为 release 和 tag 关联，tag 已修复后 release 自动指向正确的 commit*

5. **取消当前失败的 workflow run**  
   `POST /repos/:owner/:repo/actions/runs/27778031947/cancel`

6. **验证最终状态**（列出 checklist）
   - [ ] `git ls-remote --tags origin v1.13.0` → 返回 `fe4f1dc...`
   - [ ] GitHub Release 页面仍可访问，4 个 APK/AAB 资产仍存在
   - [ ] `pubspec.yaml` 仍为 `1.13.0+1130`
   - [ ] 下一次 push 新 commit 到 main 时，semantic-release 将正确地以 v1.13.0 为基准计算下一个版本号（预计为 v1.14.0 或更高）

**优点**:
- ✅ 操作最快（预计 2-3 分钟完成，无需重新编译 Flutter）
- ✅ 不改变 main 分支的 commit 历史（无需 force-push）
- ✅ Release 资产（APK/AAB）无需重新生成和上传
- ✅ 风险最小（只是 tag 的位置校正）

**缺点**:
- CHANGELOG.md 仍有重复的 1.13.0 条目（可通过后续 commit 手动清理，不影响发布状态）
- universal APK (`app-release.apk`) 缺失（注意：`.releaserc.json` 配置中要求了此文件，但 Android 构建现在通常按 ABI 分裂，universal 版本并不必要）

**风险评级**: **低** — 仅涉及 tag 的删除/重建，不修改代码或 commit 历史

---

### 方案 B：完全重来 — 删除 tag 和 release，回退 main，重新触发 CI
**目标**: 删除一切与 v1.13.0 相关的东西，从 `90016e5`（最后一个 feat commit）重新做一次干净的 release

**操作步骤**（约 15-20 分钟，包含 Flutter 重新构建）:

1. 删除远程 tag `v1.13.0`
2. 删除 GitHub Release `v1.13.0`
3. Force-push main 回退到 `90016e5`（丢弃 release commit fe4f1dc）
4. 手动清理 `CHANGELOG.md` 中的重复 1.13.0 条目，push 一个 cleanup commit
5. 通过 workflow_dispatch 重新触发 `Android Release` workflow
6. 等待 Flutter 构建 + semantic-release 完成（约 10-15 分钟）

**优点**:
- ✅ CHANGELOG 干净无重复
- ✅ tag、release commit、release 资产完全一致
- ✅ 可获得 universal APK 资产（如果构建配置正确）

**缺点**:
- ❌ 需要 force-push main（改动历史）
- ❌ 需要重新跑一次完整的 Flutter 构建（10+ 分钟）
- ❌ 风险更高（新的构建可能有新问题）

**风险评级**: **中** — force-push 和全量重新构建带来不确定性

---

## 3. 推荐方案：方案 A

选择方案 A 的理由：

1. **Release 的核心产出物（APK/AAB）已经存在且有效** — 无需重新构建
2. **问题仅仅是 tag 指向了一个 dangling commit** — 代价最小的修复即最合理
3. **不 force-push main** — 保持 Git 历史的完整性，不给用户带来困惑
4. **时间成本极低** — 几分钟内完成
5. **CHANGELOG 重复条目是纯 cosmetic 问题** — 不影响功能，可在后续的下一次 release 中自然修复（下一次 semantic-release 会在顶部写入新版本号，旧的重复条目仍在但不再显眼）

---

## 4. 详细执行步骤（方案 A）

### 步骤 4.1 — 删除远程 tag `v1.13.0`
**工具**: GitHub REST API  
**请求**:
```
DELETE https://api.github.com/repos/1525745393/EmbyTok-Flutter/git/refs/tags/v1.13.0
Authorization: Bearer <PAT>
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
```
**预期响应**: HTTP 204 No Content  
**失败回退**: 如果 404 → 说明 tag 已被删除，直接进入下一步

### 步骤 4.2 — 创建新 tag `v1.13.0` 指向 `fe4f1dc`
**工具**: GitHub REST API  
**请求**:
```
POST https://api.github.com/repos/1525745393/EmbyTok-Flutter/git/refs
Authorization: Bearer <PAT>
Content-Type: application/json

{
  "ref": "refs/tags/v1.13.0",
  "sha": "fe4f1dc165edad186195a722df7b6b5d0b7ebf41"
}
```
**预期响应**: HTTP 201 Created + 返回 ref 对象，其中 `object.sha` 为 `fe4f1dc...`

### 步骤 4.3 — 验证 tag 修复
**工具**: Git 命令 + GitHub REST API  
**验证命令**:
```bash
# 1. 本地刷新远程 tag
git fetch origin --tags --force

# 2. 验证 tag 指向
git rev-parse refs/tags/v1.13.0
# 期望输出: fe4f1dc165edad186195a722df7b6b5d0b7ebf41

# 3. 验证 tag 的 commit 在 main 上
git branch -r --contains refs/tags/v1.13.0
# 期望输出: origin/main 应出现在列表中
```

### 步骤 4.4 — 取消当前失败的 workflow run
**工具**: GitHub REST API  
**请求**:
```
POST https://api.github.com/repos/1525745393/EmbyTok-Flutter/actions/runs/27778031947/cancel
Authorization: Bearer <PAT>
Content-Type: application/json
{}
```
**预期响应**: HTTP 202 Accepted（接受取消请求）或 HTTP 409（如果 run 已经完成/失败无法取消）

### 步骤 4.5 — 最终验证清单
在浏览器或 API 中检查以下项：
- [ ] `https://github.com/1525745393/EmbyTok-Flutter/releases/tag/v1.13.0` 可访问，显示 4 个 APK 资产
- [ ] 点击 release 页面的 commit hash → 能正确跳转到 main 分支上的 `chore(release): 1.13.0 [skip ci]`
- [ ] `https://github.com/1525745393/EmbyTok-Flutter/actions` 没有处于运行中的 Android Release 工作流
- [ ] main 分支的 `frontend/pubspec.yaml` 显示 `version: 1.13.0+1130`

---

## 5. 风险与回退

**风险 1: 删除 tag 后重建失败**
- 概率: 极低（GitHub API 操作稳定）
- 影响: 短暂缺少 v1.13.0 tag，但 Release 页面的 assets 仍然存在
- 回退: 如果 DELETE 成功但 POST 失败，可立即用相同命令重新 POST，或用 git CLI 推送 tag

**风险 2: GitHub Release 与新 tag 的关联出问题**
- 概率: 低（GitHub Release 是通过 tag 名关联的，不是 commit sha）
- 影响: 无影响，Release 始终绑定到 tag 名 `v1.13.0`
- 回退: 检查 Release 页面，如有问题可通过 `PATCH /releases/:id` 更新

**风险 3: 下一次 release 时 semantic-release 行为异常**
- 概率: 低（tag 已正确指向 main 上的 commit，semantic-release 下一次会正确识别 v1.13.0 为上一个版本）
- 验证方法: 可以在本地或 test 分支先跑一次 `npx semantic-release --dry-run` 验证

---

## 6. 后续可选优化

这些不在本次修复范围内，但建议后续处理：

1. **CHANGELOG 清理**: 在下一个常规开发 commit 中，手动编辑 `CHANGELOG.md`，合并 3 段重复的 1.13.0 条目为一段。
2. **Universal APK 缺失检查**: 如果 `app-release.apk`（universal）确实是需要的，请检查 `frontend/android/app/build.gradle` 中的 `splits` 配置——当前只按 ABI 分裂但未同时生成 universal 版本。如果 universal 不是必需的，可从 `.releaserc.json` 的 assets 配置中移除该条目，避免下次 release 时报告缺失。
3. **分支保护策略**: 建议配置 `semantic-release` 相关的分支保护规则（例如，允许 GitHub Actions bot 绕过 push 限制），防止未来再次出现类似的 push 失败。
