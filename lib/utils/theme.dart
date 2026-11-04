import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum ThemeType { solemn, brisk, bright, fantasy }

/// 日间 / 夜间 / 跟随系统
enum DarkModeType { light, dark, system }

extension DarkModeTypeLabel on DarkModeType {
  String get label {
    switch (this) {
      case DarkModeType.light:
        return TIM_t("日间");
      case DarkModeType.dark:
        return TIM_t("夜间");
      case DarkModeType.system:
        return TIM_t("跟随系统");
    }
  }
}

class DefTheme {
  static ThemeType themeTypeFromString(String str) {
    return ThemeType.values
        .firstWhere((e) => e.toString() == str, orElse: () => ThemeType.brisk);
  }

  /// 平台当前是否为深色（用于 system 模式实时的亮度判断）。
  static bool get isPlatformDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  /// 根据主题色与夜间模式返回对应的 TUITheme。
  /// 夜间模式会沿用当前主题的强调色（primaryColor / lightPrimaryColor），
  /// 仅替换背景、分割线、文字等表面色为深色，从而和当前皮肤协调。
  static TUITheme getTheme(ThemeType type, DarkModeType darkMode) {
    final base = defaultTheme[type]!;
    final bool effectiveDark = darkMode == DarkModeType.dark ||
        (darkMode == DarkModeType.system && isPlatformDark);
    if (!effectiveDark) return base;
    return _toDark(base);
  }

  static TUITheme _toDark(TUITheme base) {
    const surface = Color(0xFF1A1A1A);
    const surfaceDeep = Color(0xFF121212);
    const divider = Color(0xFF2C2C2C);
    const weekText = Color(0xFF9B9B9B);
    const mainText = Color(0xFFEAEAEA);
    return TUITheme(
      // 沿用当前皮肤的强调色，保证和当前模式协调
      primaryColor: base.primaryColor,
      lightPrimaryColor: base.lightPrimaryColor,
      secondaryColor: base.secondaryColor,
      infoColor: base.infoColor,
      cautionColor: base.cautionColor,
      ownerColor: base.ownerColor,
      adminColor: base.adminColor,
      white: base.white,
      black: base.black,
      textgrey: base.textgrey,
      // 深色表面
      weakBackgroundColor: surface,
      wideBackgroundColor: surface,
      weakDividerColor: divider,
      inputFillColor: divider,
      weakTextColor: weekText,
      darkTextColor: mainText,
      textColor: mainText,
      appbarBgColor: surface,
      appbarTextColor: mainText,
      selectPanelBgColor: surface,
      selectPanelTextIconColor: mainText,
      conversationItemBgColor: surface,
      conversationItemBorderColor: divider,
      conversationItemActiveBgColor: divider,
      conversationItemPinedBgColor: divider,
      conversationItemTitleTextColor: mainText,
      conversationItemLastMessageTextColor: weekText,
      conversationItemTitmeTextColor: weekText,
      conversationItemOnlineStatusBgColor: Colors.green,
      conversationItemOfflineStatusBgColor: Colors.grey,
      conversationItemUnreadCountBgColor:
          base.cautionColor ?? const Color(0xFFFF584C),
      conversationItemUnreadCountTextColor: AppColors.onPrimary,
      conversationItemDraftTextColor: base.cautionColor,
      conversationItemNoNotificationIconColor: weekText,
      conversationItemSliderTextColor: AppColors.onPrimary,
      conversationItemSliderClearBgColor: base.primaryColor,
      conversationItemSliderPinBgColor: base.infoColor,
      conversationItemSliderDeleteBgColor: Colors.red,
      conversationItemChooseBgColor:
          base.primaryColor?.withAlpha(51) ?? const Color(0xFFE7F0FF),
      chatBgColor: surfaceDeep,
      desktopChatMessageInputBgColor: surface,
      chatTimeDividerTextColor: weekText,
      chatHeaderBgColor: surface,
      chatHeaderTitleTextColor: mainText,
      chatHeaderBackTextColor: mainText,
      chatHeaderActionTextColor: mainText,
      chatMessageItemTextColor: mainText,
      chatMessageItemFromSelfBgColor:
          base.primaryColor?.withAlpha(77) ?? const Color(0xFFD1E3FF),
      chatMessageItemFromOthersBgColor: divider,
      chatMessageItemUnreadStatusTextColor: weekText,
      chatMessageTongueBgColor: base.textgrey,
      chatMessageTongueTextColor: base.textgrey,
    );
  }

  static final Map<ThemeType, TUITheme> defaultTheme = {
    ThemeType.solemn: const TUITheme(
      primaryColor: Color(0xFF00449E),
      lightPrimaryColor: Color(0xFF3371CD),
    ),
    ThemeType.brisk: const TUITheme(
      primaryColor: Color(0xFF147AFF),
      lightPrimaryColor: Color(0xFFC0E1FF),
    ),
    ThemeType.bright: const TUITheme(
      primaryColor: Color(0xFFF38787),
      lightPrimaryColor: Color(0xFFFAE1B6),
    ),
    ThemeType.fantasy: const TUITheme(
      primaryColor: Color(0xFF8783F0),
      lightPrimaryColor: Color(0xFFAEB6F4),
    ),
  };

  static final Map<ThemeType, String> defaultThemeName = {
    ThemeType.solemn: TIM_t("深沉"),
    ThemeType.brisk: TIM_t("轻快"),
    ThemeType.bright: TIM_t("明媚"),
    ThemeType.fantasy: TIM_t("梦幻")
  };
}
