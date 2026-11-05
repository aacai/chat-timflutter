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

/// 弹窗菜单项，配色与弹窗外壳共用一套 AppColors。
class AppMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AppMenuItem(
      {required this.label, required this.icon, required this.onTap});
}

/// 统一风格的弹窗菜单：图标 + 文案 + 细分割线 + hover 反馈。
class AppMenu extends StatelessWidget {
  final List<AppMenuItem> items;

  const AppMenu({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final onSurface = AppColors.onSurfaceOf(context);
    final weakText = AppColors.weakTextOf(context);
    final divider = AppColors.dividerOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 0.5, indent: 44, color: divider),
          InkWell(
            onTap: items[i].onTap,
            borderRadius: BorderRadius.circular(8),
            hoverColor: AppColors.overlayOf(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(items[i].icon, size: 18, color: weakText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(items[i].label,
                        style: TextStyle(fontSize: 14, color: onSurface)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 统一接管 TUIKit 的所有宽屏浮窗。
///
/// 原生 TUIKitWidePopup 的 overlay 分支无法用遮罩 / Esc / 系统返回关闭，
/// 且固定 440x520 会把只有几项的菜单撑成一大块空白面板。这里用
/// showGeneralDialog 重做外壳：菜单按内容自适应、过渡更短、配色统一走
/// [AppColors]，不依赖 TUIKit core 的全局主题是否已同步。
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
    final onSubmitCb = onSubmit;
    final onCancelCb = onCancel;
    final onConfirmCb = onConfirm;
    // 菜单 / 确认框按内容自适应；设置、关于等内容页用调用方给定的尺寸。
    final bool fixedSize = width != null && height != null && height > 200;
    final isCompactScreen = size.width < 600;
    final dialogWidth = isCompactScreen
        ? size.width - 24
        : (width ?? 360).clamp(0.0, size.width - 32).toDouble();
    final dialogHeight = fixedSize
        ? (isCompactScreen
            ? size.height - 80
            : height.clamp(0.0, size.height - 48).toDouble())
        : 0.0;

    final surface = AppColors.elevatedSurfaceOf(context);
    final onSurface = AppColors.onSurfaceOf(context);
    final weakText = AppColors.weakTextOf(context);
    final divider = AppColors.dividerOf(context);
    final accent = theme?.primaryColor ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActions = onCancelCb != null || onConfirmCb != null;

    // close() 里同步释放，菜单项才能立刻打开下一个弹窗；
    // 遮罩关闭走不到 close()，所以在 await 之后补一次（幂等）。
    bool released = false;
    void release() {
      if (released) return;
      released = true;
      TUIKitWidePopup.isShow = false;
      TUIKitWidePopup.entry?.remove();
      TUIKitWidePopup.entry = null;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: TIM_t("关闭"),
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        void close() {
          release();
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: size.height - 48),
                  child: Container(
                    width: dialogWidth,
                    height: fixedSize ? dialogHeight : null,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius:
                          borderRadius ?? BorderRadius.circular(18),
                      border: Border.all(color: divider, width: 0.5),
                      // 深色下用描边即可分层，省掉大尺寸弹窗的阴影重绘。
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Column(
                      mainAxisSize:
                          fixedSize ? MainAxisSize.max : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
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
                                          color: onSurface),
                                    ),
                                  ),
                                if (title == null) const Spacer(),
                                if (onSubmitCb != null) ...[
                                  InkWell(
                                    onTap: () {
                                      onSubmitCb();
                                      close();
                                    },
                                    child: submitWidget ??
                                        Icon(Icons.check,
                                            size: 20, color: onSurface),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                IconButton(
                                  onPressed: close,
                                  tooltip: TIM_t("关闭"),
                                  icon: Icon(Icons.close,
                                      size: 18, color: weakText),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  splashRadius: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, thickness: 0.5, color: divider),
                        if (fixedSize)
                          Expanded(child: child(close))
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: child(close),
                          ),
                        if (hasActions)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (onCancelCb != null)
                                  TextButton(
                                    onPressed: () {
                                      close();
                                      onCancelCb();
                                    },
                                    child: Text(TIM_t("取消"),
                                        style: TextStyle(color: weakText)),
                                  ),
                                if (onCancelCb != null && onConfirmCb != null)
                                  const SizedBox(width: 8),
                                if (onConfirmCb != null)
                                  FilledButton(
                                    onPressed: () {
                                      close();
                                      onConfirmCb();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accent,
                                      foregroundColor: AppColors.onPrimary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: Text(TIM_t("确定")),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (dialogContext, animation, secondaryAnimation, dialogChild) {
        final curve =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curve),
            child: dialogChild,
          ),
        );
      },
    );

    // UIKit 在 hook 返回 true 时不会复位 isShow，
    // 遮罩 / 系统返回关闭时补一次（幂等，不会覆盖新打开的弹窗）。
    release();
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

/// 单选对话框的一个选项。
class ProfileOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const ProfileOption({required this.value, required this.label, this.icon});
}

bool _useBottomSheet(BuildContext context) =>
    MediaQuery.of(context).size.width < 600;

Color _accentOf(BuildContext context, Color? accent) =>
    accent ?? Theme.of(context).colorScheme.primary;

Widget _dialogActions(BuildContext context,
    {required VoidCallback onCancel,
    required VoidCallback onConfirm,
    required Color accent,
    required String confirmText}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: Text(TIM_t("取消"),
              style: TextStyle(color: AppColors.weakTextOf(context))),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: AppColors.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

Widget _dialogTitle(BuildContext context, String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceOf(context)),
      ),
    );

/// 统一的文本编辑对话框：宽屏为轻量 Dialog，移动端为 BottomSheet。
/// 返回编辑后的文本；取消返回 null。
Future<String?> showProfileTextDialog({
  required BuildContext context,
  required String title,
  String hint = "",
  String initialText = "",
  int maxLength = 100,
  Color? accent,
}) async {
  final controller = TextEditingController(text: initialText);
  final primary = _accentOf(context, accent);
  final surface = AppColors.elevatedSurfaceOf(context);
  final onSurface = AppColors.onSurfaceOf(context);
  final weakText = AppColors.weakTextOf(context);
  final divider = AppColors.dividerOf(context);

  Widget field() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLength: maxLength,
          maxLines: 3,
          minLines: 1,
          style: TextStyle(fontSize: 15, color: onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: weakText),
            filled: true,
            fillColor: AppColors.overlayOf(context),
            counterStyle: TextStyle(fontSize: 11, color: weakText),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: divider, width: 0.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      );

  String? result;
  if (_useBottomSheet(context)) {
    result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                _dialogTitle(sheetContext, title),
                field(),
                _dialogActions(sheetContext,
                    onCancel: () => Navigator.of(sheetContext).pop(),
                    onConfirm: () => Navigator.of(sheetContext)
                        .pop(controller.text.trim()),
                    accent: primary,
                    confirmText: TIM_t("保存")),
              ],
            ),
          ),
        ),
      ),
    );
  } else {
    result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: TIM_t("取消"),
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: divider, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dialogTitle(dialogContext, title),
                field(),
                _dialogActions(dialogContext,
                    onCancel: () => Navigator.of(dialogContext).pop(),
                    onConfirm: () => Navigator.of(dialogContext)
                        .pop(controller.text.trim()),
                    accent: primary,
                    confirmText: TIM_t("保存")),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
    );
  }
  controller.dispose();
  return result;
}

