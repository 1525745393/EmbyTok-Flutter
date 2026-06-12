# Android 签名配置指南 (Release 构建签名密钥配置

本文档介绍如何为 EmbyTok Android 应用生成签名密钥并配置 release 构建。

## 1. 生成签名 Keystore

在项目根目录的 `android/` 目录下执行以下命令：

```bash
cd /workspace/frontend/android
```

然后执行 `keytool` 生成密钥（JKS 格式的 keystore 文件：

```bash
keytool -genkey -v -keystore embbytok-keystore.jks -keyalg RSA -keysize 2048 -validity 36500 -alias embbytok
```

参数说明：
- `-keystore embbytok-keystore.jks`：输出的密钥库文件名（请在 android/ 目录下生成）
- `-keyalg RSA`：使用 RSA 算法
- `-keysize 2048`：密钥长度 2048 位
- `-validity 36500`：有效期约 100 年（36500 天）
- `-alias embbytok`：密钥别名

执行过程中需要填写以下信息：

```
Enter keystore password:  <输入 storePassword>
Re-enter new password: <再次输入 storePassword>
What is your first and last name?
  [Unknown]:  EmbyTok
What is the name of your organizational unit?
  [Unknown]:  EmbyTok
What is the name of your organization?
  [Unknown]:  EmbyTok
What is the name of your City or Locality?
  [Unknown]:  Beijing
What is the name of your State or Province?
  [Unknown]:  Beijing
What is the two-letter country code for this unit?
  [Unknown]:  CN
Is CN=EmbyTok, OU=EmbyTok, O=EmbyTok, L=Beijing, ST=Beijing, C=CN correct?
  [no]:  yes

Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 36,500 days
	for: CN=EmbyTok, OU=EmbyTok, O=EmbyTok, L=Beijing, ST=Beijing, C=CN
Enter key password for <embbytok>
	(RETURN if same as keystore password):  <回车或输入 keyPassword>
[Storing embbytok-keystore.jks]
```

## 2. 配置 key.properties

将 `android/key.properties.template` 复制为 `android/key.properties`：

```bash
cp key.properties.template key.properties
```

然后编辑 `key.properties`，填写刚才输入的密码与文件路径：

```properties
storePassword=your_store_password_here
keyPassword=your_key_password_here
keyAlias=embbytok
storeFile=embbytok-keystore.jks
```

## 3. 执行 Release 构建

在项目根目录 `frontend/` 下执行：

```bash
flutter build apk --release
```

或只构建 Android：

```bash
cd android
./gradlew assembleRelease
```

## 4. 安全提示

- **keystore 文件（`embbytok-keystore.jks`）和密码必须离线备份（例如加密压缩后上传到私人密码管理器），丢失后无法更新已上架的应用
- **绝不要** 将 `key.properties` 和 `*.jks`/`*.keystore` 文件提交到 Git，已经在 `.gitignore` 中忽略
- **团队成员共享时请使用安全的传输方式，不要在公开渠道传播

## 5. 构建输出路径

- APK 输出路径：`frontend/build/app/outputs/flutter-apk/app-release.apk`
- AAB 输出路径：`frontend/build/app/outputs/bundle/release/app-release.aab`
