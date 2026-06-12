# GitHub Secrets 配置摘要

生成时间: 2026-06-12

## 一、Android 签名 Secrets (已生成)

| Secret 名称 | 值 |
|------------|-----|
| ANDROID_KEYSTORE | 详见下方 keystore_base64.txt |
| ANDROID_KEYSTORE_PWD | `EmbyTok2024!` |
| ANDROID_KEY_ALIAS | `embbytok` |
| ANDROID_KEY_PWD | `EmbyTok2024!` |

keystore 文件: `frontend/android/embbytok-keystore.jks`
keystore base64: `scripts/keystore_base64.txt`

## 二、Docker Secrets (需您提供)

| Secret 名称 | 值 |
|------------|-----|
| DOCKER_USERNAME | 您的 Docker Hub 用户名 |
| DOCKER_PASSWORD | 您的 Docker Hub Access Token |
| DOCKER_REGISTRY | (可选) 默认 docker.io |

## 三、设置步骤

### 方式 A: GitHub 网页（推荐新手）

1. 打开: https://github.com/1525745393/EmbyTok-Flutter/settings/secrets/actions
2. 点击 "New repository secret"
3. 依次添加上述 4+2 个 Secrets
4. 每个 secret 添加后点击 "Add secret"

### 方式 B: 使用脚本（推荐自动化）

在本地终端运行：

```bash
# 1. 替换为您的 GitHub PAT (ghp_ 开头)
export GITHUB_PAT="ghp_YourPersonalAccessToken"

# 2. 设置 Docker 账号（可选）
export DOCKER_USERNAME="YourDockerHubUsername"
export DOCKER_PASSWORD="YourDockerHubAccessToken"

# 3. 运行脚本一键设置所有 Secrets
cd /workspace
python3 scripts/set_github_secrets.py \
  --token "$GITHUB_PAT" \
  --android-keystore "$(base64 -w 0 frontend/android/embbytok-keystore.jks)" \
  --android-keystore-pwd "EmbyTok2024!" \
  --android-key-alias "embbytok" \
  --android-key-pwd "EmbyTok2024!" \
  --docker-username "$DOCKER_USERNAME" \
  --docker-password "$DOCKER_PASSWORD"
```

## 四、验证配置成功

配置完成后，在 GitHub Actions 页面手动触发 "Secrets 配置检查" workflow:
https://github.com/1525745393/EmbyTok-Flutter/actions/workflows/secrets-check.yml

## 五、触发构建

配置完成后，推送一个 tag 即可触发自动化构建:

```bash
git tag v1.0.0
git push --tags
```

或者在 Actions 页面手动触发 android-release / docker-release workflow。

## 六、安全提示

⚠️ 请妥善保管：
- keystore 文件 (embbytok-keystore.jks)
- 密码 (EmbyTok2024!)
- GitHub PAT
- Docker Hub Access Token

建议将 keystore 文件加密备份到安全位置。
