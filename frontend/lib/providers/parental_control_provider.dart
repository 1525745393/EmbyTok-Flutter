// 家长控制 / 儿童模式 Provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 家长控制设置
class ParentalControlState {
  /// 是否启用儿童模式
  final bool kidsModeEnabled;

  /// 最高允许的内容评分（如 MPAA PG-13，留空表示不限制）
  final String? maxRating;

  /// 隐藏未到评分的影片
  final bool hideRestrictedContent;

  const ParentalControlState({
    this.kidsModeEnabled = false,
    this.maxRating,
    this.hideRestrictedContent = false,
  });

  ParentalControlState copyWith({
    bool? kidsModeEnabled,
    String? maxRating,
    bool? hideRestrictedContent,
    bool clearMaxRating = false,
  }) {
    return ParentalControlState(
      kidsModeEnabled: kidsModeEnabled ?? this.kidsModeEnabled,
      maxRating: clearMaxRating ? null : (maxRating ?? this.maxRating),
      hideRestrictedContent:
          hideRestrictedContent ?? this.hideRestrictedContent,
    );
  }
}

class ParentalControlNotifier extends StateNotifier<ParentalControlState> {
  ParentalControlNotifier() : super(const ParentalControlState()) {
    _load();
  }

  static const _keyKidsMode = 'parental_kids_mode';
  static const _keyMaxRating = 'parental_max_rating';
  static const _keyHideRestricted = 'parental_hide_restricted';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = ParentalControlState(
        kidsModeEnabled: prefs.getBool(_keyKidsMode) ?? false,
        maxRating: prefs.getString(_keyMaxRating),
        hideRestrictedContent: prefs.getBool(_keyHideRestricted) ?? false,
      );
    } catch (_) {}
  }

  Future<void> setKidsMode(bool enabled) async {
    state = state.copyWith(kidsModeEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKidsMode, enabled);
  }

  Future<void> setMaxRating(String? rating) async {
    state = state.copyWith(maxRating: rating, clearMaxRating: rating == null);
    final prefs = await SharedPreferences.getInstance();
    if (rating == null) {
      await prefs.remove(_keyMaxRating);
    } else {
      await prefs.setString(_keyMaxRating, rating);
    }
  }

  Future<void> setHideRestricted(bool hide) async {
    state = state.copyWith(hideRestrictedContent: hide);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideRestricted, hide);
  }
}

final parentalControlProvider =
    StateNotifierProvider<ParentalControlNotifier, ParentalControlState>(
  (ref) => ParentalControlNotifier(),
);
