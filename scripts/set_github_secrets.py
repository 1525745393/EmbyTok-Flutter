#!/usr/bin/env python3
"""
设置 GitHub Actions Secrets 脚本

用法:
    python3 scripts/set_github_secrets.py --token YOUR_GITHUB_TOKEN \
        --repo 1525745393/EmbyTok-Flutter \
        --android-keystore BASE64_STRING \
        --android-keystore-pwd "your_password" \
        --android-key-alias "embbytok" \
        --android-key-pwd "your_password" \
        --docker-username "your_dockerhub_username" \
        --docker-password "your_dockerhub_token"
"""

import argparse
import base64
import json
import sys
from typing import Optional

try:
    from nacl import encoding, public
except ImportError:
    print("❌ 需要安装 pynacl: pip install pynacl")
    sys.exit(1)

import requests

GITHUB_API = "https://api.github.com"


def encrypt_secret(public_key_str: str, secret_value: str) -> str:
    """使用 GitHub 仓库公钥加密 secret 值"""
    public_key_bytes = base64.b64decode(public_key_str)
    box_public_key = public.PublicKey(public_key_bytes)
    sealed_box = public.SealedBox(box_public_key)
    encrypted_bytes = sealed_box.encrypt(secret_value.encode("utf-8"))
    return base64.b64encode(encrypted_bytes).decode("utf-8")


def get_public_key(token: str, repo: str) -> tuple[str, str]:
    """获取仓库公钥"""
    url = f"{GITHUB_API}/repos/{repo}/actions/secrets/public-key"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
    }
    resp = requests.get(url, headers=headers)
    resp.raise_for_status()
    data = resp.json()
    return data["key"], data["key_id"]


def set_secret(
    token: str, repo: str, secret_name: str, secret_value: str
) -> bool:
    """设置仓库级 secret"""
    try:
        pub_key, key_id = get_public_key(token, repo)
        encrypted = encrypt_secret(pub_key, secret_value)

        url = f"{GITHUB_API}/repos/{repo}/actions/secrets/{secret_name}"
        headers = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github.v3+json",
        }
        payload = {"encrypted_value": encrypted, "key_id": key_id}

        resp = requests.put(url, headers=headers, json=payload)
        resp.raise_for_status()
        print(f"✅ {secret_name} 设置成功")
        return True
    except requests.exceptions.HTTPError as e:
        print(f"❌ {secret_name} 设置失败: {e}")
        if e.response is not None:
            print(f"   响应: {e.response.text[:200]}")
        return False
    except Exception as e:
        print(f"❌ {secret_name} 设置失败: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="设置 GitHub Actions Secrets")
    parser.add_argument(
        "--token",
        required=True,
        help="GitHub Personal Access Token (需要 repo 权限)",
    )
    parser.add_argument(
        "--repo",
        default="1525745393/EmbyTok-Flutter",
        help="仓库名称 (格式: owner/repo)",
    )
    parser.add_argument("--android-keystore", help="ANDROID_KEYSTORE (base64)")
    parser.add_argument(
        "--android-keystore-pwd", help="ANDROID_KEYSTORE_PWD (keystore 密码)"
    )
    parser.add_argument(
        "--android-key-alias", help="ANDROID_KEY_ALIAS (key 别名, 默认 embbytok)"
    )
    parser.add_argument("--android-key-pwd", help="ANDROID_KEY_PWD (key 密码)")
    parser.add_argument(
        "--docker-registry",
        help="DOCKER_REGISTRY (可选, 默认 docker.io)",
    )
    parser.add_argument("--docker-username", help="DOCKER_USERNAME (Docker Hub 用户名)")
    parser.add_argument("--docker-password", help="DOCKER_PASSWORD (Docker Hub Access Token)")

    args = parser.parse_args()

    secrets = {}

    # Android 签名配置
    if args.android_keystore:
        secrets["ANDROID_KEYSTORE"] = args.android_keystore
    if args.android_keystore_pwd:
        secrets["ANDROID_KEYSTORE_PWD"] = args.android_keystore_pwd
    if args.android_key_alias:
        secrets["ANDROID_KEY_ALIAS"] = args.android_key_alias
    if args.android_key_pwd:
        secrets["ANDROID_KEY_PWD"] = args.android_key_pwd

    # Docker 配置
    if args.docker_registry:
        secrets["DOCKER_REGISTRY"] = args.docker_registry
    if args.docker_username:
        secrets["DOCKER_USERNAME"] = args.docker_username
    if args.docker_password:
        secrets["DOCKER_PASSWORD"] = args.docker_password

    if not secrets:
        print("⚠️  未指定任何 secret，请提供至少一个 --* 参数")
        parser.print_help()
        sys.exit(1)

    print(f"📦 将为仓库 {args.repo} 设置以下 Secrets:")
    for name in secrets:
        value_preview = secrets[name][:5] + "..." + secrets[name][-3:] if len(secrets[name]) > 10 else "..."
        print(f"  - {name}: {value_preview}")
    print()

    # 确认
    try:
        response = input("继续？ (y/N): ").strip().lower()
        if response not in ("y", "yes"):
            print("已取消")
            sys.exit(0)
    except EOFError:
        pass

    print(f"\n🚀 开始设置 Secrets...\n")

    results = {}
    for name, value in secrets.items():
        results[name] = set_secret(args.token, args.repo, name, value)

    print(f"\n📊 完成 {len(results)} 个 Secrets 的设置:")
    for name, success in results.items():
        print(f"  {'✅' if success else '❌'} {name}")

    if not all(results.values()):
        sys.exit(1)
    print("\n🎉 所有 Secrets 已成功设置！")
    print(f"查看: https://github.com/{args.repo}/settings/secrets/actions")


if __name__ == "__main__":
    main()
