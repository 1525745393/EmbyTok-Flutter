# Checklist: Flutter 编译错误预防机制

## CI Workflow 检查点

- [x] `.github/workflows/ci.yml` 包含 `flutter analyze` 步骤
- [x] `flutter analyze` 步骤位于测试步骤之前
- [x] `flutter analyze` 失败时 CI job 失败（非 warning 而已）

## 发布脚本检查点

- [x] `scripts/release.sh` 包含 flutter analyze 调用
- [x] `scripts/release.sh` 包含 flutter build --debug 调用
- [x] 验证失败时脚本输出错误信息并以非 0 退出码退出

## 本地检查脚本检查点

- [x] `scripts/flutter-check.sh` 文件存在且可执行
- [x] 脚本运行 `flutter analyze`
- [x] 脚本运行 `flutter build --debug`
- [x] 错误时返回非 0 退出码

## Android Release Workflow 检查点

- [x] `.github/workflows/android-release.yml` 在构建前包含 flutter analyze 步骤
- [x] analyze 失败时阻止后续构建步骤

## 整体验证检查点

- [ ] 运行 `flutter analyze` 无任何 error 输出
- [ ] 运行 `flutter build --debug` 构建成功
- [ ] CI 中 analyze 步骤正确执行
