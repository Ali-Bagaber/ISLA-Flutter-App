import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const _box = 'isla_prefs';
  static const _key = 'isDarkMode';

  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  /// Call once at app start (after Hive.initFlutter) to restore saved choice.
  Future<void> load() async {
    final box = await Hive.openBox(_box);
    _isDarkMode = box.get(_key, defaultValue: true) as bool;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    _persist();
  }

  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    _persist();
  }

  void _persist() async {
    final box = await Hive.openBox(_box);
    await box.put(_key, _isDarkMode);
  }
}
