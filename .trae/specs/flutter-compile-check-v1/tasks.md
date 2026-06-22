# Tasks: Flutter 编译错误预防机制

## 任务列表

- [x] Task 1: 修改 CI workflow，添加 flutter analyze 步骤
  - 修改 `.github/workflows/ci.yml`，添加 `flutter analyze` job
  - 确保 analyze 失败时 CI 整体失败

- [x] Task 2: 修改发布脚本，添加前置构建验证
  - 修改 `scripts/release.sh`，在版本更新前执行 `flutter analyze --no-pub` 和 `flutter build --debug`
  - 验证失败时脚本输出错误信息并以非 0 退出码退出

- [x] Task 3: 创建本地 Flutter 检查脚本
  - 创建 `scripts/flutter-check.sh`
  - 包含 flutter analyze 和 flutter build 验证
  - 方便开发者本地运行

- [x] Task 4: 更新 CI android-release workflow
  - 在 `android-release.yml` 开头添加 flutter analyze 检查
  - 确保发布前代码质量达标

## 任务依赖
- Task 4 依赖 Task 1（需先在 CI 中验证 analyze 配置正确）
- Task 3 可独立进行

## 验证方式
- 修改后触发 CI，观察 analyze 步骤是否正确执行
- 手动运行 `scripts/flutter-check.sh`，确认输出正确