/// 统一的单选对话框：宽屏 Dialog / 移动端 BottomSheet，点选即返回。
Future<T?> showProfilePickerDialog<T>({
  required BuildContext context,
  required String title,
  required List<ProfileOption<T>> options,
  T? selected,
  Color? accent,
}) async {
  final primary = _accentOf(context, accent);
  final surface = AppColors.elevatedSurfaceOf(context);
  final onSurface = AppColors.onSurfaceOf(context);
  final weakText = AppColors.weakTextOf(context);
  final divider = AppColors.dividerOf(context);

  Widget list(BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0.5, indent: 20, color: divider),
            InkWell(
              onTap: () => Navigator.of(ctx).pop(options[i].value),
              hoverColor: AppColors.overlayOf(ctx),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    if (options[i].icon != null) ...[
                      Icon(options[i].icon,
                          size: 18,
                          color: options[i].value == selected
                              ? primary
                              : weakText),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(options[i].label,
                          style: TextStyle(
                              fontSize: 15,
                              color: options[i].value == selected
                                  ? primary
                                  : onSurface)),
                    ),
                    if (options[i].value == selected)
                      Icon(Icons.check, size: 18, color: primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      );

  if (_useBottomSheet(context)) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              _dialogTitle(sheetContext, title),
              list(sheetContext),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(TIM_t("取消"),
                      style: TextStyle(color: weakText)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: TIM_t("取消"),
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height - 80),
          child: Container(
            width: 360,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: divider, width: 0.5),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dialogTitle(dialogContext, title),
                  list(dialogContext),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(TIM_t("取消"),
                            style: TextStyle(color: weakText)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
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
