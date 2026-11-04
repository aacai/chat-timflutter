import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';

/// 全局返回入口。
///
/// 优先 pop 当前路由；已经处于根路由时交给 [onRootBack]
/// （宽屏主页会用它切回第一个 tab），避免用户卡在空态页里出不去。
class AppNavigation {
  static VoidCallback? onRootBack;

  static bool back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return true;
    }
    final fallback = onRootBack;
    if (fallback != null) {
      fallback();
      return true;
    }
    return false;
  }
}

/// 统一接管 TUIKit 的所有宽屏浮窗。
///
/// 原生 TUIKitWidePopup 有三个问题：没传 theme 时白色兜底、
/// title 为 null 时不渲染关闭按钮、offset 分支用 OverlayEntry
/// 导致点击遮罩 / Esc / 系统返回都关不掉。这里用 showDialog 重做外壳。
class AppModal {
  static Future<bool> showDesktopModal(
    TUIKitWideModalOperationKey operationKey,
    BuildContext context,
    Widget Function(VoidCallback closeFunc) child,
    TUITheme? theme,
    double? width,
    double? height,
    Offset? offset,
    String? initText,
    BorderRadius? borderRadius,
    bool? isDarkBackground,
    String? title,
    VoidCallback? onSubmit,
    Widget? submitWidget,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  ) async {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (width ?? 440).clamp(0.0, size.width - 24).toDouble();
    final dialogHeight =
        (height ?? 520).clamp(0.0, size.height - 48).toDouble();
    final surface = theme?.wideBackgroundColor ??
        theme?.weakBackgroundColor ??
        AppColors.surfaceOf(context);
    final onSurface =
        theme?.darkTextColor ?? AppColors.onSurfaceOf(context);
    final divider =
        theme?.weakDividerColor ?? AppColors.dividerOf(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) {
        void close() {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        }

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): close,
          },
          child: Focus(
            autofocus: true,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: dialogWidth,
                  height: dialogHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius:
                        borderRadius ?? BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 无论有没有 title 都给一个关闭入口。
                      SizedBox(
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              if (title != null)
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                ),
                              if (title == null) const Spacer(),
                              if (onSubmit != null) ...[
                                InkWell(
                                  onTap: () {
                                    onSubmit();
                                    close();
                                  },
                                  child: submitWidget ??
                                      Icon(Icons.check, color: onSurface),
                                ),
                                const SizedBox(width: 12),
                              ],
                              InkWell(
                                onTap: close,
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(Icons.close,
                                      size: 20, color: onSurface),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 0.5, color: divider),
                      Expanded(child: child(close)),
                      if (onCancel != null || onConfirm != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (onCancel != null)
                                OutlinedButton(
                                  onPressed: () {
                                    close();
                                    onCancel();
                                  },
                                  child: Text(TIM_t("取消")),
                                ),
                              if (onConfirm != null) ...[
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    close();
                                    onConfirm();
                                  },
                                  child: Text(TIM_t("确定")),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // UIKit 在 hook 返回 true 时不会复位 isShow，
    // 不重置会导致之后所有浮窗都被静默挡掉。
    TUIKitWidePopup.isShow = false;
    TUIKitWidePopup.entry?.remove();
    TUIKitWidePopup.entry = null;
    return true;
  }
}

/// 根节点 Esc 兜底：任意页面按 Esc 都能回退一层。
class AppEscapeScope extends StatelessWidget {
  final Widget child;

  const AppEscapeScope({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            AppNavigation.back(context),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// 没有 AppBar 的宽屏/空态页面共用的返回条。
class AppBackBar extends StatelessWidget {
  final String title;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final List<Widget> actions;

  const AppBackBar({
    Key? key,
    required this.title,
    this.backgroundColor,
    this.foregroundColor,
    this.actions = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? AppColors.onSurfaceOf(context);
    return Container(
      height: 48,
      color: backgroundColor ?? Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            color: fg,
            tooltip: TIM_t("返回"),
            onPressed: () => AppNavigation.back(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// 首页按窗口宽度实时切换宽屏 / 移动布局。
///
/// UIKit 的 getFormFactor 会把结果缓存在静态变量里，窗口缩小后不重算；
/// 这里同时同步该缓存，保证子页面里的 getDeviceWidget 也跟随变化。
class ResponsiveHome extends StatelessWidget {
  const ResponsiveHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    TUIKitScreenUtils.deviceType =
        isWide ? DeviceType.Desktop : DeviceType.Mobile;
    return isWide ? const HomePageWideScreen() : const HomePage();
  }
}
