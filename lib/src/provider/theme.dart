import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class DefaultThemeData with ChangeNotifier {
  ThemeType _currentThemeType = ThemeType.brisk;
  DarkModeType _darkMode = DarkModeType.dark;
  final CoreServicesImpl _coreInstance = TIMUIKitCore.getInstance();
  TUITheme _theme = DefTheme.getTheme(ThemeType.brisk, DarkModeType.dark);

  DefaultThemeData() {
    // 强制首次同步：初始 _theme 与 getTheme 结果相同，theme getter 里的
    // _sameTheme 短路会跳过 setTheme，导致 TUIKit core 全局主题停留在
    // 浅色默认值（ColumnMenu / 文件气泡等读 core 主题的组件白底白字）。
    _theme = DefTheme.getTheme(_currentThemeType, _darkMode);
    _coreInstance.setTheme(theme: _theme);
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

  TUITheme get theme {
    final next = DefTheme.getTheme(_currentThemeType, _darkMode);
    // TUIKit 的组件读的是 core 里的全局主题，而这里的 theme 是动态计算的。
    // 两者一旦不一致，AppBar、搜索框、会话项就会在深色界面里冒出白底，
    // 所以每次取 theme 都同步一次（只有颜色真的变了才写 core）。
    if (!_sameTheme(_theme, next)) {
      _theme = next;
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.persistentCallbacks) {
        // build 期间不能触发外部重建，延到本帧结束再同步。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _coreInstance.setTheme(theme: next);
        });
      } else {
        _coreInstance.setTheme(theme: next);
      }
    }
    return next;
  }

  bool _sameTheme(TUITheme a, TUITheme b) {
    return a.primaryColor == b.primaryColor &&
        a.weakBackgroundColor == b.weakBackgroundColor &&
        a.wideBackgroundColor == b.wideBackgroundColor &&
        a.chatHeaderBgColor == b.chatHeaderBgColor &&
        a.appbarBgColor == b.appbarBgColor &&
        a.darkTextColor == b.darkTextColor;
  }

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
    // 强制同步，不走 theme getter 的 _sameTheme 短路（避免漏同步给 TUIKit core）。
    final next = DefTheme.getTheme(_currentThemeType, _darkMode);
    _theme = next;
    _coreInstance.setTheme(theme: next);
  }
}
