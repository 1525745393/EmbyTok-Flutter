/// ============================================================
/// EmbyTok Flutter - 版本信息
/// 此文件由发布脚本自动维护，请勿手动编辑
/// 同步于 pubspec.yaml 中的 version 字段
/// ============================================================
library;

/// 语义化版本号 (MAJOR.MINOR.PATCH)
/// 注意：此文件由 semantic-release prepareCmd 自动维护，
/// 同步自 pubspec.yaml。以下手动修改仅用于补齐历史遗留错位
const String embytokVersion = '2.35.5';

/// 构建号（与 Android versionCode / iOS buildNumber 对齐）
const int embytokBuildNumber = 635;

/// 完整版本信息
String get embytokFullVersion => '$embytokVersion+$embytokBuildNumber';
