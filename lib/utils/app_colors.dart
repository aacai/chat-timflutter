import 'package:flutter/material.dart';

/// 统一配色入口。
///
/// 参考 Material 3 的 color role：白色只允许以 [onPrimary] 的形式出现
/// （深色主色 / 渐变 / 徽标底上的前景），且集中在此定义；
/// 所有背景、表面、分割线、次要文字都必须跟随主题亮度，
/// 避免各页面散落 Colors.white 造成深色模式下的白块与启动白闪。
class AppColors {
  AppColors._();

  /// 主色、渐变、强调色底上的前景（Material 3 on-primary）。
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryWeak = Color(0xB3FFFFFF);
  static const Color onPrimaryMuted = Color(0x99FFFFFF);
  static const Color onPrimaryFaint = Color(0x1FFFFFFF);

  /// 与各端原生启动背景、深色 TUITheme.weakBackgroundColor 保持一致。
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color lightSurface = Color(0xFFF5F6F8);

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : lightSurface;

  /// 浮起表面（弹窗、分组卡片）：比页面底色亮一档，用来建立层级。
  /// 深色下不能用纯白，浅色下用白色与页面浅灰拉开对比。
  static Color elevatedSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF242528)
          : const Color(0xFFFFFFFF);

  static Color onSurfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFEAEAEA)
          : const Color(0xFF1F2329);

  static Color weakTextOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF9B9B9B)
          : const Color(0xFF8A8F99);

  static Color dividerOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2C)
          : const Color(0xFFE3E5E9);

  /// 深色叠加白、浅色叠加黑，用于选中态 / hover 的半透明层。
  static Color overlayOf(BuildContext context) =>
      (Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withOpacity(0.07);

  static Color inputFillOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.04)
          : lightSurface;
}
