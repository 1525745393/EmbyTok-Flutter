// ================================
// 版本号管理
// ================================
// 单一事实来源（Single Source of Truth）：
//   - pubspec.yaml 的 version 字段
//   - android/app/build.gradle 的 versionName/versionCode
//   - 本文件中的 kAppVersion / kAppVersionCode
// 三者在每次发布时必须保持一致。
// 可使用 scripts/verify-release.sh 自动验证。
// ================================

// 语义版本号（MAJOR.MINOR.PATCH），与 pubspec.yaml 中 version 字段同步更新
const String kAppVersion = '1.2.4';

// Android versionCode：
//   - 每次发布必须单调递增
//   - 建议：1000 * MAJOR + 100 * MINOR + PATCH
//   - 当前：1 * 1000 + 2 * 100 + 4 = 1204  → 为保留空间使用自定义值
const int kAppVersionCode = 15;

// 构建渠道（release / debug / ci），便于日志与错误报告中区分
const String kBuildChannel =
    String.fromEnvironment('BUILD_CHANNEL', defaultValue: 'release');

// ================================
// 语义版本解析与比较工具
// ================================

/// 解析 "1.2.4" / "1.2.4-beta.1" 形式的版本字符串
class SemanticVersion {
  final int major;
  final int minor;
  final int patch;
  final String? prerelease; // 如 "beta.1"

  SemanticVersion(this.major, this.minor, this.patch, [this.prerelease]);

  /// 从字符串解析，失败时返回 null
  static SemanticVersion? tryParse(String value) {
    if (value.isEmpty) return null;
    // 分离主版本号和预发布标识："1.2.4-beta.1"
    final parts = value.split('-');
    final numeric = parts[0].trim();
    final prerelease = parts.length > 1 ? parts.sublist(1).join('-') : null;

    final numbers = numeric.split('.');
    if (numbers.length < 3) return null;

    final major = int.tryParse(numbers[0]);
    final minor = int.tryParse(numbers[1]);
    final patch = int.tryParse(numbers[2]);
    if (major == null || minor == null || patch == null) return null;

    return SemanticVersion(major, minor, patch, prerelease);
  }

  /// 比较：当前版本小于 other 返回 -1，等于 0，大于 1
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // 预发布版本：有 prelease 的视为小于没有 prelease 的
    if (prerelease == null && other.prerelease == null) return 0;
    if (prerelease == null) return 1;
    if (other.prerelease == null) return -1;
    return prerelease!.compareTo(other.prerelease!);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          other.major == major &&
          other.minor == minor &&
          other.patch == patch &&
          other.prerelease == prerelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease);

  @override
  String toString() =>
      prerelease == null ? '$major.$minor.$patch' : '$major.$minor.$patch-$prerelease';
}

/// 返回完整版本信息字符串，用于 "关于" 页面或日志输出
String get fullVersionString {
  if (kBuildChannel == 'release') return 'v$kAppVersion';
  return 'v$kAppVersion ($kBuildChannel)';
}

/// 解析远程版本字符串并与当前版本比较，返回是否需要升级
bool isUpdateAvailable(String remoteVersion) {
  final current = SemanticVersion.tryParse(kAppVersion);
  final latest = SemanticVersion.tryParse(remoteVersion);
  if (current == null || latest == null) return false;
  return latest > current;
}
