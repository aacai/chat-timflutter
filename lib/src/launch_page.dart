import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/app_colors.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// 启动到登录页之间的加载页。
///
/// 背景必须与各端原生启动背景、以及 MaterialApp 的 scaffoldBackgroundColor
/// 一致（深色主题下为 #1A1A1A），否则首帧会闪白。
class LaunchPage extends StatelessWidget {
  const LaunchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final background = AppColors.surfaceOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: background,
      child: isWideScreen
          ? MoveWindow(
              child: Center(
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: theme.primaryColor ?? AppColors.weakTextOf(context),
                  size: 50,
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: theme.primaryColor ?? AppColors.weakTextOf(context),
                    size: 76,
                  ),
                ),
                // 底部装饰图是浅色素材，深色主题下会变成刺眼的白块，直接隐藏。
                if (!isDark)
                  Positioned(
                    bottom: 0,
                    child: Image.asset(
                      "assets/logo_bottom.png",
                      fit: BoxFit.fitWidth,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
              ],
            ),
    );
  }
}
