import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class DefaultThemeData with ChangeNotifier {
  ThemeType _currentThemeType = ThemeType.brisk;
  DarkModeType _darkMode = DarkModeType.system;
  final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
  TUITheme _theme = DefTheme.getTheme(ThemeType.brisk, DarkModeType.system);

  DefaultThemeData() {
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString("darkMode");
    if (value != null) {
      _darkMode = DarkModeType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => DarkModeType.system,
      );
      _applyTheme();
      notifyListeners();
    }
  }

  TUITheme get theme => DefTheme.getTheme(_currentThemeType, _darkMode);

  ThemeMode get themeMode {
    switch (_darkMode) {
      case DarkModeType.light:
        return ThemeMode.light;
      case DarkModeType.dark:
        return ThemeMode.dark;
      case DarkModeType.system:
        return ThemeMode.system;
    }
  }

  ThemeType get currentThemeType => _currentThemeType;

  set currentThemeType(ThemeType type) {
    _currentThemeType = type;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString("themeType", type.toString());
    });
    _applyTheme();
    notifyListeners();
  }

  DarkModeType get darkMode => _darkMode;

  set darkMode(DarkModeType mode) {
    _darkMode = mode;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString("darkMode", mode.name);
    });
    _applyTheme();
    notifyListeners();
  }

  void _applyTheme() {
    final next = theme;
    _theme = next;
    _coreInstance.setTheme(theme: next);
  }
}
